package com.github.tfox.flutter_vless.xray.service

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.github.tfox.flutter_vless.xray.core.XrayDiagnosticsStore
import com.github.tfox.flutter_vless.xray.dto.XrayConfig
import com.github.tfox.flutter_vless.xray.utils.AppConfigs
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Offline, real VLESS server and real Android TUN; no production account or traffic. */
@RunWith(AndroidJUnit4::class)
class OculveTunnelStartupTest {
    @Test fun defaultAppProfileCarriesHostTrafficThroughRealVlessTunnel() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        assertNull("Authorize ACTIVATE_VPN for this isolated test APK", VpnService.prepare(context))
        val workers = Executors.newCachedThreadPool()
        val http = ServerSocket(0)
        val serverPort = ServerSocket(0).use { it.localPort }
        val serverConfig = File(context.noBackupFilesDir, "oculve-synthetic-server.json")
        val marker = "oculve-vless-tunnel-verified"
        // The test server permits only its own loopback HTTP endpoint. Modern Xray
        // otherwise blocks private destinations for remote-proxy inbound protocols.
        serverConfig.writeText("""{"log":{"loglevel":"debug"},"inbounds":[{"listen":"127.0.0.1","port":$serverPort,"protocol":"vless","settings":{"clients":[{"id":"11111111-1111-4111-8111-111111111111"}],"decryption":"none"}}],"outbounds":[{"protocol":"freedom","settings":{"redirect":"127.0.0.1:${http.localPort}","finalRules":[{"action":"allow","ip":["127.0.0.1/32"],"port":"${http.localPort}"}]}}]}""")
        val server = ProcessBuilder(File(context.applicationInfo.nativeLibraryDir, "libxray.so").path,
            "run", "-config", serverConfig.path).redirectErrorStream(true).start()
        val syntheticServerLogs = StringBuffer()
        workers.submit { server.inputStream.bufferedReader().useLines { lines ->
            lines.forEach { syntheticServerLogs.append(it).append('\n') }
        } }
        workers.submit {
            try {
                while (!http.isClosed) {
                    val client = http.accept()
                    // Captured Android background DNS must not block the owned HTTP probe.
                    workers.submit {
                        runCatching { client.use { socket ->
                            socket.soTimeout = 1500
                            val reader = socket.getInputStream().bufferedReader()
                            val firstLine = reader.readLine()
                            if (firstLine?.startsWith("GET / HTTP/") == true) {
                                while (!reader.readLine().isNullOrEmpty()) { }
                                socket.getOutputStream().write("HTTP/1.1 200 OK\r\nContent-Length: ${marker.length}\r\nConnection: close\r\n\r\n$marker".toByteArray())
                            }
                        } }
                    }
                }
            } catch (_: Exception) { }
        }
        try {
            repeat(30) {
                if (runCatching { Socket("127.0.0.1", serverPort).close() }.isFailure) Thread.sleep(100)
            }
            assertTrue("Synthetic VLESS server did not start", server.isAlive)
            val json = JSONObject(instrumentation.context.assets.open("oculve-vless-tcp.json")
                .bufferedReader().use { it.readText() })
            json.getJSONArray("outbounds").getJSONObject(0).getJSONObject("settings")
                .getJSONArray("vnext").getJSONObject(0).put("address", "127.0.0.1").put("port", serverPort)
            val accepted = CountDownLatch(1)
            var resultCode = -1
            val profile = XrayConfig(V2RAY_FULL_JSON_CONFIG = json.toString(),
                ANDROID_DNS_POLICY = "proxy", ANDROID_DNS_PROXY_OUTBOUND_TAG = "proxy")
            context.startForegroundService(Intent(context, XrayVPNService::class.java)
                .putExtra("COMMAND", AppConfigs.V2RAY_SERVICE_COMMANDS.START_SERVICE)
                .putExtra("V2RAY_CONFIG", profile).putExtra("PROXY_ONLY", false)
                .putExtra("start_receiver", object : ResultReceiver(Handler(Looper.getMainLooper())) {
                    override fun onReceiveResult(code: Int, data: Bundle?) {
                        resultCode = code; accepted.countDown()
                    }
                }))
            assertTrue("Service never acknowledged profile", accepted.await(20, TimeUnit.SECONDS))
            assertEquals("Profile rejected: ${XrayDiagnosticsStore.snapshot(context.filesDir)}", 0, resultCode)
            var response = ""
            var lastFailure = ""
            repeat(12) {
                if (!response.contains(marker)) {
                    response = runCatching {
                        Socket().use { socket ->
                            socket.soTimeout = 2000
                            socket.connect(java.net.InetSocketAddress("192.0.2.99", 18081), 1000)
                            socket.getOutputStream().write("GET / HTTP/1.1\r\nHost: synthetic.test\r\nConnection: close\r\n\r\n".toByteArray())
                            socket.getInputStream().bufferedReader().readText()
                        }
                    }.onFailure { lastFailure = it.toString() }.getOrDefault("")
                    if (!response.contains(marker)) Thread.sleep(300)
                }
            }
            assertTrue("TUN did not carry application bytes: $lastFailure\n${XrayDiagnosticsStore.snapshot(context.filesDir)}\nSynthetic server only: $syntheticServerLogs", response.contains(marker))
            assertTrue("Native forwarding readiness not reached", XrayDiagnosticsStore.snapshot(context.filesDir).lineSequence().any { it == "CONNECTED" })
            // A second real server forces a transport replacement while the
            // old Android interface must stay installed and capture traffic.
            val secondPort = ServerSocket(0).use { it.localPort }
            val secondFile = File(context.noBackupFilesDir, "oculve-synthetic-server-switch.json")
            secondFile.writeText(serverConfig.readText().replace("\"port\":$serverPort", "\"port\":$secondPort"))
            val secondServer = ProcessBuilder(File(context.applicationInfo.nativeLibraryDir, "libxray.so").path,
                "run", "-config", secondFile.path).redirectErrorStream(true).start()
            workers.submit { secondServer.inputStream.bufferedReader().useLines { lines -> lines.forEach { } } }
            try {
                Thread.sleep(400)
                assertTrue(secondServer.isAlive)
                json.getJSONArray("outbounds").getJSONObject(0).getJSONObject("settings")
                    .getJSONArray("vnext").getJSONObject(0).put("port", secondPort)
                val switched = CountDownLatch(1)
                var switchCode = -1
                context.startForegroundService(Intent(context, XrayVPNService::class.java)
                    .putExtra("COMMAND", AppConfigs.V2RAY_SERVICE_COMMANDS.START_SERVICE)
                    .putExtra("V2RAY_CONFIG", profile.copy(V2RAY_FULL_JSON_CONFIG = json.toString()))
                    .putExtra("PRESERVE_TUNNEL", true)
                    .putExtra("start_receiver", object : ResultReceiver(Handler(Looper.getMainLooper())) {
                        override fun onReceiveResult(code: Int, data: Bundle?) { switchCode = code; switched.countDown() }
                    }))
                assertTrue(switched.await(20, TimeUnit.SECONDS)); assertEquals(0, switchCode)
                repeat(100) {
                    if (!XrayDiagnosticsStore.snapshot(context.filesDir).lineSequence().any { it == "CONNECTED" }) Thread.sleep(100)
                }
                val events = XrayDiagnosticsStore.snapshot(context.filesDir).lineSequence().toList()
                assertTrue("The existing TUN was not retained: $events", events.contains("TUN_RETAINED"))
                assertFalse("Replacement recreated the TUN: $events", events.contains("TUN_ESTABLISHED"))
                assertTrue("New server never forwarded traffic: $events", events.contains("CONNECTED"))
                Socket().use { socket ->
                    socket.soTimeout = 3000
                    socket.connect(java.net.InetSocketAddress("192.0.2.99", 18081), 1000)
                    socket.getOutputStream().write("GET / HTTP/1.1\r\nHost: synthetic.test\r\nConnection: close\r\n\r\n".toByteArray())
                    assertTrue(socket.getInputStream().bufferedReader().readText().contains(marker))
                }
            } finally {
                secondServer.destroy(); secondServer.waitFor(3, TimeUnit.SECONDS); secondFile.delete()
            }

        } finally {
            context.startService(Intent(context, XrayVPNService::class.java)
                .putExtra("COMMAND", AppConfigs.V2RAY_SERVICE_COMMANDS.STOP_SERVICE))
            Thread.sleep(800)
            http.close(); server.destroy(); server.waitFor(3, TimeUnit.SECONDS)
            workers.shutdownNow(); serverConfig.delete()
        }
    }
}
