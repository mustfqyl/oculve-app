package com.github.tfox.flutter_vless.xray.core

import android.os.Build
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLPeerUnverifiedException
import java.io.DataInputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URI
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

/** RFC 1929 authentication belongs to each socket, never to a process-wide Authenticator. */
internal object AuthenticatedSocksClient {
    private val connectivityUrls = listOf(
        "https://www.gstatic.com/generate_204",
        "https://cp.cloudflare.com/generate_204"
    )

    internal fun startVerifiedTls(socket: SSLSocket, host: String,
                                  legacyVerifier: HostnameVerifier? = null) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                socket.sslParameters = socket.sslParameters.apply { endpointIdentificationAlgorithm = "HTTPS" }
            }
            socket.startHandshake()
            // Android 6 lacks SSLParameters' HTTPS endpoint identification.
            // Keep its platform verifier rather than skipping host validation.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N &&
                !(legacyVerifier ?: HttpsURLConnection.getDefaultHostnameVerifier()).verify(host, socket.session)) {
                throw SSLPeerUnverifiedException("TLS hostname verification failed")
            }
        } catch (error: Exception) {
            runCatching { socket.close() }
            throw error
        }
    }

    fun connect(port: Int, credentials: LocalProxyCredentials?, host: String, targetPort: Int,
                timeoutMs: Int = 5000): Socket {
        val socket = Socket()
        try {
            socket.connect(InetSocketAddress("127.0.0.1", port), timeoutMs)
            socket.soTimeout = timeoutMs
            val input = DataInputStream(DeadlineSocketInputStream(socket, timeoutMs))
            val output = socket.getOutputStream()
            val method = if (credentials == null) 0 else 2
            output.write(byteArrayOf(5, 1, method.toByte()))
            if (input.readUnsignedByte() != 5 || input.readUnsignedByte() != method) throw IOException("SOCKS authentication required")
            if (credentials != null) {
                val user = credentials.username.toByteArray(Charsets.UTF_8)
                val pass = credentials.password.toByteArray(Charsets.UTF_8)
                output.write(byteArrayOf(1, user.size.toByte()) + user + byteArrayOf(pass.size.toByte()) + pass)
                if (input.readUnsignedByte() != 1 || input.readUnsignedByte() != 0) throw IOException("SOCKS authentication rejected")
            }
            val name = host.toByteArray(Charsets.US_ASCII)
            require(name.size in 1..255 && targetPort in 1..65535) { "Invalid probe target" }
            output.write(byteArrayOf(5, 1, 0, 3, name.size.toByte()) + name + byteArrayOf((targetPort shr 8).toByte(), targetPort.toByte()))
            if (input.readUnsignedByte() != 5 || input.readUnsignedByte() != 0) throw IOException("SOCKS connect rejected")
            if (input.readUnsignedByte() != 0) throw IOException("Invalid SOCKS reply")
            val addressLength = when (input.readUnsignedByte()) { 1 -> 4; 3 -> input.readUnsignedByte(); 4 -> 16; else -> throw IOException("Invalid SOCKS address") }
            input.readFully(ByteArray(addressLength + 2))
            socket.soTimeout = timeoutMs
            return socket
        } catch (error: Exception) { socket.close(); throw error }
    }

    /** Resolve a replacement endpoint through the old proxy and verified HTTPS.
     * Never ask a physical Network's resolver while a protected session exists. */
    fun resolveIpv4(port: Int, credentials: LocalProxyCredentials, hostname: String): List<String> {
        require(hostname.length in 1..253 && !hostname.contains('\r') && !hostname.contains('\n'))
        connect(port, credentials, "1.1.1.1", 443).use { raw ->
            val tls = (SSLSocketFactory.getDefault() as SSLSocketFactory)
                .createSocket(raw, "cloudflare-dns.com", 443, true) as SSLSocket
            tls.use { socket ->
                socket.soTimeout = 5000
                startVerifiedTls(socket, "cloudflare-dns.com")
                val query = java.net.URLEncoder.encode(hostname, "UTF-8")
                socket.getOutputStream().write(("GET /dns-query?name=$query&type=A HTTP/1.1\r\n" +
                    "Host: cloudflare-dns.com\r\nAccept: application/dns-json\r\nConnection: close\r\n\r\n").toByteArray(Charsets.US_ASCII))
                val input = DataInputStream(DeadlineSocketInputStream(socket, 5000))
                var headerBytes = 0
                fun line(): String {
                    val text = StringBuilder()
                    while (text.length < 4096 && headerBytes++ < 16384) {
                        val value = input.readUnsignedByte()
                        if (value == 10) return text.toString().trimEnd('\r')
                        text.append(value.toChar())
                    }
                    throw IOException("DNS response header too large")
                }
                require(line().matches(Regex("HTTP/1\\.[01] 200(?: .*)?")))
                val headers = mutableMapOf<String, String>()
                while (true) {
                    val line = line(); if (line.isEmpty()) break
                    val split = line.indexOf(':'); require(split > 0)
                    headers[line.substring(0, split).lowercase()] = line.substring(split + 1).trim()
                }
                require(headers["content-type"]?.substringBefore(';')?.trim() == "application/dns-json")
                val bytes = java.io.ByteArrayOutputStream()
                if (headers["transfer-encoding"]?.lowercase() == "chunked") {
                    while (true) {
                        val size = line().substringBefore(';').toInt(16)
                        require(size >= 0 && bytes.size() + size <= 65536)
                        if (size == 0) break
                        val chunk = ByteArray(size); input.readFully(chunk); bytes.write(chunk)
                        require(input.readUnsignedByte() == 13 && input.readUnsignedByte() == 10)
                    }
                } else {
                    val size = headers["content-length"]?.toInt() ?: throw IOException("Bounded DNS response required")
                    require(size in 1..65536)
                    val body = ByteArray(size); input.readFully(body); bytes.write(body)
                }
                return parseDnsJson(bytes.toString("UTF-8"), hostname)
            }
        }
    }

    fun parseDnsJson(body: String, hostname: String): List<String> {
        require(body.length <= 65536)
        val json = org.json.JSONObject(body)
        require(json.getInt("Status") == 0 && !json.optBoolean("TC"))
        val questions = json.getJSONArray("Question")
        fun canonical(value: String) = value.trimEnd('.').lowercase()
        require(questions.length() == 1 && questions.getJSONObject(0).getInt("type") == 1 &&
            canonical(questions.getJSONObject(0).getString("name")) == canonical(hostname))
        val answers = json.optJSONArray("Answer") ?: return emptyList()
        require(answers.length() <= 256)
        var owner = canonical(hostname)
        val seen = mutableSetOf<String>()
        repeat(16) {
            require(seen.add(owner))
            val matching = (0 until answers.length()).map { answers.getJSONObject(it) }
                .filter { canonical(it.getString("name")) == owner }
            val addresses = matching.filter { it.getInt("type") == 1 }.map { it.getString("data") }
                .filter { address -> val parts = address.split('.'); parts.size == 4 && parts.all { it.toIntOrNull() in 0..255 && it.matches(Regex("[0-9]{1,3}")) } }
            if (addresses.isNotEmpty()) return addresses.distinct()
            val alias = matching.firstOrNull { it.getInt("type") == 5 } ?: return emptyList()
            owner = canonical(alias.getString("data"))
        }
        throw IOException("Invalid DNS alias chain")
    }

    /** An HTTP response proves authenticated, bidirectional application bytes, not only CONNECT. */
    fun measure(port: Int, credentials: LocalProxyCredentials?, url: String): Long {
        val started = System.nanoTime()
        request(port, credentials, url, "HEAD", 5000)
        return (System.nanoTime() - started) / 1_000_000
    }

    private fun request(port: Int, credentials: LocalProxyCredentials?, url: String,
                        method: String, timeoutMs: Int): Int {
        val uri = URI(url)
        require(uri.scheme in setOf("http", "https") && uri.host != null && uri.rawUserInfo == null) { "Invalid probe URL" }
        require(!url.contains('\r') && !url.contains('\n')) { "Invalid probe URL" }
        val secure = uri.scheme == "https"
        val targetPort = if (uri.port >= 0) uri.port else if (secure) 443 else 80
        connect(port, credentials, uri.host, targetPort, timeoutMs).use { raw ->
            val transport = if (secure) {
                (SSLSocketFactory.getDefault() as SSLSocketFactory).createSocket(raw, uri.host, targetPort, true).let {
                    it as SSLSocket
                    it.soTimeout = timeoutMs
                    startVerifiedTls(it, uri.host)
                    it
                }
            } else raw
            transport.use { socket ->
                val path = (uri.rawPath.takeUnless { it.isNullOrEmpty() } ?: "/") + (uri.rawQuery?.let { "?$it" } ?: "")
                val host = if (targetPort == if (secure) 443 else 80) uri.host else "${uri.host}:$targetPort"
                socket.getOutputStream().write("$method $path HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
                val input = DeadlineSocketInputStream(socket, timeoutMs)
                val line = StringBuilder()
                while (line.length < 1024) { val value = input.read(); if (value < 0) throw IOException("Empty probe response"); if (value == 10) break; line.append(value.toChar()) }
                val match = Regex("HTTP/1\\.[01] ([1-5][0-9]{2})(?: .*)?")
                    .matchEntire(line.toString().trimEnd('\r'))
                    ?: throw IOException("Invalid probe response")
                return match.groupValues[1].toInt()
            }
        }
    }

    /** A verified TLS response through Xray and the active outbound proves application connectivity. */
    fun checkConnectivity(port: Int, credentials: LocalProxyCredentials?): Boolean =
        connectivityUrls.any { url ->
            runCatching { request(port, credentials, url, "GET", 2500) == 204 }.getOrDefault(false)
        }
}
