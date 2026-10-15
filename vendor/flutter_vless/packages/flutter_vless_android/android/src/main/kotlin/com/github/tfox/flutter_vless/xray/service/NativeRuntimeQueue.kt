package com.github.tfox.flutter_vless.xray.service

import java.util.concurrent.ScheduledThreadPoolExecutor

/** Xray and ByeDPI are process-wide; service recreation must share their queue. */
internal object NativeRuntimeQueue {
    private var current: ScheduledThreadPoolExecutor? = null
    private var users = 0
    internal class Lease internal constructor(val worker: ScheduledThreadPoolExecutor) {
        internal var released = false
        fun post(action: () -> Unit): Boolean = synchronized(NativeRuntimeQueue) {
            if (released) false else { worker.execute(action); true }
        }
    }
    @Synchronized fun acquire(): Lease {
        val worker = current ?: ScheduledThreadPoolExecutor(1).apply {
            setExecuteExistingDelayedTasksAfterShutdownPolicy(false)
            current = this
        }
        users++
        return Lease(worker)
    }
    @Synchronized fun release(lease: Lease) {
        if (lease.released) return
        lease.released = true
        users--
        // Enqueued after that service's teardown. A replacement acquired in the
        // meantime keeps this same worker until all services have released it.
        lease.worker.execute {
            synchronized(this) {
                if (users == 0 && current === lease.worker) {
                    current = null
                    lease.worker.shutdown()
                }
            }
        }
    }
}
