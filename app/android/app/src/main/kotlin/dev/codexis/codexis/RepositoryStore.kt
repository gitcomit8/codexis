package dev.codexis.codexis

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID

/** Imports user-selected Git checkouts into app-private storage without changing the source. */
internal class RepositoryStore(context: Context) {
    private val resolver = context.contentResolver
    private val root = File(context.filesDir, "repositories").apply { mkdirs() }
    private val metadataRoot = File(root, ".metadata").apply { mkdirs() }

    fun import(treeUri: Uri): Map<String, Any> {
        val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val rootDocument = DocumentsContract.buildDocumentUriUsingTree(treeUri, treeDocumentId)
        val name = displayName(rootDocument).safeName()
        val id = UUID.randomUUID().toString()
        val staging = File(root, ".$id.importing")
        val destination = File(root, id)
        if (staging.exists()) staging.deleteRecursively()
        if (!staging.mkdirs()) throw IOException("Could not create repository import directory")

        try {
            copyTree(treeUri, treeDocumentId, staging)
            val gitMetadata = File(staging, ".git")
            if (!gitMetadata.isDirectory) {
                if (gitMetadata.exists()) {
                    throw IOException("This checkout uses a .git file (worktree/submodule); import a complete Git checkout")
                }
                throw IOException("Choose a Git repository folder containing its .git directory")
            }
            if (!staging.renameTo(destination)) throw IOException("Could not finalize imported repository")
            val record = JSONObject().put("id", id).put("name", name).put("createdAt", System.currentTimeMillis())
            metadata(id).writeText(record.toString(), Charsets.UTF_8)
            return mapOf("id" to id, "name" to name, "path" to destination.canonicalPath)
        } catch (error: Throwable) {
            staging.deleteRecursively()
            destination.deleteRecursively()
            metadata(id).delete()
            throw error
        }
    }

    fun list(): List<Map<String, Any>> = root.listFiles()
        .orEmpty()
        .asSequence()
        .filter { it.isDirectory && !it.name.startsWith(".") }
        .mapNotNull { directory ->
            runCatching {
                val record = JSONObject(metadata(directory.name).readText(Charsets.UTF_8))
                mapOf(
                    "id" to record.getString("id"),
                    "name" to record.getString("name"),
                    "path" to directory.canonicalPath,
                )
            }.getOrNull()
        }
        .sortedBy { it["name"].toString().lowercase() }
        .toList()

    fun remove(id: String) {
        require(id.matches(Regex("[0-9a-fA-F-]{36}"))) { "Invalid repository ID" }
        val directory = File(root, id).canonicalFile
        require(directory.parentFile == root.canonicalFile) { "Invalid repository path" }
        if (!directory.deleteRecursively()) throw IOException("Could not remove imported repository")
        metadata(id).delete()
    }

    fun requireRepositoryPath(path: String): File {
        val file = File(path).canonicalFile
        val repository = list().firstOrNull { it["path"] == file.canonicalPath }
            ?: throw IOException("Workspace is not an imported Codexis repository")
        @Suppress("UNUSED_VARIABLE") val checked = repository
        return file
    }

    fun listFiles(directoryPath: String): List<Map<String, Any>> {
        val directory = requireContainedPath(directoryPath)
        if (!directory.isDirectory) throw IOException("Requested path is not a directory")
        return directory.listFiles().orEmpty()
            .filter { it.name != ".git" }
            .sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
            .map { file ->
                mapOf(
                    "path" to file.canonicalPath,
                    "name" to file.name,
                    "isDirectory" to file.isDirectory,
                    "size" to if (file.isFile) file.length() else 0L,
                )
            }
    }

    fun readFile(path: String): String {
        val file = requireContainedPath(path)
        if (!file.isFile) throw IOException("Requested path is not a file")
        if (file.length() > MAX_TEXT_BYTES) throw IOException("File exceeds the 2 MiB viewer limit")
        val bytes = file.readBytes()
        if (bytes.size > MAX_TEXT_BYTES) throw IOException("File exceeds the 2 MiB viewer limit")
        if (bytes.contains(0.toByte())) throw IOException("Binary files cannot be displayed as text")
        return bytes.toString(Charsets.UTF_8)
    }

    private fun requireContainedPath(path: String): File {
        val file = File(path).canonicalFile
        val repository = list().asSequence().map { File(it["path"] as String).canonicalFile }
            .firstOrNull { file.path == it.path || file.path.startsWith(it.path + File.separator) }
            ?: throw IOException("Path is outside imported repositories")
        if (file.path != repository.path && !file.path.startsWith(repository.path + File.separator)) {
            throw IOException("Path is outside imported repositories")
        }
        return file
    }

    private fun copyTree(treeUri: Uri, parentDocumentId: String, destination: File) {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocumentId)
        val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE)
        resolver.query(childrenUri, columns, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                val childId = cursor.getString(idColumn)
                val childName = cursor.getString(nameColumn).safeName()
                val childMime = cursor.getString(mimeColumn)
                val target = File(destination, childName)
                if (childMime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    if (!target.mkdirs() && !target.isDirectory) throw IOException("Could not create $childName")
                    copyTree(treeUri, childId, target)
                } else {
                    val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, childId)
                    resolver.openInputStream(documentUri)?.use { input ->
                        target.outputStream().use { output -> input.copyTo(output) }
                    } ?: throw IOException("Could not read $childName from selected provider")
                }
            }
        } ?: throw IOException("Could not list the selected folder")
    }

    private fun displayName(uri: Uri): String = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        ?.takeIf { !it.isNullOrBlank() }
        ?: uri.lastPathSegment?.substringAfterLast(':')?.takeIf { it.isNotBlank() }
        ?: "Imported repository"

    private fun metadata(id: String) = File(metadataRoot, "$id.json")

    private fun String.safeName(): String {
        val normalized = trim().replace(Regex("[/\\\\\\u0000-\\u001f]"), "_")
        return normalized.takeIf { it.isNotBlank() && it != "." && it != ".." } ?: "repository"
    }

    companion object {
        private const val MAX_TEXT_BYTES = 2 * 1024 * 1024
    }
}
