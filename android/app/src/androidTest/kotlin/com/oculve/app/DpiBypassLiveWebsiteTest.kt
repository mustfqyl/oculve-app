package com.oculve.app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Bundle
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.github.tfox.flutter_vless.xray.core.XrayCoreManager
import com.github.tfox.flutter_vless.xray.dto.XrayConfig
import com.github.tfox.flutter_vless.xray.service.XrayVPNService
import com.github.tfox.flutter_vless.xray.utils.AppConfigs
import org.json.JSONObject
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.HttpURLConnection
import java.net.Socket
import java.net.URL
import java.util.concurrent.TimeUnit

/** Manual acceptance test for the real Oculve Xray → ByeDPI → Android TUN path. */
@RunWith(AndroidJUnit4::class)
class DpiBypassLiveWebsiteTest {
    @Test fun automaticDpiVpnLoadsRequestedSitesWithoutAccountOrNode() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val profileFile = File(context.noBackupFilesDir, "flutter_vless_authorized_v1.bin")
        val diagnosticsFile = File(context.filesDir, "flutter_vless_events_v2.log")
        val previousDiagnostics = diagnosticsFile.takeIf(File::isFile)?.readBytes()
        val baselineEvents = XrayCoreManager.getProviderDebugSnapshot(context)
        assertFalse("An Oculve VPN service is already running; refusing to replace it", isOculveServiceRunning(context))
        assertFalse("Existing authorized profile must be preserved", profileFile.exists())
        assertFalse("Existing Xray config must be preserved", File(context.filesDir, "config.json").exists())
        assertFalse("Existing delay config must be preserved", File(context.filesDir, "temp_delay_config.json").exists())
        val connectivity = context.getSystemService(ConnectivityManager::class.java)
        assertFalse(
            "Another VPN is active; refusing to replace it",
            connectivity.allNetworks.any { connectivity.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true },
        )

