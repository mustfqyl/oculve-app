package com.github.tfox.flutter_vless.xray.service

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import java.security.MessageDigest

/** Keeps only the last known working internal preset for the current underlay signature. */
internal class DpiProfileCache(private val context: Context) {
    private val preferences = context.getSharedPreferences("dpi_strategy_cache", Context.MODE_PRIVATE)

    fun candidates(): List<Int> {
        val cached = preferences.getInt(key(), -1).takeIf { it in 0..3 }
        return listOfNotNull(cached) + (0..3).filter { it != cached }
    }

    fun save(profile: Int) {
        if (profile in 0..3) preferences.edit().putInt(key(), profile).apply()
    }

    private fun key(): String {
        val manager = context.getSystemService(ConnectivityManager::class.java)
        val physical = manager.allNetworks.asSequence().mapNotNull { network ->
            val caps = manager.getNetworkCapabilities(network) ?: return@mapNotNull null
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ||
                !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return@mapNotNull null
            val link = manager.getLinkProperties(network)
            val type = when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            }
            "$type|${link?.interfaceName.orEmpty()}|" +
                (link?.dnsServers?.map { it.hostAddress.orEmpty() }?.sorted()?.joinToString(",") ?: "") + "|" +
                (link?.routes?.map { it.destination.toString() + ":" + it.gateway?.hostAddress.orEmpty() }
                    ?.sorted()?.joinToString(",") ?: "")
        }.firstOrNull().orEmpty()
        val digest = MessageDigest.getInstance("SHA-256").digest(physical.toByteArray())
            .take(12).joinToString("") { "%02x".format(it.toInt() and 0xff) }
        return "profile.$digest"
    }
}
