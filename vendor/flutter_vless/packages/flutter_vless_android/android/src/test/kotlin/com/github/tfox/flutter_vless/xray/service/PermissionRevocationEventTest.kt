package com.github.tfox.flutter_vless.xray.service

import android.content.Intent
import com.github.tfox.flutter_vless.xray.utils.AppConfigs
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.atomic.AtomicLong
import org.junit.Assert.*
import org.junit.Test
import org.mockito.Mockito.*

class PermissionRevocationEventTest {
    @Test fun permissionLossIsBroadcastBeforeTheCleanupWorkerCanRun() {
        val service = mock(XrayVPNService::class.java, CALLS_REAL_METHODS)
        val worker = mock(ScheduledThreadPoolExecutor::class.java)
        val recovery = SessionRecoveryPolicy().apply { activate() }
        fun set(name: String, value: Any) = XrayVPNService::class.java.getDeclaredField(name).apply {
            isAccessible = true; set(service, value)
        }
        set("runtimeLease", NativeRuntimeQueue.Lease(worker))
        set("requests", AtomicLong())
        set("recovery", recovery)
        val original = AppConfigs.V2RAY_STATE
        try {
            mockConstruction(Intent::class.java, withSettings().defaultAnswer(RETURNS_SELF)).use { intents ->
                service.onRevoke()
                assertFalse(recovery.authorized)
                val broadcast = intents.constructed().single()
                verify(service).sendBroadcast(broadcast)
                verify(broadcast).putExtra("STATE", AppConfigs.V2RAY_STATES.V2RAY_PERMISSION_REQUIRED)
                verify(worker).execute(any(Runnable::class.java))
            }
        } finally { AppConfigs.V2RAY_STATE = original }
    }
}
