package com.github.tfox.flutter_vless.xray.core

import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*
import java.util.concurrent.TimeUnit

class ChildProcessCompatTest {
    // Android's JVM stub is SDK 0: exercise every pre-26 branch without
    // invoking methods which are absent on supported older Android devices.
    @Test fun olderAndroidChecksExitValueWithoutCallingIsAlive() {
        val process = mock(Process::class.java)
        `when`(process.exitValue()).thenThrow(IllegalThreadStateException())
        assertTrue(ChildProcessCompat.isAlive(process))
        doReturn(0).`when`(process).exitValue()
        assertFalse(ChildProcessCompat.isAlive(process))
        verify(process, never()).isAlive
    }
    @Test fun olderAndroidWaitHasADeadline() {
        val process = mock(Process::class.java)
        `when`(process.exitValue()).thenThrow(IllegalThreadStateException())
        assertFalse(ChildProcessCompat.waitFor(process, 20, TimeUnit.MILLISECONDS))
        verify(process, never()).waitFor(anyLong(), any(TimeUnit::class.java))
    }
    @Test fun olderAndroidRecognizesAnExitedProcessImmediately() {
        val process = mock(Process::class.java)
        assertTrue(ChildProcessCompat.waitFor(process, 0, TimeUnit.SECONDS))
    }
    @Test fun olderAndroidTerminationPreservesTheAvailableKillMethod() {
        val process = mock(Process::class.java)
        ChildProcessCompat.destroyForcibly(process)
        verify(process).destroy()
        verify(process, never()).destroyForcibly()
    }
}
