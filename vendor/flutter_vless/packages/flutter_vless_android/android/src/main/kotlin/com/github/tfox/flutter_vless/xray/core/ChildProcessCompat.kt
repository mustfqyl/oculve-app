package com.github.tfox.flutter_vless.xray.core

import android.os.Build
import java.util.concurrent.TimeUnit
import kotlin.math.min

/** Preserve process supervision on the plugin's pre-Android-8 devices. */
internal object ChildProcessCompat {
    fun isAlive(process: Process): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) return process.isAlive
        return try { process.exitValue(); false }
        catch (_: IllegalThreadStateException) { true }
    }

    fun waitFor(process: Process, timeout: Long, unit: TimeUnit): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) return process.waitFor(timeout, unit)
        val deadline = System.nanoTime() + unit.toNanos(timeout)
        while (isAlive(process)) {
            val remaining = deadline - System.nanoTime()
            if (remaining <= 0) return false
            TimeUnit.NANOSECONDS.sleep(min(remaining, TimeUnit.MILLISECONDS.toNanos(50)))
        }
        return true
    }

    fun destroyForcibly(process: Process) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) process.destroyForcibly()
        else process.destroy()
        // Callers recheck exit before forgetting the old process or restarting.
        // A worker that refuses shutdown must retain the existing traffic guard.
    }
}
