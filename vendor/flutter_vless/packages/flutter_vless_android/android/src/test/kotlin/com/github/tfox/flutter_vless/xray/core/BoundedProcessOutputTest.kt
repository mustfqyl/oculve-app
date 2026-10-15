package com.github.tfox.flutter_vless.xray.core

import java.io.ByteArrayInputStream
import java.io.InputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*

class BoundedProcessOutputTest {
    private fun finished(bytes: ByteArray): Process {
        val process = mock(Process::class.java)
        `when`(process.inputStream).thenReturn(ByteArrayInputStream(bytes))
        `when`(process.waitFor(anyLong(), any(TimeUnit::class.java))).thenReturn(true)
        return process
    }

    @Test fun readsSuccessfulOutput() {
        val process = finished("{\"stat\":[]}".toByteArray())
        assertEquals("{\"stat\":[]}", BoundedProcessOutput.read(process))
        verify(process, never()).destroy()
    }

    @Test fun doesNotWaitForeverForAnOpenOutputPipe() {
        val released = CountDownLatch(1)
        val process = mock(Process::class.java)
        `when`(process.exitValue()).thenAnswer {
            if (released.count > 0) throw IllegalThreadStateException() else 0
        }
        `when`(process.inputStream).thenReturn(object : InputStream() {
            override fun read(): Int { released.await(); return -1 }
        })
        doAnswer { released.countDown(); null }.`when`(process).destroy()
        val started = System.nanoTime()
        try {
            BoundedProcessOutput.read(process, timeoutMillis = 100)
            fail("Open pipe must time out")
        } catch (_: TimeoutException) { }
        assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started) < 2000)
        verify(process).destroy()
    }

    @Test fun rejectsOutputBeforeItCanGrowPastTheLimit() {
        val process = finished(ByteArray(8192))
        try {
            BoundedProcessOutput.read(process, maxBytes = 4096)
            fail("Oversized output must fail")
        } catch (error: java.util.concurrent.ExecutionException) {
            assertTrue(error.cause is java.io.IOException)
        }
    }

    @Test fun eofDoesNotHideAProcessThatHasNotExited() {
        val process = finished("ok".toByteArray())
        `when`(process.exitValue()).thenThrow(IllegalThreadStateException())
        `when`(process.waitFor(anyLong(), any(TimeUnit::class.java))).thenReturn(false)
        try {
            BoundedProcessOutput.read(process, timeoutMillis = 100)
            fail("Process exit must also be bounded")
        } catch (_: TimeoutException) { }
        verify(process, atLeastOnce()).destroy()
        verify(process, never()).destroyForcibly()
    }
}
