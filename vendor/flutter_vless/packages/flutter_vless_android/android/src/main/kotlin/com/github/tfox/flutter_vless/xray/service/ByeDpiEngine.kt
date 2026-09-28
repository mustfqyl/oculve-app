package com.github.tfox.flutter_vless.xray.service

/** The engine runs inside the tunnel process so its sockets can use the VPN protect broker. */
internal class ByeDpiEngine {
    companion object {
        init { System.loadLibrary("byedpi_engine") }
    }

    external fun start(profile: Int, protectPath: String): Int
    external fun stop(): Boolean
    external fun isRunning(): Boolean
}
