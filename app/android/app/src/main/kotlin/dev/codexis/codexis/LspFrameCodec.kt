package dev.codexis.codexis

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.nio.charset.StandardCharsets

/** LSP Content-Length framing. Lengths are UTF-8 octets, never character counts. */
internal object LspFrameCodec {
    private const val MAX_HEADER_BYTES = 8192
    private const val MAX_MESSAGE_BYTES = 32 * 1024 * 1024

    fun encode(body: ByteArray): ByteArray {
        require(body.size <= MAX_MESSAGE_BYTES) { "LSP message is too large" }
        val header = "Content-Length: ${body.size}\r\n\r\n".toByteArray(StandardCharsets.US_ASCII)
        return header + body
    }

    fun readBody(stream: InputStream): ByteArray {
        val headerBytes = ByteArrayOutputStream()
        var matched = 0
        while (headerBytes.size() < MAX_HEADER_BYTES) {
            val byte = stream.read()
            if (byte < 0) throw IOException("LSP stdout closed while reading headers")
            headerBytes.write(byte)
            matched = when {
                matched == 0 && byte == '\r'.code -> 1
                matched == 1 && byte == '\n'.code -> 2
                matched == 2 && byte == '\r'.code -> 3
                matched == 3 && byte == '\n'.code -> 4
                byte == '\r'.code -> 1
                else -> 0
            }
            if (matched == 4) break
        }
        if (matched != 4) throw IOException("LSP header is too large or malformed")
        val headers = headerBytes.toByteArray().toString(StandardCharsets.US_ASCII)
            .split("\r\n").mapNotNull { line ->
                val colon = line.indexOf(':')
                if (colon < 0) null else line.substring(0, colon).trim().lowercase() to line.substring(colon + 1).trim()
            }
        val contentLengths = headers.filter { it.first == "content-length" }.map { it.second.toIntOrNull() }
        if (contentLengths.size != 1) throw IOException("LSP Content-Length header missing or duplicated")
        val length = contentLengths.single() ?: throw IOException("Invalid LSP Content-Length")
        if (length < 0 || length > MAX_MESSAGE_BYTES) throw IOException("Invalid LSP Content-Length: $length")
        val body = ByteArray(length)
        var offset = 0
        while (offset < length) {
            val read = stream.read(body, offset, length - offset)
            if (read < 0) throw IOException("LSP stdout closed inside message body")
            if (read == 0) continue
            offset += read
        }
        return body
    }
}
