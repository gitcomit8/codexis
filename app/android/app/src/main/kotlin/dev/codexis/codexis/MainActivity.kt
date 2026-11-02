package dev.codexis.codexis

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Android bridge for app-private repository imports and language-server sessions. */
class MainActivity : FlutterActivity() {
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private lateinit var repositories: RepositoryStore
    private lateinit var processManager: RuntimeProcessManager
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repositories = RepositoryStore(this)
        processManager = RuntimeProcessManager(
            applicationInfo.nativeLibraryDir,
            filesDir.absolutePath,
            cacheDir.absolutePath,
        ) { event -> runOnUiThread { eventSink?.success(event) } }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(::onMethodCall)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickAndImportRepository" -> pickRepository(result)
                "listRepositories" -> result.success(repositories.list())
                "removeRepository" -> {
                    val id = call.requiredString("id")
                    ioExecutor.execute {
                        runCatching { repositories.remove(id) }
                            .onSuccess { runOnUiThread { result.success(null) } }
                            .onFailure { fail(result, "repository_remove_failed", it) }
                    }
                }
                "listFiles" -> result.success(repositories.listFiles(call.requiredString("path")))
                "readFile" -> result.success(repositories.readFile(call.requiredString("path")))
                "probeExecutable" -> {
                    val name = call.requiredString("name")
                    Thread {
                        val answer = runCatching { processManager.probeNativeLibraryExecutable(applicationInfo.nativeLibraryDir, name) }
                        runOnUiThread {
                            answer.onSuccess(result::success).onFailure { fail(result, "executable_probe_failed", it) }
                        }
                    }.start()
                }
                "startServer" -> {
                    val serverId = call.requiredString("serverId")
                    val workspace = repositories.requireRepositoryPath(call.requiredString("workspacePath"))
                    Thread {
                        val answer = runCatching { processManager.start(serverId, workspace) }
                        runOnUiThread {
                            answer.onSuccess(result::success).onFailure { fail(result, "server_start_failed", it) }
                        }
                    }.start()
                }
                "sendLspRequest" -> {
                    val sessionId = call.requiredString("sessionId")
                    val method = call.requiredString("method")
                    val params = call.argument<Any>("params") ?: emptyMap<String, Any>()
                    Thread {
                        val answer = runCatching { processManager.sendRequest(sessionId, method, params) }
                        runOnUiThread {
                            answer.onSuccess(result::success).onFailure { fail(result, "lsp_request_failed", it) }
                        }
                    }.start()
                }
                "sendLspNotification" -> {
                    processManager.sendNotification(
                        call.requiredString("sessionId"),
                        call.requiredString("method"),
                        call.argument<Any>("params") ?: emptyMap<String, Any>(),
                    )
                    result.success(null)
                }
                "stopServer" -> {
                    Thread {
                        runCatching { processManager.stop(call.requiredString("sessionId")) }
                            .onSuccess { runOnUiThread { result.success(null) } }
                            .onFailure { fail(result, "server_stop_failed", it) }
                    }.start()
                }
                "getServerStatus" -> result.success(processManager.status(call.requiredString("sessionId")))
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            fail(result, "invalid_request", error)
        }
    }

    private fun pickRepository(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("picker_busy", "A repository picker is already open", null)
            return
        }
        pendingPickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, REQUEST_TREE)
        } catch (error: Throwable) {
            pendingPickerResult = null
            fail(result, "picker_unavailable", error)
        }
    }

    @Deprecated("FlutterActivity retains the legacy Activity result contract")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_TREE) return
        val result = pendingPickerResult ?: return
        pendingPickerResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri = data.data!!
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (error: SecurityException) {
            // Permission is only needed during the immediate copy; some providers omit persistable grants.
            Log.i(TAG, "Provider did not grant persistable folder access", error)
        }
        ioExecutor.execute {
            runCatching { repositories.import(uri) }
                .onSuccess { imported -> runOnUiThread { result.success(imported) } }
                .onFailure { fail(result, "repository_import_failed", it) }
        }
    }

    override fun onDestroy() {
        processManager.stopAll()
        ioExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun fail(result: MethodChannel.Result, code: String, error: Throwable) {
        Log.e(TAG, code, error)
        runOnUiThread { result.error(code, error.message ?: error.javaClass.simpleName, null) }
    }

    private fun MethodCall.requiredString(name: String): String =
        argument<String>(name)?.takeIf { it.isNotBlank() } ?: error("Missing required argument '$name'")

    companion object {
        private const val TAG = "CodexisRuntime"
        private const val CHANNEL = "dev.codexis/runtime"
        private const val EVENTS = "dev.codexis/runtime/events"
        private const val REQUEST_TREE = 7124
    }
}
