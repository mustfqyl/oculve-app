package com.github.tfox.flutter_vless.xray.core

import android.content.Context
import android.content.pm.ApplicationInfo
import com.github.tfox.flutter_vless.xray.dto.XrayConfig
import com.github.tfox.flutter_vless.xray.utils.AppConfigs
import java.io.ByteArrayInputStream
import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*

class DpiTrafficCountersTest {
    @Test fun statsQuerySelectsTheActiveProxyOrDpiOutbound() {
        val context = mock(Context::class.java)
        `when`(context.applicationInfo).thenReturn(ApplicationInfo().apply { nativeLibraryDir = "/fixture" })
        val core = mock(Process::class.java)
        `when`(core.exitValue()).thenThrow(IllegalThreadStateException())
        val field = XrayCoreManager::class.java.getDeclaredField("xrayProcess").apply { isAccessible = true }
        val previousCore = field.get(XrayCoreManager)
        val previousConfig = AppConfigs.V2RAY_CONFIG
        field.set(XrayCoreManager, core)
        val json = """{"stat":[{"name":"outbound>>>byedpi>>>traffic>>>uplink","value":1000},{"name":"outbound>>>byedpi>>>traffic>>>downlink","value":2000},{"name":"outbound>>>proxy>>>traffic>>>uplink","value":3000},{"name":"outbound>>>proxy>>>traffic>>>downlink","value":4000}]}"""
        try {
            for (dpi in listOf(false, true)) {
                AppConfigs.V2RAY_CONFIG = XrayConfig(DPI_BYPASS = dpi)
                val query = mock(Process::class.java)
                `when`(query.inputStream).thenReturn(ByteArrayInputStream(json.toByteArray()))
                var command: List<*> = emptyList<Any>()
                mockConstruction(ProcessBuilder::class.java, withSettings().defaultAnswer(RETURNS_SELF)) { builder, construction ->
                    command = (construction.arguments().single() as Array<*>).toList()
                    `when`(builder.start()).thenReturn(query)
                }.use {
                    val counters = XrayCoreManager.getV2rayTraffic(context)
                    val tag = if (dpi) "byedpi" else "proxy"
                    assertTrue(command.contains("outbound>>>$tag>>>"))
                    assertEquals(if (dpi) 1000L else 3000L, counters[2])
                    assertEquals(if (dpi) 2000L else 4000L, counters[3])
                }
            }
        } finally {
            field.set(XrayCoreManager, previousCore)
            AppConfigs.V2RAY_CONFIG = previousConfig
        }
    }
}
