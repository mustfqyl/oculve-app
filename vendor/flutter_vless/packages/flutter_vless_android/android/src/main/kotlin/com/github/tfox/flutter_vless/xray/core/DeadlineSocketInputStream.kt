package com.github.tfox.flutter_vless.xray.core

import java.io.FilterInputStream
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.concurrent.TimeUnit

/** A byte-dripping peer cannot reset a probe's total read budget. */
internal class DeadlineSocketInputStream(private val socket: Socket, timeoutMs: Int) :
    FilterInputStream(socket.getInputStream()) {
    private val deadline: Long
    init {
        require(timeoutMs > 0)
        deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMs.toLong())
    }
    private fun updateTimeout() {
        val remaining = deadline - System.nanoTime()
        if (remaining <= 0) throw SocketTimeoutException("Probe response timed out")
        socket.soTimeout = ((remaining + 999999) / 1000000).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
    }
    override fun read(): Int {
        updateTimeout()
        return super.read()
    }
    override fun read(bytes: ByteArray, offset: Int, length: Int): Int {
        updateTimeout()
        return super.read(bytes, offset, length)
    }
}
