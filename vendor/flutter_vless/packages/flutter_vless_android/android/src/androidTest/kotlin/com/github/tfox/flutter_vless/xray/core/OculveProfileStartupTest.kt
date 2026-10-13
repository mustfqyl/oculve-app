package com.github.tfox.flutter_vless.xray.core

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.github.tfox.flutter_vless.xray.dto.XrayConfig
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Real app-imported, synthetic profiles must reach the packaged native parser. */
@RunWith(AndroidJUnit4::class)
class OculveProfileStartupTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

    @Test fun appDefaultsPassAndroidPreflightAndRealXrayValidation() {
        for (transport in listOf("tcp", "tls", "reality")) {
            val raw = instrumentation.context.assets.open("oculve-vless-$transport.json")
                .bufferedReader().use { it.readText() }
            val candidate = XrayConfig(V2RAY_FULL_JSON_CONFIG = raw,
                ANDROID_DNS_POLICY = "proxy", ANDROID_DNS_PROXY_OUTBOUND_TAG = "proxy")
            XrayCoreManager.validateConfiguration(candidate)
            val dns = AndroidTunnelDnsPolicy.prepare(raw, "proxy", "proxy") {
                error("Literal fixture endpoints must never need bootstrap DNS")
            }
            candidate.V2RAY_FULL_JSON_CONFIG = dns.configJson
            val runtime = XrayCoreManager.buildRuntimeConfigJson(candidate,
                context.noBackupFilesDir, LocalProxyCredentials.generate())
            assertTrue("Packaged Xray rejected Oculve's default $transport profile",
                XrayCoreManager.validateNative(context, runtime))
        }
    }
}
