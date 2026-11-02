package dev.codexis.codexis

import java.io.ByteArrayInputStream
import java.io.IOException
import java.nio.charset.StandardCharsets
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LspFrameCodecTest {
    @Test
    fun contentLengthCountsUtf8Bytes() {
        val body = "{\"jsonrpc\":\"2.0\",\"result\":\"café 東京 🧭\"}"
            .toByteArray(StandardCharsets.UTF_8)

        val frame = LspFrameCodec.encode(body)
        val header = frame.copyOfRange(0, frame.indexOf(0x0d) + 4)
            .toString(StandardCharsets.US_ASCII)
        assertTrue(header.startsWith("Content-Length: ${body.size}\r\n\r\n"))
        assertTrue(body.size > body.toString(StandardCharsets.UTF_8).length)
        assertArrayEquals(body, LspFrameCodec.readBody(ByteArrayInputStream(frame)))
    }

    @Test
    fun readsHeaderAndBodyAcrossPartialReads() {
        val body = "{\"method\":\"textDocument/didOpen\",\"params\":{\"text\":\"λ\"}}"
            .toByteArray(StandardCharsets.UTF_8)
        val input = PartialInputStream(LspFrameCodec.encode(body), 2)

        assertArrayEquals(body, LspFrameCodec.readBody(input))
    }

    @Test(expected = IOException::class)
    fun rejectsDuplicateContentLength() {
        val frame = "Content-Length: 2\r\ncontent-length: 2\r\n\r\n{}"
            .toByteArray(StandardCharsets.US_ASCII)
        LspFrameCodec.readBody(ByteArrayInputStream(frame))
    }

    @Test(expected = IOException::class)
    fun rejectsTruncatedBody() {
        val frame = "Content-Length: 8\r\n\r\n{}".toByteArray(StandardCharsets.US_ASCII)
        LspFrameCodec.readBody(ByteArrayInputStream(frame))
    }

    @Test
    fun acceptsAdditionalHeadersCaseInsensitively() {
        val body = "{}".toByteArray(StandardCharsets.UTF_8)
        val frame = "content-type: application/vscode-jsonrpc; charset=utf-8\r\nContent-Length: ${body.size}\r\n\r\n"
            .toByteArray(StandardCharsets.US_ASCII) + body

        assertEquals("{}", LspFrameCodec.readBody(ByteArrayInputStream(frame)).toString(StandardCharsets.UTF_8))
    }

    private class PartialInputStream(private val bytes: ByteArray, private val maxRead: Int) : ByteArrayInputStream(bytes) {
        override fun read(target: ByteArray, offset: Int, length: Int): Int = super.read(target, offset, minOf(length, maxRead))
    }
}
