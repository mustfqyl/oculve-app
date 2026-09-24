package com.oculve.app

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.SystemClock
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val latencyExecutor = Executors.newFixedThreadPool(3)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.oculve/vpn_app_catalog",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listLaunchableApps" -> result.success(listLaunchableApps())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.oculve/server_latency",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "tcpConnectLatency" -> {
                    val host = call.argument<String>("host")?.trim()
                    val port = call.argument<Int>("port")
                    val timeoutMs = call.argument<Int>("timeoutMs") ?: 3000
                    if (host.isNullOrEmpty() || port == null || port !in 1..65535) {
                        result.error("invalid_target", "A valid TCP host and port are required.", null)
                    } else {
                        latencyExecutor.execute {
                            val sample = runCatching {
                                measureTcpConnect(host, port, timeoutMs.coerceIn(500, 5000))
                            }.getOrNull()
                            runOnUiThread {
                                result.success(
                                    sample?.let {
                                        mapOf(
                                            "latencyMs" to it.latencyMs,
                                            "resolvedAddress" to it.resolvedAddress,
                                        )
                                    },
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun measureTcpConnect(host: String, port: Int, timeoutMs: Int): TcpConnectSample? {
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = activePhysicalNetwork(connectivity)
        // Match Happ's documented TCP measurement and NekoBox's open-source
        // implementation: resolve the hostname on the physical network before
        // timing, use its first result, then time only one TCP handshake.
        // Racing several CDN answers can select a different edge and cause
        // the displayed value to disagree with those clients.
        val address = (network?.getAllByName(host) ?: InetAddress.getAllByName(host))
            .firstOrNull() ?: return null
        val socket = network?.socketFactory?.createSocket() ?: Socket()
        return try {
            socket.bind(InetSocketAddress(0))
            val startedAt = SystemClock.elapsedRealtime()
            socket.connect(InetSocketAddress(address, port), timeoutMs)
            TcpConnectSample(
                latencyMs = (SystemClock.elapsedRealtime() - startedAt).toInt().coerceAtLeast(1),
                resolvedAddress = address.hostAddress,
            )
        } finally {
            runCatching { socket.close() }
        }
    }

    private data class TcpConnectSample(
        val latencyMs: Int,
        val resolvedAddress: String,
    )

    private fun activePhysicalNetwork(connectivity: ConnectivityManager): Network? {
        val active = connectivity.activeNetwork
        val activeCapabilities = active?.let(connectivity::getNetworkCapabilities)
        if (active != null && activeCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) != true) {
            return active
        }

        return connectivity.allNetworks.firstOrNull { network ->
            val capabilities = connectivity.getNetworkCapabilities(network)
            capabilities != null &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
        } ?: connectivity.allNetworks.firstOrNull { network ->
            val capabilities = connectivity.getNetworkCapabilities(network)
            capabilities != null &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        }
    }

    private fun listLaunchableApps(): List<Map<String, Any>> {
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(launcher, 0)
            .asSequence()
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != packageName }
            .map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "label" to packageManager.getApplicationLabel(app).toString(),
                    "icon" to drawablePng(packageManager.getApplicationIcon(app)),
                )
            }
            .sortedBy { it["label"].toString().lowercase() }
            .toList()
    }

    private fun drawablePng(drawable: Drawable): ByteArray {
        val edge = 48
        val bitmap = Bitmap.createBitmap(edge, edge, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, edge, edge)
        drawable.draw(canvas)
        return ByteArrayOutputStream().use { output ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            bitmap.recycle()
            output.toByteArray()
        }
    }
}
