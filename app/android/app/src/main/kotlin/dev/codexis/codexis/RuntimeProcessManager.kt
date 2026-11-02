package dev.codexis.codexis

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/** A deliberately small stdio JSON-RPC host; executable feasibility is a separate device gate. */
internal class RuntimeProcessManager(
    private val nativeLibraryDir: String,
    private val appFilesDir: String,
    private val appCacheDir: String,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val sessions = ConcurrentHashMap<String, Session>()

    init {
        File(appCacheDir, "asm-lsp").mkdirs()
        val configDirectory = File(appFilesDir, ".config/asm-lsp")
        configDirectory.mkdirs()
        val config = File(configDirectory, ".asm-lsp.toml")
        if (!config.exists()) {
            config.writeText(
                "[default_config]\n" +
                    "assembler = \"nasm\"\n" +
                    "instruction_set = \"x86-64\"\n" +
                    "\n[default_config.opts]\n" +
                    "diagnostics = false\n" +
                    "default_diagnostics = false\n",
            )
        }
    }

    fun start(serverId: String, workspace: File): String {
        require(serverId == "rust-analyzer" || serverId == "asm-lsp") { "Unsupported server: $serverId" }
        require(workspace.isDirectory) { "Workspace directory does not exist" }
        val executableName = when (serverId) {
            "rust-analyzer" -> "librust-analyzer.so"
            "asm-lsp" -> "libasm-lsp.so"
            else -> error("Unsupported server: $serverId")
        }
        val executable = File(nativeLibraryDir, executableName).canonicalFile
        require(executable.parentFile == File(nativeLibraryDir).canonicalFile) {
            "Language servers must be packaged in nativeLibraryDir; workspace binaries are never executed"
        }
        require(executable.isFile && executable.canExecute()) { "Server executable is missing or not executable: $executable" }

        val command = mutableListOf(executable.absolutePath)
        if (serverId == "rust-analyzer") command.add("--stdio")
        val builder = ProcessBuilder(command)
            .directory(workspace)
            .redirectErrorStream(false)
        builder.environment().apply {
            put("HOME", appFilesDir)
            put("XDG_CONFIG_HOME", File(appFilesDir, ".config").absolutePath)
            put("ASM_LSP_CACHE_DIR", File(appCacheDir, "asm-lsp").absolutePath)
        }
        val process = builder.start()
        val sessionId = UUID.randomUUID().toString()
        val session = Session(sessionId, serverId, process, emit)
        sessions[sessionId] = session
        session.startReaders()
        emit(mapOf("sessionId" to sessionId, "kind" to "started", "serverId" to serverId))
        return sessionId
    }

    fun sendRequest(sessionId: String, method: String, params: Any?): Any? =
        requireSession(sessionId).request(method, params)

    fun sendNotification(sessionId: String, method: String, params: Any?) =
        requireSession(sessionId).notification(method, params)

    fun stop(sessionId: String) {
        sessions.remove(sessionId)?.stop()
    }

    fun stopAll() {
        sessions.keys.toList().forEach(::stop)
    }

    fun status(sessionId: String): Map<String, Any> {
        val session = sessions[sessionId] ?: return mapOf("state" to "stopped")
        return mapOf(
            "state" to if (session.process.isAlive) "running" else "exited",
            "exitCode" to if (session.process.isAlive) -1 else session.process.exitValue(),
        )
    }

    /** Executes only a named file already embedded/extracted in nativeLibraryDir; does not extract or chmod it. */
    fun probeNativeLibraryExecutable(nativeLibraryDir: String, name: String): Map<String, Any?> {
        require(name.matches(Regex("[a-zA-Z0-9_.-]+"))) { "Invalid executable name" }
        val candidate = File(nativeLibraryDir, name).canonicalFile
        require(candidate.parentFile == File(nativeLibraryDir).canonicalFile) { "Executable path escaped nativeLibraryDir" }
        if (!candidate.exists()) return mapOf(
            "launchable" to false,
            "path" to candidate.absolutePath,
            "reason" to "No probe executable is packaged at this path",
        )
        if (!candidate.canExecute()) return mapOf(
            "launchable" to false,
            "path" to candidate.absolutePath,
            "reason" to "Packaged file does not have execute permission",
        )
        val process = try {
            // This probe deliberately writes to both streams and exits 23. It validates
            // launch + stream capture + exit status, not server readiness.
            ProcessBuilder(candidate.absolutePath).start()
        } catch (error: Throwable) {
            return mapOf(
                "processStarted" to false,
                "path" to candidate.absolutePath,
                "reason" to (error.message ?: error.javaClass.simpleName),
            )
        }
        val stdoutFuture = CompletableFuture.supplyAsync { process.inputStream.bufferedReader().readText() }
        val stderrFuture = CompletableFuture.supplyAsync { process.errorStream.bufferedReader().readText() }
        val exited = process.waitFor(10, TimeUnit.SECONDS)
        if (!exited) {
            process.destroyForcibly()
            process.waitFor(1, TimeUnit.SECONDS)
        }
        val stdout = runCatching { stdoutFuture.get(1, TimeUnit.SECONDS) }.getOrDefault("")
        val stderr = runCatching { stderrFuture.get(1, TimeUnit.SECONDS) }.getOrDefault("")
        return mapOf(
            "processStarted" to true,
            "expectedProbeExitCode" to 23,
            "probePassed" to (exited && process.exitValue() == 23 && stdout.contains("CODEXIS_STDOUT_OK") && stderr.contains("CODEXIS_STDERR_OK")),
            "path" to candidate.absolutePath,
            "exitCode" to if (exited) process.exitValue() else -1,
            "stdout" to stdout,
            "stderr" to stderr,
            "timedOut" to !exited,
        )
    }

    private fun requireSession(id: String) = sessions[id] ?: throw IOException("Unknown or stopped LSP session")

    companion object {
        private const val TAG = "CodexisLsp"
        private const val REQUEST_TIMEOUT_SECONDS = 30L
    }

    private class Session(
        private val id: String,
        private val serverId: String,
        val process: Process,
        private val emit: (Map<String, Any?>) -> Unit,
    ) {
        private val input = BufferedInputStream(process.inputStream)
        private val output = BufferedOutputStream(process.outputStream)
        private val writeLock = Any()
        private val nextId = AtomicLong(1)
        private val pending = ConcurrentHashMap<Long, CompletableFuture<Any?>>()

        fun startReaders() {
            Thread({ readStdout() }, "codexis-$serverId-stdout").apply { isDaemon = true; start() }
            Thread({ readStderr() }, "codexis-$serverId-stderr").apply { isDaemon = true; start() }
            Thread({
                val code = runCatching { process.waitFor() }.getOrDefault(-1)
                pending.values.forEach { it.completeExceptionally(IOException("LSP process exited with code $code")) }
                pending.clear()
                emit(mapOf("sessionId" to id, "kind" to "exited", "exitCode" to code))
            }, "codexis-$serverId-wait").apply { isDaemon = true; start() }
        }

        fun request(method: String, params: Any?, timeoutSeconds: Long = REQUEST_TIMEOUT_SECONDS): Any? {
            checkRunning()
            val requestId = nextId.getAndIncrement()
            val future = CompletableFuture<Any?>()
            pending[requestId] = future
            writeMessage(JSONObject().put("jsonrpc", "2.0").put("id", requestId).put("method", method).put("params", toJson(params)))
            return try {
                future.get(timeoutSeconds, TimeUnit.SECONDS)
            } catch (error: Throwable) {
                pending.remove(requestId)
                throw IOException("LSP request '$method' failed: ${error.cause?.message ?: error.message}", error)
            }
        }

        fun notification(method: String, params: Any?) {
            checkRunning()
            writeMessage(JSONObject().put("jsonrpc", "2.0").put("method", method).put("params", toJson(params)))
        }

        fun stop() {
            if (!process.isAlive) return
            runCatching { request("shutdown", JSONObject(), timeoutSeconds = 1) }
            runCatching { notification("exit", JSONObject()) }
            if (!runCatching { process.waitFor(1500, TimeUnit.MILLISECONDS) }.getOrDefault(false)) {
                process.destroy()
                if (!runCatching { process.waitFor(500, TimeUnit.MILLISECONDS) }.getOrDefault(false)) {
                    process.destroyForcibly()
                }
            }
        }

        private fun checkRunning() {
            if (!process.isAlive) throw IOException("LSP process is not running")
        }

        private fun writeMessage(message: JSONObject) {
            val body = message.toString().toByteArray(StandardCharsets.UTF_8)
            val frame = LspFrameCodec.encode(body)
            synchronized(writeLock) {
                output.write(frame)
                output.flush()
            }
        }

        private fun readStdout() {
            try {
                while (process.isAlive) dispatch(readFrame(input))
            } catch (error: Throwable) {
                if (process.isAlive) Log.e(TAG, "LSP stdout transport failed", error)
                pending.values.forEach { it.completeExceptionally(error) }
            }
        }

        private fun readStderr() {
            runCatching {
                process.errorStream.bufferedReader(StandardCharsets.UTF_8).useLines { lines ->
                    lines.forEach { line -> emit(mapOf("sessionId" to id, "kind" to "stderr", "line" to line)) }
                }
            }.onFailure { Log.w(TAG, "Could not read server stderr", it) }
        }

        private fun dispatch(message: JSONObject) {
            if (message.has("method")) {
                val method = message.getString("method")
                if (message.has("id")) {
                    // Answer common client capability/configuration requests so servers do not hang.
                    val response = when (method) {
                        "workspace/configuration" -> JSONArray().also { array ->
                            val items = message.optJSONObject("params")?.optJSONArray("items")
                            repeat(items?.length() ?: 0) { array.put(JSONObject.NULL) }
                        }
                        "window/workDoneProgress/create", "client/registerCapability", "client/unregisterCapability" -> JSONObject()
                        "workspace/workspaceFolders" -> JSONArray()
                        else -> JSONObject().put("code", -32601).put("message", "Client request not supported: $method")
                    }
                    val envelope = JSONObject().put("jsonrpc", "2.0").put("id", message.get("id"))
                    if (response is JSONObject && response.has("code")) envelope.put("error", response) else envelope.put("result", response)
                    writeMessage(envelope)
                    emit(mapOf("sessionId" to id, "kind" to "serverRequest", "method" to method))
                } else {
                    emit(mapOf("sessionId" to id, "kind" to "notification", "method" to method,
                        "params" to message.opt("params").toFlutterValue()))
                }
                return
            }
            val rawId = message.opt("id")
            val requestId = (rawId as? Number)?.toLong() ?: return
            val future = pending.remove(requestId) ?: return
            if (message.has("error")) {
                future.completeExceptionally(IOException(message.optJSONObject("error")?.optString("message") ?: "LSP error"))
            } else {
                future.complete(message.opt("result").toFlutterValue())
            }
        }

        private fun readFrame(stream: BufferedInputStream): JSONObject =
            JSONObject(LspFrameCodec.readBody(stream).toString(StandardCharsets.UTF_8))

        private fun Any?.toFlutterValue(): Any? = when (this) {
            JSONObject.NULL -> null
            is JSONObject -> keys().asSequence().associateWith { get(it).toFlutterValue() }
            is JSONArray -> (0 until length()).map { opt(it).toFlutterValue() }
            else -> this
        }

        private fun toJson(value: Any?): Any = when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> JSONObject().also { objectValue -> value.forEach { (key, item) ->
                if (key is String) objectValue.put(key, toJson(item))
            } }
            is List<*> -> JSONArray().also { array -> value.forEach { array.put(toJson(it)) } }
            else -> value
        }
    }
}