        val permission = VpnService.prepare(context)
        report(instrumentation, "vpn_permission_required=${permission != null}")
        if (permission != null) {
            val appLaunch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            assertTrue("Could not bring Oculve to the foreground", appLaunch != null)
            instrumentation.startActivitySync(appLaunch!!.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            Thread.sleep(500)
            permission.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(permission)
            val permissionDeadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(180)
            while (VpnService.prepare(context) != null && System.nanoTime() < permissionDeadline) Thread.sleep(400)
        }
        assertNull("Approve the Oculve VPN permission prompt to continue", VpnService.prepare(context))
        val dpiProfile = InstrumentationRegistry.getArguments().getString("profile")?.toIntOrNull() ?: 4
        require(dpiProfile in 0..4) { "DPI profile must be in 0..4" }

        val configJson = JSONObject(
            """{
              "log":{"loglevel":"warning","access":"none","error":"none","dnsLog":false},
              "inbounds":[{"tag":"socks","listen":"127.0.0.1","port":10807,"protocol":"socks",
                "settings":{"auth":"noauth","udp":true},
                "sniffing":{"enabled":true,"destOverride":["http","tls","quic"],"routeOnly":true}}],
              "outbounds":[
                {"tag":"byedpi","protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":65535}]},"targetStrategy":"UseIP"},
                {"tag":"direct","protocol":"freedom"},
                {"tag":"block","protocol":"blackhole"}],
              "dns":{"servers":["https://cloudflare-dns.com/dns-query"],"queryStrategy":"UseIPv4","disableFallback":true},
              "routing":{"domainStrategy":"AsIs","rules":[
                {"type":"field","domain":["full:www.gstatic.com"],"outboundTag":"byedpi"},
                {"type":"field","domain":["full:cp.cloudflare.com"],"outboundTag":"byedpi"}]}
            }""".trimIndent(),
        )
        val profile = XrayConfig(
            V2RAY_FULL_JSON_CONFIG = configJson.toString(),
            REMARK = "DPI Bypass live website verification",
            ANDROID_DNS_POLICY = "proxy",
            ANDROID_DNS_PROXY_OUTBOUND_TAG = "byedpi",
            DPI_BYPASS = true,
            DPI_PROFILE = dpiProfile,
        )
        assertFalse("The live-test UID must be included in VPN routing", context.packageName in profile.BLOCKED_APPS)
        var startAttempted = false
        var sessionStarted = false
        var cleanupConfirmed = false
        var testFailure: Throwable? = null
        try {
            startAttempted = true
            context.startForegroundService(
                Intent(context, XrayVPNService::class.java)
                    .putExtra("COMMAND", AppConfigs.V2RAY_SERVICE_COMMANDS.START_SERVICE)
                    .putExtra("V2RAY_CONFIG", profile)
                    .putExtra("PROXY_ONLY", false),
            )
            val startDeadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(25)
            var lastEvents = ""
            while (!sessionStarted && System.nanoTime() < startDeadline) {
                lastEvents = XrayCoreManager.getProviderDebugSnapshot(context)
                val events = eventLines(lastEvents)
                val fresh = lastEvents != baselineEvents
                sessionStarted = fresh && events.firstOrNull() == "SESSION_START"
                val rejected = if (fresh) events.firstOrNull {
                    it in setOf("CONFIG_REJECTED", "NATIVE_VALIDATION_FAILED", "ENDPOINT_RESOLUTION_FAILED", "PROFILE_SAVE_FAILED")
                } else null
                if (rejected != null) break
                if (!sessionStarted) Thread.sleep(250)
            }
            report(instrumentation, "service_session_started=$sessionStarted events=${lastEvents.replace('\n', ',')}")
            assertTrue("Oculve did not accept/start the temporary session; events=$lastEvents", sessionStarted)

            val connectedDeadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(90)
            var connected = false
            while (!connected && System.nanoTime() < connectedDeadline) {
                lastEvents = XrayCoreManager.getProviderDebugSnapshot(context)
                val events = eventLines(lastEvents)
                connected = lastEvents != baselineEvents && events.firstOrNull() == "SESSION_START" &&
                    events.drop(1).any { it == "CONNECTED" }
                if (!connected) Thread.sleep(400)
            }
            report(instrumentation, "tunnel_connected=$connected events=${lastEvents.replace('\n', ',')}")
            assertTrue("Oculve's native DPI forwarding never became ready; events=$lastEvents", connected)
            val vpnNetworks = connectivity.allNetworks.filter {
                connectivity.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
            }
            assertTrue("Expected exactly the VPN established by this test, found ${vpnNetworks.size}", vpnNetworks.size == 1)
            val vpn = vpnNetworks.single()
            val vpnProperties = requireNotNull(connectivity.getLinkProperties(vpn))
            val vpnDns = vpnProperties.dnsServers.map { it.hostAddress }
            report(instrumentation, "vpn_active=true dns=${vpnDns.joinToString()}")
            assertTrue("Unexpected system DNS on the active VPN: $vpnDns", vpnDns == listOf("198.18.0.2"))
            assertTrue(
                "Oculve VPN does not publish an IPv4 default route: ${vpnProperties.routes}",
                vpnProperties.routes.any { it.destination.prefixLength == 0 && it.destination.address.hostAddress == "0.0.0.0" },
            )

            val failures = mutableListOf<String>()
            val controlBytesBefore = runCatching { outboundTrafficBytes(context) }.getOrNull()
            var control: HttpURLConnection? = null
            try {
                control = vpn.openConnection(URL("https://example.com/")) as HttpURLConnection
                control.connectTimeout = 15_000
                control.readTimeout = 15_000
                control.instanceFollowRedirects = true
                control.useCaches = false
                val status = control.responseCode
                report(instrumentation, "control=example.com http=$status")
                if (status !in 200..399) failures += "example.com control returned HTTP $status"
            } catch (error: Exception) {
                val detail = errorDetail(error)
                report(instrumentation, "control=example.com failed=$detail")
                failures += "example.com VPN control failed: $detail"
            } finally {
                control?.disconnect()
                if (controlBytesBefore != null) {
                    val after = runCatching { outboundTrafficBytes(context) }
                    if (after.isSuccess) {
                        val delta = after.getOrThrow() - controlBytesBefore
                        report(instrumentation, "control_traffic=example.com byedpi_bytes_delta=$delta")
                        if (delta <= 0) failures += "example.com control did not reach the ByeDPI outbound"
                    } else failures += "example.com Xray outbound stats unavailable after request"
                } else failures += "example.com Xray outbound stats unavailable before request"
            }
            for (host in listOf("roblox.com", "discord.com", "wattpad.com")) {
                val dnsBefore = runCatching { outboundTrafficBytes(context) }.getOrNull()
                try {
                    val dns = queryVpnDns(host, vpn)
                    val dnsAfter = runCatching { outboundTrafficBytes(context) }.getOrNull()
                    val delta = if (dnsBefore != null && dnsAfter != null) dnsAfter - dnsBefore else null
                    report(instrumentation, "dns=$host udp=${dns.first} tcp=${dns.second} byedpi_bytes_delta=$delta")
                    if (!dns.first.valid || !dns.second.valid) {
                        failures += "$host DNS invalid: udp=${dns.first} tcp=${dns.second}"
                    }
                    if (delta == null || delta <= 0) failures += "$host DNS did not reach the ByeDPI outbound"
                } catch (error: Exception) {
                    val detail = errorDetail(error)
                    report(instrumentation, "dns=$host failed=$detail")
                    failures += "$host DNS failed: $detail"
                }
                var connection: HttpURLConnection? = null
                val requestBytesBefore = runCatching { outboundTrafficBytes(context) }.getOrNull()
                if (requestBytesBefore == null) failures += "$host Xray outbound stats unavailable before request"
                try {
                    connection = vpn.openConnection(URL("https://$host/")) as HttpURLConnection
                    connection.connectTimeout = 30_000
                    connection.readTimeout = 45_000
                    connection.instanceFollowRedirects = true
                    connection.useCaches = false
                    connection.requestMethod = "GET"
                    val status = connection.responseCode
                    val finalUrl = connection.url
                    report(instrumentation, "website=$host http=$status final_host=${finalUrl.host}")
                    if (status !in 200..399) failures += "$host returned HTTP $status"
                    if (finalUrl.protocol != "https" || !isSameSiteOrSubdomain(host, finalUrl.host)) {
                        failures += "$host redirected outside its HTTPS site to ${finalUrl.host}"
                    }
                } catch (error: Exception) {
                    val detail = errorDetail(error)
                    report(instrumentation, "website=$host failed=$detail")
                    failures += "$host failed: $detail"
                } finally {
                    connection?.disconnect()
                    if (requestBytesBefore != null) {
                        val after = runCatching { outboundTrafficBytes(context) }
                        if (after.isSuccess) {
                            val delta = after.getOrThrow() - requestBytesBefore
                            report(instrumentation, "website_traffic=$host byedpi_bytes_delta=$delta")
                            if (delta <= 0) failures += "$host request did not reach the ByeDPI outbound"
                        } else {
                            failures += "$host Xray outbound stats unavailable after request"
                        }
                    }
                }
            }
            assertTrue("Websites did not load through the actual Oculve DPI VPN: ${failures.joinToString()}", failures.isEmpty())
        } catch (failure: Throwable) {
            testFailure = failure
            throw failure
        } finally {
            try {
                if (startAttempted) {
                    try {
                        val latest = XrayCoreManager.getProviderDebugSnapshot(context)
                        sessionStarted = sessionStarted || (latest != baselineEvents && eventLines(latest).firstOrNull() == "SESSION_START")
                        stopTemporarySession(context, instrumentation, sessionStarted)
                        cleanupConfirmed = !hasActiveVpn(context) && !isOculveServiceRunning(context) && !profileFile.exists()
                    } catch (cleanup: Throwable) {
                        if (testFailure != null) testFailure!!.addSuppressed(cleanup) else throw cleanup
                    }
                }
            } finally {
                try {
                    if (cleanupConfirmed && !hasActiveVpn(context) && !isOculveServiceRunning(context) && !profileFile.exists()) {
                        if (previousDiagnostics == null) {
                            check(diagnosticsFile.delete() || !diagnosticsFile.exists())
                        } else {
                            diagnosticsFile.writeBytes(previousDiagnostics)
                        }
                    } else if (startAttempted) {
                        report(instrumentation, "diagnostics_restore_skipped=true; live state preserved for inspection")
                    }
                } catch (restore: Throwable) {
                    if (testFailure != null) testFailure!!.addSuppressed(restore) else throw restore
                }
            }
        }
    }

