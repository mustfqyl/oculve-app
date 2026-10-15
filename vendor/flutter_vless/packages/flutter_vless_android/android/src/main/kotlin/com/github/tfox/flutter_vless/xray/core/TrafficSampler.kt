package com.github.tfox.flutter_vless.xray.core

/** Counter deltas are rates only when divided by their actual sampling interval. */
internal class TrafficSampler {
    private var uplink = 0L
    private var downlink = 0L
    private var sampledAt = 0L
    fun reset(now: Long = System.nanoTime()) {
        uplink = 0; downlink = 0; sampledAt = now
    }
    fun sample(up: Long, down: Long, now: Long = System.nanoTime()): LongArray {
        val seconds = (now - sampledAt).toDouble() / 1_000_000_000.0
        fun rate(current: Long, previous: Long): Long =
            if (seconds <= 0) 0 else ((current - previous).coerceAtLeast(0).toDouble() / seconds).toLong()
        val result = longArrayOf(rate(up, uplink), rate(down, downlink), up, down)
        uplink = up; downlink = down; sampledAt = now
        return result
    }
}
