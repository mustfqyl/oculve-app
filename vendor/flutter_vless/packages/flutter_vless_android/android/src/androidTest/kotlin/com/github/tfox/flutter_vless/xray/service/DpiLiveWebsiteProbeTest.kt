package com.github.tfox.flutter_vless.xray.service

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.Socket
import java.nio.charset.StandardCharsets
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

/** One-off real-network check of the JNI ByeDPI SOCKS engine on the connected device. */
@RunWith(AndroidJUnit4::class)
class DpiLiveWebsiteProbeTest {
    @Test fun automaticDpiEngineLoadsRequestedSites() {
        val engine = ByeDpiEngine()
        val profile = InstrumentationRegistry.getArguments().getString("profile")?.toIntOrNull() ?: 4
        val port = engine.start(profile, "")
        assertTrue("Android ByeDPI engine did not start for profile $profile", port in 1..65535)
        val failures = mutableListOf<String>()
        val args = InstrumentationRegistry.getArguments()
        val hosts = args.getString("host")?.let(::listOf) ?: listOf("roblox.com", "discord.com", "wattpad.com")

        try {
            val control = InetAddress.getAllByName("example.com").firstOrNull { it is Inet4Address } as? Inet4Address
            val controlDirect = control?.let(::directTcp) ?: "failed=no-ipv4"
            val controlProxy = runCatching { getStatusThroughByeDpi("example.com", control ?: error("No IPv4 destination"), port).toString() }
                .getOrElse { "failed=${it.javaClass.simpleName}" }
            println("DPI_LIVE_CONTROL host=example.com direct=$controlDirect byedpi=$controlProxy")
            for (host in hosts) {
                val destinations = InetAddress.getAllByName(host).filterIsInstance<Inet4Address>()
                if (destinations.isEmpty()) {
                    failures += "$host resolution failed"
                    continue
                }
                val directResults = destinations.map { it to directTcp(it) }
                println("DPI_LIVE_DIRECT host=$host results=${directResults.map { it.second }.joinToString()}")
                val destination = directResults.firstOrNull { it.second == "connected" }?.first ?: directResults.first().first
                try {
                    val status = getStatusThroughByeDpi(host, destination, port)
                    println("DPI_LIVE_WEBSITE profile=$profile host=$host http=$status")
                    if (status !in 200..399) failures += "$host returned HTTP $status"
                } catch (error: Exception) {
                    val rootCause = generateSequence(error as Throwable?) { it.cause }.lastOrNull()
                    val detail = "${rootCause?.javaClass?.simpleName}: ${rootCause?.message.orEmpty()}".take(180)
                    println("DPI_LIVE_WEBSITE profile=$profile host=$host failed=${error.javaClass.simpleName} cause=$detail")
                    failures += "$host failed: ${error.javaClass.simpleName} ($detail)"
                }
            }
        } finally {
            assertTrue("Android ByeDPI engine did not stop", engine.stop())
        }

        assertTrue("Sites unavailable through Android ByeDPI: ${failures.joinToString()}", failures.isEmpty())
    }

    private fun directTcp(address: Inet4Address): String = runCatching {
        Socket().use { it.connect(InetSocketAddress(address, 443), 3000) }
        "connected"
    }.getOrElse { "failed=${it.javaClass.simpleName}" }

    private fun getStatusThroughByeDpi(host: String, destination: Inet4Address, proxyPort: Int): Int {
        // Match the app: Xray resolves the hostname, then sends an IP SOCKS request to ByeDPI.
        val socks = Socket(Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", proxyPort)))
        socks.connect(InetSocketAddress(destination, 443), 15_000)
        socks.soTimeout = 45_000
        val factory = SSLSocketFactory.getDefault() as SSLSocketFactory
        val tls = factory.createSocket(socks, host, 443, true) as SSLSocket
        return tls.use { socket ->
            socket.sslParameters = socket.sslParameters.apply { endpointIdentificationAlgorithm = "HTTPS" }
            socket.soTimeout = 45_000
            socket.startHandshake()
            socket.getOutputStream().write(
                "GET / HTTP/1.1\r\nHost: $host\r\nUser-Agent: Oculve-DPI-Live-Probe\r\nConnection: close\r\n\r\n"
                    .toByteArray(StandardCharsets.US_ASCII),
            )
            val statusLine = BufferedReader(InputStreamReader(socket.inputStream, StandardCharsets.ISO_8859_1)).readLine()
                ?: error("Empty HTTPS response")
            statusLine.split(' ').getOrNull(1)?.toIntOrNull()
                ?: error("Invalid HTTPS status line")
        }
    }
}
