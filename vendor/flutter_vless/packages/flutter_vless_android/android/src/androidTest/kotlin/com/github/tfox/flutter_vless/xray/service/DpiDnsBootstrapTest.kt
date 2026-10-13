package com.github.tfox.flutter_vless.xray.service

import android.net.VpnService
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.github.tfox.flutter_vless.xray.core.AndroidTunnelDnsPolicy
import com.github.tfox.flutter_vless.xray.core.AuthenticatedSocksClient
import com.github.tfox.flutter_vless.xray.core.LocalProxyCredentials
import com.github.tfox.flutter_vless.xray.core.XrayCoreManager
import com.github.tfox.flutter_vless.xray.dto.XrayConfig
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.security.KeyFactory
import java.security.KeyStore
import java.security.cert.CertificateFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLServerSocket
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManagerFactory

/** Real Xray + JNI ByeDPI + verified local HTTPS DNS. No Internet or system CA changes. */
@RunWith(AndroidJUnit4::class)
class DpiDnsBootstrapTest {
    @Test fun bootstrapBreaksDohRecursionAndByeDpiTransfersVerifiedTlsBytes() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val assets = instrumentation.context.assets
        val certBytes = assets.open("dpi-local-doh-cert.pem").use { it.readBytes() }
        val certificate = CertificateFactory.getInstance("X.509").generateCertificate(certBytes.inputStream())
        val key = KeyFactory.getInstance("RSA").generatePrivate(PKCS8EncodedKeySpec(
            assets.open("dpi-local-doh-key.pk8").use { it.readBytes() }))
        val store = KeyStore.getInstance(KeyStore.getDefaultType()).apply {
            load(null); setKeyEntry("fixture", key, "test-only".toCharArray(), arrayOf(certificate))
            setCertificateEntry("test-root", certificate)
        }
        val keys = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm()).apply { init(store, "test-only".toCharArray()) }
        val trust = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm()).apply { init(store) }
        val tls = SSLContext.getInstance("TLS").apply { init(keys.keyManagers, trust.trustManagers, null) }
        val server = tls.serverSocketFactory.createServerSocket(0, 32, InetAddress.getByName("127.0.0.1")) as SSLServerSocket
        server.sslParameters = server.sslParameters.apply { applicationProtocols = arrayOf("h2", "http/1.1") }
        val executor = Executors.newCachedThreadPool()
        val dnsQueries = AtomicInteger()
        val acceptedConnections = AtomicInteger()
        val fixtureErrors = java.util.concurrent.ConcurrentLinkedQueue<String>()
        executor.submit {
            try {
                while (!server.isClosed) {
                    val connection = server.accept()
                    acceptedConnections.incrementAndGet()
                    executor.submit {
                        runCatching { connection.use { socket ->
                            socket.soTimeout = 3000
                            val sslSocket = socket as SSLSocket
                            sslSocket.sslParameters = sslSocket.sslParameters.apply { applicationProtocols = arrayOf("h2", "http/1.1") }
                            sslSocket.startHandshake()
                            val input = java.io.PushbackInputStream(socket.getInputStream(), 24)
                            fun dnsAnswer(query: ByteArray): ByteArray {
                                var end = 12
                                while (query[end].toInt() != 0) end += (query[end].toInt() and 255) + 1
                                end += 5
                                return query.copyOfRange(0, 2) + byteArrayOf(0x81.toByte(), 0x80.toByte(), 0, 1, 0, 1, 0, 0, 0, 0) +
                                    query.copyOfRange(12, end) + byteArrayOf(0xc0.toByte(), 0x0c, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 127, 0, 0, 1)
                            }
                            // Xray uses an HTTP/2-only DoH transport. The owned
                            // fixture only needs SETTINGS, DATA and a static :status header.
                            val prefix = ByteArray(24)
                            java.io.DataInputStream(input).readFully(prefix)
                            if (String(prefix) == "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n") {
                                val data = java.io.DataInputStream(input)
                                val output = socket.getOutputStream()
                                fun frame(type: Int, flags: Int, stream: Int, payload: ByteArray = byteArrayOf()) {
                                    output.write(byteArrayOf((payload.size shr 16).toByte(), (payload.size shr 8).toByte(), payload.size.toByte(),
                                        type.toByte(), flags.toByte(), (stream shr 24).toByte(), (stream shr 16).toByte(), (stream shr 8).toByte(), stream.toByte()))
                                    output.write(payload); output.flush()
                                }
                                frame(4, 0, 0)
                                val queries = mutableMapOf<Int, java.io.ByteArrayOutputStream>()
                                while (true) {
                                    val length = (data.readUnsignedByte() shl 16) or (data.readUnsignedByte() shl 8) or data.readUnsignedByte()
                                    val type = data.readUnsignedByte(); val flags = data.readUnsignedByte(); val stream = data.readInt() and 0x7fffffff
                                    val bytes = ByteArray(length); data.readFully(bytes)
                                    if (type == 4 && flags and 1 == 0) frame(4, 1, 0)
                                    if (type == 0) {
                                        val query = queries.getOrPut(stream) { java.io.ByteArrayOutputStream() }
                                        query.write(bytes)
                                        if (flags and 1 != 0) {
                                            dnsQueries.incrementAndGet()
                                            frame(1, 4, stream, byteArrayOf(0x88.toByte())) // HPACK :status 200
                                            frame(0, 1, stream, dnsAnswer(query.toByteArray()))
                                        }
                                    }
                                }
                            }
                            input.unread(prefix)
                            fun line(): String {
                                val text = StringBuilder()
                                while (text.length < 8192) {
                                    val value = input.read(); if (value < 0 || value == 10) break
                                    if (value != 13) text.append(value.toChar())
                                }
                                return text.toString()
                            }
                            val request = line()
                            val headers = mutableMapOf<String, String>()
                            while (true) {
                                val value = line(); if (value.isEmpty()) break
                                headers[value.substringBefore(':').lowercase()] = value.substringAfter(':').trim()
                            }
                            if (request.startsWith("POST /dns-query ")) {
                                val query = ByteArray(headers.getValue("content-length").toInt())
                                java.io.DataInputStream(input).readFully(query)
                                val answer = dnsAnswer(query)
                                dnsQueries.incrementAndGet()
                                socket.getOutputStream().write("HTTP/1.1 200 OK\r\nContent-Type: application/dns-message\r\nContent-Length: ${answer.size}\r\nConnection: close\r\n\r\n".toByteArray() + answer)
                            } else if (request.startsWith("GET /owned-proof ")) {
                                socket.getOutputStream().write("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n".toByteArray())
                            } else {
                                error("Unexpected owned request: $request / ALPN=${sslSocket.applicationProtocol}")
                            }
                        } }.onFailure { fixtureErrors.add(it.javaClass.simpleName + ": " + it.message) }
                    }
                }
            } catch (e: Exception) { fixtureErrors.add("accept: " + e.javaClass.simpleName + ": " + e.message) }
        }
        val certificateFile = File(context.noBackupFilesDir, "dpi-test-ca.pem").apply { writeBytes(certBytes) }
        val protected = AtomicInteger()
        // All destinations are this test's loopback listener. The fake broker
        // acknowledges FD transfers without installing any Android VPN route.
        val protector = XraySocketProtector(VpnService(), protectFd = { protected.incrementAndGet(); true })
        protector.allowPhysicalDnsForEndpointNames(emptySet())
        val engine = ByeDpiEngine()
        val configFile = File(context.noBackupFilesDir, "dpi-bootstrap-fixture.json")
        try {
            val dpiPort = engine.start(4, "@${protector.socketName}")
            assertTrue("Packaged ByeDPI engine did not start", dpiPort in 1..65535)
            val raw = JSONObject().put("inbounds", JSONArray()).put("outbounds", JSONArray()
                .put(JSONObject().put("tag", "byedpi").put("protocol", "socks").put("targetStrategy", "UseIP")
                    .put("settings", JSONObject().put("servers", JSONArray().put(JSONObject().put("address", "127.0.0.1").put("port", dpiPort))))))
                .put("dns", JSONObject().put("servers", JSONArray().put("https://doh.fixture.test:${server.localPort}/dns-query")))
            val prepared = AndroidTunnelDnsPolicy.prepare(raw.toString(), "proxy", "byedpi") { name ->
                assertEquals("Only the DNS infrastructure hostname may use physical bootstrap", "doh.fixture.test", name)
                listOf("127.0.0.1")
            }
            val proxyPort = ServerSocket(0).use { it.localPort }
            val secret = LocalProxyCredentials.generate()
            val runtime = XrayCoreManager.buildRuntimeConfigJson(XrayConfig(V2RAY_FULL_JSON_CONFIG = prepared.configJson,
                LOCAL_SOCKS5_PORT = proxyPort, LOCAL_API_PORT = proxyPort + 1), context.noBackupFilesDir, secret)

            var attemptFailure = ""
            val nativeOutput = StringBuffer()
            fun attempt(withBootstrap: Boolean): Boolean {
                val json = JSONObject(runtime.toString())
                // Synthetic test data only; production logging stays content-free.
                json.put("log", JSONObject().put("loglevel", "debug").put("access", "none").put("error", ""))
                if (!withBootstrap) {
                    json.getJSONObject("dns").getJSONObject("hosts").remove("doh.fixture.test")
                    val rules = json.getJSONObject("routing").getJSONArray("rules")
                    for (i in 0 until rules.length()) if (rules.getJSONObject(i).optJSONArray("inboundTag")?.toString()?.contains(AndroidTunnelDnsPolicy.UPSTREAM_TAG) == true) rules.getJSONObject(i).put("outboundTag", "byedpi")
                    val kept = JSONArray()
                    val outputs = json.getJSONArray("outbounds")
                    for (i in 0 until outputs.length()) if (outputs.getJSONObject(i).optString("tag") != AndroidTunnelDnsPolicy.DOH_BOOTSTRAP_TAG) kept.put(outputs.getJSONObject(i))
                    json.put("outbounds", kept)
                }
                configFile.writeText(json.toString())
                val builder = ProcessBuilder(File(context.applicationInfo.nativeLibraryDir, "libxray.so").path,
                    "run", "-config", configFile.path).redirectErrorStream(true)
                builder.environment()["SSL_CERT_FILE"] = certificateFile.path
                builder.environment()["FLUTTER_VLESS_PROTECT_SOCKET"] = protector.socketName
                val process = builder.start()
                executor.submit { process.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { line -> if (nativeOutput.length < 16384) nativeOutput.append(line.replace(secret.password, "[redacted]").replace(secret.username, "[redacted]")).append('\n') }
                } }
                try {
                    Thread.sleep(400)
                    return runCatching {
                        AuthenticatedSocksClient.connect(proxyPort, secret, "site.fixture.test", server.localPort, 2000).use { rawSocket ->
                            (tls.socketFactory.createSocket(rawSocket, "site.fixture.test", server.localPort, true) as SSLSocket).use { socket ->
                                socket.soTimeout = 2500
                                socket.sslParameters = socket.sslParameters.apply { endpointIdentificationAlgorithm = "HTTPS" }
                                socket.startHandshake()
                                socket.getOutputStream().write("GET /owned-proof HTTP/1.1\r\nHost: site.fixture.test\r\nConnection: close\r\n\r\n".toByteArray())
                                check(socket.getInputStream().bufferedReader().readLine().contains(" 204 "))
                            }
                        }
                        // The virtual DNS endpoint used by Android must also
                        // return an A answer through the same protected DoH path.
                        val query = byteArrayOf(0x12, 0x34, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0,
                            4, 115, 105, 116, 101, 7, 102, 105, 120, 116, 117, 114, 101, 4, 116, 101, 115, 116, 0, 0, 1, 0, 1)
                        AuthenticatedSocksClient.connect(proxyPort, secret, AndroidTunnelDnsPolicy.VIRTUAL_SERVER, 53, 2000).use { dnsSocket ->
                            java.io.DataOutputStream(dnsSocket.getOutputStream()).apply { writeShort(query.size); write(query) }
                            val input = java.io.DataInputStream(dnsSocket.getInputStream())
                            val answer = ByteArray(input.readUnsignedShort()); input.readFully(answer)
                            check(answer.size >= 12 && answer[3].toInt() and 15 == 0 && answer[7].toInt() > 0)
                        }
                        true
                    }.onFailure { attemptFailure = it.javaClass.simpleName + ": " + it.message + "; alive=" + process.isAlive + "; DNS=" + dnsQueries.get() + "; protected=" + protected.get() }.getOrDefault(false)
                } finally { process.destroy(); process.waitFor(3, TimeUnit.SECONDS) }
            }
            assertFalse("Old recursive DoH configuration unexpectedly completed", attempt(false))
            val passed = attempt(true)
            if (!passed) Thread.sleep(500)
            assertTrue("Pinned DoH through actual ByeDPI did not resolve and transfer verified TLS bytes: $attemptFailure / accepted=${acceptedConnections.get()} / fixture=$fixtureErrors / native=$nativeOutput", passed)
            assertTrue("DoH request never reached the owned HTTPS resolver", dnsQueries.get() > 0)
            assertTrue("ByeDPI/Xray never sent descriptors to the protect broker", protected.get() >= 2)
        } finally {
            engine.stop(); protector.close(); server.close(); executor.shutdownNow()
            configFile.delete(); certificateFile.delete()
        }
    }
}
