package com.github.tfox.flutter_vless.xray.core

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.FutureTask
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** Drains a short-lived command without blocking its caller on an open pipe. */
internal object BoundedProcessOutput {
    fun read(process: Process, timeoutMillis: Long = 2000, maxBytes: Int = 64 * 1024): String {
        require(timeoutMillis > 0 && maxBytes > 0)
        val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMillis)
        val output = FutureTask {
            process.inputStream.use { stream ->
                val bytes = ByteArrayOutputStream()
                val buffer = ByteArray(4096)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    if (bytes.size() + count > maxBytes) throw IOException("Command output exceeds limit")
                    bytes.write(buffer, 0, count)
                }
                bytes.toString("UTF-8")
            }
        }
        val reader = Thread(output, "oculve-command-output").apply { isDaemon = true }
        reader.start()
        try {
            val text = output.get(timeoutMillis, TimeUnit.MILLISECONDS)
            val remaining = deadline - System.nanoTime()
            if (remaining <= 0 || !ChildProcessCompat.waitFor(process, remaining, TimeUnit.NANOSECONDS)) {
                throw TimeoutException("Command did not exit before deadline")
            }
            if (process.exitValue() != 0) throw IOException("Command failed")
            return text
        } finally {
            // Destroy before closing the pipe: a concurrent blocked read can
            // hold the pipe's lock, making close itself wait for process exit.
            if (ChildProcessCompat.isAlive(process)) {
                process.destroy()
                if (!ChildProcessCompat.waitFor(process, 100, TimeUnit.MILLISECONDS)) ChildProcessCompat.destroyForcibly(process)
            }
            output.cancel(true)
            runCatching { process.outputStream.close() }
            runCatching { process.errorStream.close() }
        }
    }
}