    private data class DnsReply(val summary: String, val valid: Boolean) {
        override fun toString() = summary
    }

    private fun queryVpnDns(host: String, vpn: Network): Pair<DnsReply, DnsReply> {
        val id = 0x4f43
        val query = ByteArrayOutputStream()
        DataOutputStream(query).use { output ->
            output.writeShort(id)
            output.writeShort(0x0100)
            output.writeShort(1)
            output.writeShort(0) // ANCOUNT
            output.writeInt(0) // NSCOUNT, ARCOUNT
            host.split('.').forEach { label ->
                val bytes = label.toByteArray(Charsets.US_ASCII)
                require(bytes.size in 1..63)
                output.writeByte(bytes.size)
                output.write(bytes)
            }
            output.writeByte(0)
            output.writeShort(1) // A
            output.writeShort(1) // IN
        }
        val address = InetAddress.getByAddress(byteArrayOf(198.toByte(), 18, 0, 2))
        val request = query.toByteArray()
        fun describe(response: ByteArray): DnsReply {
            require(response.size >= 12) { "short DNS reply" }
            val responseId = ((response[0].toInt() and 255) shl 8) or (response[1].toInt() and 255)
            require(responseId == id) { "DNS transaction ID mismatch" }
            val flags = ((response[2].toInt() and 255) shl 8) or (response[3].toInt() and 255)
            val answers = ((response[6].toInt() and 255) shl 8) or (response[7].toInt() and 255)
            require(flags and 0x8000 != 0) { "DNS reply bit is not set" }
            require(flags and 0x7800 == 0) { "Unexpected DNS opcode" }
            val rcode = flags and 15
            val truncated = flags and 0x0200 != 0
            val summary = "rcode=$rcode answers=$answers truncated=$truncated bytes=${response.size}"
            return DnsReply(summary, rcode == 0 && answers > 0 && !truncated)
        }
        fun probe(block: () -> ByteArray): DnsReply = runCatching { describe(block()) }
            .getOrElse { DnsReply("failed=${errorDetail(it)}", false) }
        val udp = probe {
            DatagramSocket(null).use { socket ->
                vpn.bindSocket(socket)
                socket.soTimeout = 5000
                socket.send(DatagramPacket(request, request.size, address, 53))
                val packet = DatagramPacket(ByteArray(4096), 4096)
                socket.receive(packet)
                packet.data.copyOf(packet.length)
            }
        }
        val tcp = probe {
            Socket().use { socket ->
                vpn.bindSocket(socket)
                socket.soTimeout = 5000
                socket.connect(InetSocketAddress(address, 53), 5000)
                DataOutputStream(socket.getOutputStream()).apply { writeShort(request.size); write(request); flush() }
                val input = DataInputStream(socket.getInputStream())
                val response = ByteArray(input.readUnsignedShort())
                input.readFully(response)
                response
            }
        }
        return udp to tcp
    }

