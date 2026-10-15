package com.github.tfox.flutter_vless

import android.content.Context
import android.content.Intent
import android.net.VpnService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Test
import org.mockito.Mockito.*
import com.github.tfox.flutter_vless.xray.dto.XrayConfig
import com.github.tfox.flutter_vless.xray.service.AuthorizedProfileStore
import com.github.tfox.flutter_vless.xray.service.SessionRecoveryPolicy
import com.github.tfox.flutter_vless.xray.service.XrayVPNService
import org.junit.Assert.*

class VpnConsentBoundaryTest {
    @Test fun directServiceStartCannotPersistOrArmAnUnconsentedTunnel() {
        val service = mock(XrayVPNService::class.java, CALLS_REAL_METHODS)
        val profiles = mock(AuthorizedProfileStore::class.java)
        val recovery = SessionRecoveryPolicy()
        fun set(name: String, value: Any) = XrayVPNService::class.java.getDeclaredField(name).apply {
            isAccessible = true; set(service, value)
        }
        set("requests", java.util.concurrent.atomic.AtomicLong(1))
        set("profiles", profiles)
        set("recovery", recovery)
        val rejected = mutableListOf<String>()
        val reject: (String) -> Unit = { rejected.add(it) }
        mockStatic(VpnService::class.java).use { consent ->
            consent.`when`<Intent> { VpnService.prepare(service) }.thenReturn(mock(Intent::class.java))
            val accept = XrayVPNService::class.java.getDeclaredMethod("acceptSession", XrayConfig::class.java,
                Boolean::class.javaPrimitiveType, Long::class.javaPrimitiveType, kotlin.jvm.functions.Function1::class.java).apply { isAccessible = true }
            for (explicit in listOf(false, true)) {
                assertFalse(accept.invoke(service, XrayConfig(), explicit, 1L, reject) as Boolean)
            }
            assertEquals(listOf("VPN_PERMISSION_REQUIRED", "VPN_PERMISSION_REQUIRED"), rejected)
            assertFalse(recovery.authorized)
            verifyNoInteractions(profiles)
        }
    }

    @Test fun proxyOnlyDoesNotRequireVpnConsent() {
        val context = mock(Context::class.java)
        val plugin = FlutterVlessPlugin()
        FlutterVlessPlugin::class.java.getDeclaredField("context").apply { isAccessible = true; set(plugin, context) }
        mockStatic(VpnService::class.java).use { consent ->
            consent.`when`<Intent> { VpnService.prepare(context) }.thenReturn(mock(Intent::class.java))
            val result = mock(MethodChannel.Result::class.java)
            plugin.onMethodCall(MethodCall("startVless", mapOf("proxy_only" to true)), result)
            // This deliberately invalid config reaches validation, not the VPN consent gate.
            verify(result).error(eq("INVALID_CONFIG"), anyString(), isNull())
            consent.verify({ VpnService.prepare(context) }, never())
        }
    }

    @Test fun missingConsentRejectsBothStartAndReplaceBeforeCreatingAService() {
        val context = mock(Context::class.java)
        val plugin = FlutterVlessPlugin()
        FlutterVlessPlugin::class.java.getDeclaredField("context").apply { isAccessible = true; set(plugin, context) }
        mockStatic(VpnService::class.java).use { consent ->
            consent.`when`<Intent> { VpnService.prepare(context) }.thenReturn(mock(Intent::class.java))
            for (method in listOf("startVless", "replaceVless")) {
                val result = mock(MethodChannel.Result::class.java)
                plugin.onMethodCall(MethodCall(method, emptyMap<String, Any>()), result)
                verify(result).error(eq("VPN_PERMISSION_REQUIRED"), anyString(), isNull())
                verify(result, never()).success(any())
            }
            verify(context, never()).startService(any(Intent::class.java))
            verify(context, never()).startForegroundService(any(Intent::class.java))
        }
    }
}
