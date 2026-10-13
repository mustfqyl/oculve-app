package com.github.tfox.flutter_vless

import org.junit.Assert.*
import org.junit.Test

class PermissionRequestCoordinatorTest {
    @Test fun notificationCallbackPrecedesVpnAndDenialDoesNotBlockVpn() {
        val launches = mutableListOf<String>()
        val results = mutableListOf<Boolean>()
        val flow = PermissionRequestCoordinator({ launches += "notification" }, { launches += "vpn"; false })
        assertTrue(flow.request(true, results::add))
        assertEquals(listOf("notification"), launches)
        assertTrue(results.isEmpty())
        assertFalse(flow.vpnCompleted(true))
        assertTrue(flow.notificationsCompleted())
        assertEquals(listOf("notification", "vpn"), launches)
        assertTrue(flow.vpnCompleted(true))
        assertEquals(listOf(true), results)
        assertFalse(flow.vpnCompleted(false))
    }

    @Test fun duplicateRequestsCannotReplaceThePendingFlutterResult() {
        val results = mutableListOf<Boolean>()
        val flow = PermissionRequestCoordinator({}, { false })
        assertTrue(flow.request(false, results::add))
        assertFalse(flow.request(false) { fail("Duplicate request stole completion") })
        flow.vpnCompleted(false)
        assertEquals(listOf(false), results)
        assertTrue(flow.request(false, results::add))
    }

    @Test fun priorVpnAuthorizationCompletesWithoutAnotherDialog() {
        var result: Boolean? = null
        val flow = PermissionRequestCoordinator({ fail("Unnecessary notification prompt") }, { true })
        flow.request(false) { result = it }
        assertEquals(true, result)
    }

    @Test fun activityRemovalOrLaunchFailureCompletesOnceAndAllowsRetry() {
        val results = mutableListOf<Boolean>()
        var failLaunch = true
        val flow = PermissionRequestCoordinator({}, { if (failLaunch) error("Activity unavailable") else false })
        flow.request(false, results::add)
        assertEquals(listOf(false), results)
        failLaunch = false
        flow.request(false, results::add)
        flow.cancel(); flow.cancel(); flow.vpnCompleted(true)
        assertEquals(listOf(false, false), results)
        assertTrue(flow.request(false, results::add))
    }
}
