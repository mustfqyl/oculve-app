package com.github.tfox.flutter_vless.xray.service

import android.os.ParcelFileDescriptor
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import com.github.tfox.flutter_vless.xray.core.XrayCoreManager
import org.junit.Test
import org.mockito.Mockito.*

class SessionStopFailureTest {
    @Test fun alreadyStoppedServiceCannotStopTheNewGlobalCore() {
        val service = mock(XrayVPNService::class.java, CALLS_REAL_METHODS)
        XrayVPNService::class.java.getDeclaredField("recovery").apply {
            isAccessible = true; set(service, SessionRecoveryPolicy())
        }
        val newCore = mock(Process::class.java)
        val globalProcess = XrayCoreManager::class.java.getDeclaredField("xrayProcess").apply { isAccessible = true }
        val original = globalProcess.get(XrayCoreManager)
        globalProcess.set(XrayCoreManager, newCore)
        try {
            val stop = XrayVPNService::class.java.getDeclaredMethod("deactivateSession").apply { isAccessible = true }
            val result = runCatching { stop.invoke(service) as Boolean }
            verify(newCore, never()).destroy()
            assertTrue(result.getOrThrow())
            assertSame(newCore, globalProcess.get(XrayCoreManager))
        } finally {
            globalProcess.set(XrayCoreManager, original)
        }
    }

    @Test fun anUnstoppableWorkerCannotReleaseTheTunnelOrClaimShutdown() {
        // Skip the Android native-library constructor; invoke the production
        // teardown with a real recovery policy and an unresponsive child.
        val service = mock(XrayVPNService::class.java, CALLS_REAL_METHODS)
        val child = mock(Process::class.java)
        `when`(child.exitValue()).thenThrow(IllegalThreadStateException())
        val tunnel = mock(ParcelFileDescriptor::class.java)
        fun field(name: String) = XrayVPNService::class.java.getDeclaredField(name).apply { isAccessible = true }
        field("recovery").set(service, SessionRecoveryPolicy())
        field("process").set(service, child)
        field("tun").set(service, tunnel)
        val stop = XrayVPNService::class.java.getDeclaredMethod("deactivateSession").apply { isAccessible = true }
        assertFalse(stop.invoke(service) as Boolean)
        verify(tunnel, never()).close()
        assertSame(tunnel, field("tun").get(service))
        assertSame(child, field("process").get(service))
    }
}
