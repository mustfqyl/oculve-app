package com.github.tfox.flutter_vless.xray.service

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*
import com.github.tfox.flutter_vless.xray.core.XrayCoreManager
import com.github.tfox.flutter_vless.xray.dto.XrayConfig

class NativeRuntimeQueueTest {
    @Test fun repeatedLifecycleCyclesCloseWorkersAndCancelObsoleteDelayedTasks() {
        val initialThreads = Thread.getAllStackTraces().keys.count { it.isAlive }
        repeat(1000) {
            val lease = NativeRuntimeQueue.acquire()
            val obsolete = lease.worker.schedule({ fail("A released service's delayed work must not run") }, 60, TimeUnit.SECONDS)
            lease.worker.submit {}.get(1, TimeUnit.SECONDS)
            NativeRuntimeQueue.release(lease)
            NativeRuntimeQueue.release(lease)
            assertTrue(lease.worker.awaitTermination(1, TimeUnit.SECONDS))
            assertTrue(obsolete.isCancelled)
            assertFalse(lease.post { fail("Late callback") })
        }
        val finalThreads = Thread.getAllStackTraces().keys.count { it.isAlive }
        // Termination is checked every cycle; one final JVM thread can be exiting.
        assertTrue("Runtime worker threads accumulated", finalThreads <= initialThreads + 1)
        println("RUNTIME_QUEUE cycles=1000 initialThreads=$initialThreads finalThreads=$finalThreads")
    }

    @Test fun serviceDestroyFinishesItsChildBeforeReplacementCanInstallTheNewCore() {
        val old = NativeRuntimeQueue.acquire()
        val service = mock(XrayVPNService::class.java, CALLS_REAL_METHODS)
        fun set(name: String, value: Any) = XrayVPNService::class.java.getDeclaredField(name).apply {
            isAccessible = true; set(service, value)
        }
        set("runtimeLease", old)
        set("recovery", SessionRecoveryPolicy())
        set("requests", java.util.concurrent.atomic.AtomicLong())
        set("config", XrayConfig())
        val teardownEntered = CountDownLatch(1)
        val finishTeardown = CountDownLatch(1)
        val child = mock(Process::class.java)
        doAnswer { teardownEntered.countDown(); check(finishTeardown.await(3, TimeUnit.SECONDS)); null }.`when`(child).destroy()
        set("process", child)
        val coreField = XrayCoreManager::class.java.getDeclaredField("xrayProcess").apply { isAccessible = true }
        val original = coreField.get(XrayCoreManager)
        val newCore = mock(Process::class.java)
        service.onDestroy()
        assertTrue(teardownEntered.await(1, TimeUnit.SECONDS))
        assertTrue(old.released)
        val replacement = NativeRuntimeQueue.acquire()
        val installed = CountDownLatch(1)
        try {
            replacement.worker.execute { coreField.set(XrayCoreManager, newCore); installed.countDown() }
            assertFalse(installed.await(50, TimeUnit.MILLISECONDS))
            finishTeardown.countDown()
            assertTrue(installed.await(1, TimeUnit.SECONDS))
            verify(newCore, never()).destroy()
            assertSame(newCore, coreField.get(XrayCoreManager))
        } finally {
            finishTeardown.countDown()
            coreField.set(XrayCoreManager, original)
            NativeRuntimeQueue.release(replacement)
        }
        assertTrue(replacement.worker.awaitTermination(1, TimeUnit.SECONDS))
    }

    @Test fun replacementWaitsForOldTeardownAndTheLastReleaseClosesTheWorker() {
        val old = NativeRuntimeQueue.acquire()
        val teardownEntered = CountDownLatch(1)
        val finishTeardown = CountDownLatch(1)
        val startup = CountDownLatch(1)
        val order = java.util.Collections.synchronizedList(mutableListOf<String>())
        old.worker.execute {
            teardownEntered.countDown()
            check(finishTeardown.await(3, TimeUnit.SECONDS))
            order.add("old-stop")
        }
        assertTrue(teardownEntered.await(1, TimeUnit.SECONDS))
        NativeRuntimeQueue.release(old)
        val replacement = NativeRuntimeQueue.acquire()
        try {
            assertSame(old.worker, replacement.worker)
            replacement.worker.execute { order.add("new-start"); startup.countDown() }
            assertFalse(startup.await(50, TimeUnit.MILLISECONDS))
            assertFalse(old.post { fail("A released service callback must not run") })
            finishTeardown.countDown()
            assertTrue(startup.await(1, TimeUnit.SECONDS))
            assertEquals(listOf("old-stop", "new-start"), order)
            assertFalse(replacement.worker.isShutdown)
            NativeRuntimeQueue.release(old) // Duplicate lifecycle cleanup is harmless.
        } finally {
            finishTeardown.countDown()
            NativeRuntimeQueue.release(replacement)
        }
        assertTrue(replacement.worker.awaitTermination(1, TimeUnit.SECONDS))
        val fresh = NativeRuntimeQueue.acquire()
        assertNotSame(replacement.worker, fresh.worker)
        NativeRuntimeQueue.release(fresh)
        assertTrue(fresh.worker.awaitTermination(1, TimeUnit.SECONDS))
    }
}
