package com.github.tfox.flutter_vless

/** Exactly one system dialog at a time; notification denial never denies VPN. */
internal class PermissionRequestCoordinator(
    private val launchNotifications: () -> Unit,
    private val launchVpn: () -> Boolean
) {
    private enum class Stage { IDLE, NOTIFICATIONS, VPN }
    private var stage = Stage.IDLE
    private var completion: ((Boolean) -> Unit)? = null

    fun request(notificationsRequired: Boolean, complete: (Boolean) -> Unit): Boolean {
        if (completion != null) return false
        completion = complete
        if (notificationsRequired) {
            stage = Stage.NOTIFICATIONS
            try { launchNotifications() } catch (_: Exception) { finish(false) }
        } else requestVpn()
        return true
    }

    fun notificationsCompleted(): Boolean {
        if (stage != Stage.NOTIFICATIONS) return false
        requestVpn()
        return true
    }

    fun vpnCompleted(granted: Boolean): Boolean {
        if (stage != Stage.VPN) return false
        finish(granted)
        return true
    }

    fun cancel() { finish(false) }

    private fun requestVpn() {
        stage = Stage.VPN
        try {
            // true means Android already authorized this app; no VPN dialog is needed.
            if (launchVpn()) finish(true)
        } catch (_: Exception) { finish(false) }
    }

    private fun finish(granted: Boolean) {
        val callback = completion
        completion = null
        stage = Stage.IDLE
        callback?.invoke(granted)
    }
}
