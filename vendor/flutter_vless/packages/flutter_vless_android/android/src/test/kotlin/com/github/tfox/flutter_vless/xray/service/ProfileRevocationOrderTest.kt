package com.github.tfox.flutter_vless.xray.service

import com.github.tfox.flutter_vless.xray.dto.XrayConfig
import com.github.tfox.flutter_vless.xray.utils.AppConfigs
import android.content.Intent
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*

class ProfileRevocationOrderTest {
    @Test fun revocationCannotBeUndoneByAnAlreadyPendingProfileWrite() {
        val lease = NativeRuntimeQueue.acquire()
        val service = mock(XrayVPNService::class.java, CALLS_REAL_METHODS)
        val profiles = mock(AuthorizedProfileStore::class.java)
        val recovery = SessionRecoveryPolicy().apply { activate() }
        fun set(name: String, value: Any) = XrayVPNService::class.java.getDeclaredField(name).apply {
            isAccessible = true; set(service, value)
        }
        set("runtimeLease", lease)
        set("requests", AtomicLong())
        set("recovery", recovery)
        set("profiles", profiles)
        set("config", XrayConfig()) // JNI teardown is outside this file-IO boundary.
        val originalState = AppConfigs.V2RAY_STATE
        // The file boundary models AtomicFile.finishWrite occurring after deletion.
        val authorizationExists = AtomicBoolean(true)
        val entered = CountDownLatch(1)
        val finish = CountDownLatch(1)
        val config = XrayConfig()
        doAnswer {
            entered.countDown()
            check(finish.await(3, TimeUnit.SECONDS))
            authorizationExists.set(true)
            null
        }.`when`(profiles).save(config)
        doAnswer { authorizationExists.set(false); null }.`when`(profiles).disarm()
        lease.worker.execute { profiles.save(config) }
        try {
            assertTrue(entered.await(1, TimeUnit.SECONDS))
            mockConstruction(Intent::class.java, withSettings().defaultAnswer(RETURNS_SELF)).use {
                service.onRevoke()
            }
            assertFalse("Runtime callbacks must lose authorization immediately", recovery.authorized)
            finish.countDown()
            lease.worker.submit {}.get(1, TimeUnit.SECONDS)
            assertFalse("The late commit must not resurrect authorization", authorizationExists.get())
        } finally {
            finish.countDown()
            service.onDestroy()
            assertTrue(lease.worker.awaitTermination(2, TimeUnit.SECONDS))
            AppConfigs.V2RAY_STATE = originalState
        }
    }
}
