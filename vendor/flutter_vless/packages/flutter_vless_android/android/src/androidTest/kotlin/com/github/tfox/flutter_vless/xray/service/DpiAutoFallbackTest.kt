package com.github.tfox.flutter_vless.xray.service

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.DataInputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class DpiAutoFallbackTest {
    @Test fun automaticRetriesWhenTlsServerStaysSilent() {
        val server = ServerSocket(0, 8, InetAddress.getByName("127.0.0.1"))
        val executor = Executors.newSingleThreadExecutor()
        val connections = ConcurrentLinkedQueue<Socket>()
        val accepted = AtomicInteger()
        val firstHello = AtomicReference<ByteArray>()
        val firstHelloReceived = CountDownLatch(1)
        val retryReceived = CountDownLatch(1)
        val serverFailure = AtomicReference<Throwable>()
        val engine = ByeDpiEngine()
        var client: Socket? = null

        executor.execute {
            try {
                repeat(2) {
                    val connection = server.accept()
                    connections.add(connection)
                    if (accepted.incrementAndGet() == 1) {
                        val hello = ByteArray(6)
                        DataInputStream(connection.getInputStream()).readFully(hello)
                        firstHello.set(hello)
                        firstHelloReceived.countDown()
                        // Keep the TCP connection open and send no TLS response.
                    } else {
                        retryReceived.countDown()
                    }
                }
            } catch (error: Throwable) {
                if (!server.isClosed) serverFailure.set(error)
            }
        }

        try {
            val port = engine.start(4, "")
            assertTrue("ByeDPI did not start", port in 1..65535)
            client = Socket("127.0.0.1", port).apply { soTimeout = 3000 }
            val input = DataInputStream(client.getInputStream())
            client.getOutputStream().write(byteArrayOf(5, 1, 0))
            assertEquals(5, input.readUnsignedByte())
            assertEquals(0, input.readUnsignedByte())
            client.getOutputStream().write(
                byteArrayOf(
                    5, 1, 0, 1, 127, 0, 0, 1,
                    (server.localPort shr 8).toByte(), server.localPort.toByte(),
                ),
            )
            assertEquals(5, input.readUnsignedByte())
            assertEquals(0, input.readUnsignedByte())
            assertEquals(0, input.readUnsignedByte())
            input.skipBytes(6)
            val hello = byteArrayOf(0x16, 0x03, 0x01, 0x00, 0x01, 0x01)
            client.getOutputStream().apply { write(hello); flush() }

            assertTrue("Initial TLS hello did not reach the silent server", firstHelloReceived.await(3, TimeUnit.SECONDS))
            assertArrayEquals(hello, firstHello.get())
            assertTrue(
                "Automatic DPI profile never tried its next strategy after no TLS response: ${serverFailure.get()}",
                retryReceived.await(8, TimeUnit.SECONDS),
            )
        } finally {
            runCatching { client?.close() }
            engine.stop()
            server.close()
            connections.forEach { runCatching { it.close() } }
            executor.shutdownNow()
            executor.awaitTermination(2, TimeUnit.SECONDS)
        }
    }
}