    private fun outboundTrafficBytes(context: Context): Long {
        val process = ProcessBuilder(
            File(context.applicationInfo.nativeLibraryDir, "libxray.so").absolutePath,
            "api", "statsquery", "--server=127.0.0.1:10809", "--pattern", "outbound>>>byedpi>>>traffic>>>",
        ).redirectErrorStream(true).start()
        val output = process.inputStream.bufferedReader().use { it.readText() }
        check(process.waitFor(3, TimeUnit.SECONDS)) { "Xray statistics query timed out" }
        check(process.exitValue() == 0) { "Xray statistics query failed" }
        val stats = JSONObject(output).optJSONArray("stat") ?: return 0
        var bytes = 0L
        for (index in 0 until stats.length()) {
            val stat = stats.getJSONObject(index)
            if (stat.optString("name").startsWith("outbound>>>byedpi>>>traffic>>>")) {
                bytes += stat.optLong("value", 0L)
            }
        }
        return bytes
    }

    private fun stopTemporarySession(
        context: android.content.Context,
        instrumentation: android.app.Instrumentation,
        sessionStarted: Boolean,
    ) {
        val profileFile = File(context.noBackupFilesDir, "flutter_vless_authorized_v1.bin")
        if (!sessionStarted) {
            check(!hasActiveVpn(context) && !isOculveServiceRunning(context) && !profileFile.exists()) {
                "No fresh SESSION_START proves ownership; refusing to stop or remove unrecognized VPN state"
            }
            return
        }
        val stopIntent = Intent(context, XrayVPNService::class.java)
            .putExtra("COMMAND", AppConfigs.V2RAY_SERVICE_COMMANDS.STOP_SERVICE)
        context.startService(stopIntent)
        val cleanupDeadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(25)
        var stopped = false
        var events = ""
        while (System.nanoTime() < cleanupDeadline) {
            events = XrayCoreManager.getProviderDebugSnapshot(context)
            val lines = eventLines(events)
            val startIndex = lines.indexOfFirst { it == "SESSION_START" }
            val sessionStopped = startIndex >= 0 && lines.drop(startIndex + 1).any { it == "SESSION_STOP" }
            stopped = !hasActiveVpn(context) && !isOculveServiceRunning(context) && !profileFile.exists() && sessionStopped
            if (stopped) break
            Thread.sleep(250)
        }
        if (!stopped) {
            report(instrumentation, "service_stop_not_confirmed events=${events.replace('\n', ',')}")
        }
        assertFalse("Temporary VPN interface remains active after cleanup", hasActiveVpn(context))
        assertFalse("Temporary test profile was not removed", profileFile.exists())
        assertFalse("Oculve VPN service is still running after cleanup", isOculveServiceRunning(context))
        assertTrue("Oculve did not confirm cleanup; events=$events", stopped)
    }

    private fun hasActiveVpn(context: android.content.Context): Boolean {
        val manager = context.getSystemService(ConnectivityManager::class.java)
        return manager.allNetworks.any {
            manager.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        }
    }

    @Suppress("DEPRECATION")
    private fun isOculveServiceRunning(context: Context): Boolean =
        context.getSystemService(ActivityManager::class.java).getRunningServices(Int.MAX_VALUE)
            .any { it.service.className == XrayVPNService::class.java.name }

    private fun eventLines(snapshot: String) = snapshot.lineSequence().filter(String::isNotBlank).toList()

    private fun errorDetail(error: Throwable): String {
        val rootCause = generateSequence(error) { it.cause }.last()
        return "${rootCause.javaClass.simpleName}: ${rootCause.message.orEmpty()}".take(180)
    }

    private fun isSameSiteOrSubdomain(requested: String, finalHost: String): Boolean {
        val root = requested.lowercase().removePrefix("www.")
        val final = finalHost.lowercase().removePrefix("www.")
        return final == root || final.endsWith(".$root")
    }

    private fun report(instrumentation: android.app.Instrumentation, message: String) {
        instrumentation.sendStatus(2, Bundle().apply { putString("live_test", message) })
    }
}
