// Copyright (c) 2024-2026 13FOX Studio / tfox.dev.
// SPDX-License-Identifier: MIT

package com.github.tfox.flutter_vless

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.github.tfox.flutter_vless.xray.core.BoundedProcessOutput
import com.github.tfox.flutter_vless.xray.core.XrayCoreManager
import com.github.tfox.flutter_vless.xray.dto.XrayConfig
import com.github.tfox.flutter_vless.xray.service.XrayVPNService
import com.github.tfox.flutter_vless.xray.utils.AppConfigs
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.ArrayList
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Main entry point for the Flutter Vless plugin on Android.
 *
 * This class handles communication between Flutter (Dart) and Android (Kotlin) using MethodChannels.
 * It is responsible for:
 * 1. Receiving commands from Flutter (start, stop, get delay, etc.).
 * 2. managing permissions (VPN, Notifications).
 * 3. Starting the [XrayVPNService] to run the VPN or Proxy.
 * 4. Sending status updates and traffic statistics back to Flutter via EventChannel.
 */
class FlutterVlessPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener, MethodChannel.MethodCallHandler {

    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var vpnControlMethod: MethodChannel
    private lateinit var vpnStatusEvent: EventChannel
    private var vpnStatusSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var xrayReceiver: BroadcastReceiver? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val permissionRequests = PermissionRequestCoordinator(
        launchNotifications = {
            ActivityCompat.requestPermissions(requireNotNull(activity),
                arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE_POST_NOTIFICATIONS)
        },
        launchVpn = {
            val current = requireNotNull(activity)
            val request = VpnService.prepare(current)
            if (request != null) current.startActivityForResult(request, REQUEST_CODE_VPN_PERMISSION)
            request == null
        }
    )
    private lateinit var context: Context

    companion object {
        private const val REQUEST_CODE_VPN_PERMISSION = 24
        private const val REQUEST_CODE_POST_NOTIFICATIONS = 1
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        // Channel for method calls (startVless, stopVless, etc.)
        vpnControlMethod = MethodChannel(binding.binaryMessenger, "flutter_vless")
        // Channel for streaming status updates (Connected, Disconnected, Traffic stats)
        vpnStatusEvent = EventChannel(binding.binaryMessenger, "flutter_vless/status")

        vpnControlMethod.setMethodCallHandler(this)
        vpnStatusEvent.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                vpnStatusSink = events
                registerReceiver()
                // A relaunched app must not assume DISCONNECTED while the
                // tunnel is still up; report the state the service last sent.
                emitStatus(AppConfigs.V2RAY_STATE, null)
            }

            override fun onCancel(arguments: Any?) {
                vpnStatusSink = null
                unregisterReceiver()
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSecurityCapabilities" -> result.success(mapOf("protectedServerSwitch" to true, "androidProxyDns" to true, "iosKeychainReference" to false))
            "startVless", "replaceVless" -> {
                if (call.argument<Boolean>("proxy_only") != true && VpnService.prepare(context) != null) {
                    result.error("VPN_PERMISSION_REQUIRED", "VPN permission is required before starting the tunnel", null)
                    return
                }
                // 1. Parse configuration from Flutter
                val config = XrayConfig()
                config.REMARK = call.argument("remark") ?: ""
                config.ANDROID_DNS_POLICY = call.argument("android_dns_policy") ?: "config"
                config.ANDROID_DNS_PROXY_OUTBOUND_TAG = call.argument("android_dns_proxy_outbound_tag")
                config.DPI_BYPASS = call.argument<Boolean>("dpi_bypass") == true
                config.DPI_PROFILE = call.argument<Int>("dpi_profile") ?: 0
                config.PROXY_ONLY = call.argument<Boolean>("proxy_only") == true
                config.V2RAY_FULL_JSON_CONFIG = call.argument("config") ?: ""
                config.BLOCKED_APPS = call.argument<ArrayList<String>>("blocked_apps") ?: ArrayList()
                config.BYPASS_SUBNETS = call.argument<ArrayList<String>>("bypass_subnets") ?: ArrayList()
                config.NOTIFICATION_DISCONNECT_BUTTON_NAME = call.argument("notificationDisconnectButtonName") ?: "Disconnect"

                // 2. Handle custom notification icon if set via initializeVless
                if (AppConfigs.NOTIFICATION_ICON_RESOURCE_NAME.isNotEmpty() && AppConfigs.NOTIFICATION_ICON_RESOURCE_TYPE.isNotEmpty()) {
                    config.NOTIFICATION_ICON_RESOURCE_NAME = AppConfigs.NOTIFICATION_ICON_RESOURCE_NAME
                    config.NOTIFICATION_ICON_RESOURCE_TYPE = AppConfigs.NOTIFICATION_ICON_RESOURCE_TYPE
                    val resId = context.resources.getIdentifier(
                        AppConfigs.NOTIFICATION_ICON_RESOURCE_NAME,
                        AppConfigs.NOTIFICATION_ICON_RESOURCE_TYPE,
                        context.packageName
                    )
                    config.APPLICATION_ICON = resId
                }

                // 3. Determine connection mode (VPN vs Proxy Only)
                if (call.argument<Boolean>("proxy_only") == true) {
                    AppConfigs.V2RAY_CONNECTION_MODE = AppConfigs.V2RAY_CONNECTION_MODES.PROXY_ONLY
                } else {
                    AppConfigs.V2RAY_CONNECTION_MODE = AppConfigs.V2RAY_CONNECTION_MODES.VPN_TUN
                }

                // 4. Try to parse the server address to exclude it from VPN routing (avoid loop)
                try {
                    val jsonConfig = org.json.JSONObject(config.V2RAY_FULL_JSON_CONFIG)
                    val outbounds = jsonConfig.optJSONArray("outbounds")
                    if (!config.DPI_BYPASS && outbounds != null && outbounds.length() > 0) {
                        val firstOutbound = outbounds.getJSONObject(0)
                        val settings = firstOutbound.optJSONObject("settings")
                        val vnext = settings?.optJSONArray("vnext")
                        if (vnext != null && vnext.length() > 0) {
                            val server = vnext.getJSONObject(0)
                            config.CONNECTED_V2RAY_SERVER_ADDRESS = server.optString("address", "")
                            config.CONNECTED_V2RAY_SERVER_PORT = server.optInt("port", 0).toString()
                        } else if (settings != null) {
                            config.CONNECTED_V2RAY_SERVER_ADDRESS = settings.optString("address", "")
                            config.CONNECTED_V2RAY_SERVER_PORT = settings.optInt("port", 0).toString()
                        }
                    }
                } catch (e: Exception) {
                    // Ignore parsing errors, fallback to not excluding IP
                }

                try { XrayCoreManager.validateConfiguration(config) }
                catch (_: Exception) {
                    result.error("INVALID_CONFIG", "VPN configuration or local inbound policy is incompatible", null)
                    return
                }

                // 5. Start the XrayVPNService
                // We pass the config and PROXY_ONLY flag via Intent extras
                val intent = Intent(context, XrayVPNService::class.java)
                intent.putExtra("COMMAND", AppConfigs.V2RAY_SERVICE_COMMANDS.START_SERVICE)
                intent.putExtra("V2RAY_CONFIG", config)
                intent.putExtra("PROXY_ONLY", config.PROXY_ONLY)
                intent.putExtra("PRESERVE_TUNNEL", call.method == "replaceVless")
                intent.putExtra("start_receiver", object : ResultReceiver(Handler(Looper.getMainLooper())) {
                    override fun onReceiveResult(resultCode: Int, resultData: Bundle?) {
                        if (resultCode == 0) result.success(null)
                        else {
                            val code = resultData?.getString("error_code")
                            val safeCode = if (code in setOf("ENDPOINT_RESOLUTION_FAILED", "NATIVE_VALIDATION_FAILED", "PROFILE_SAVE_FAILED", "VPN_PERMISSION_REQUIRED")) code!! else "INVALID_CONFIG"
                            result.error(safeCode, "VPN startup preflight failed; see the content-free client diagnostics", null)
                        }
                    }
                })

                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
                    else context.startService(intent)
                } catch (_: Exception) {
                    result.error("SERVICE_START_FAILED", "Android could not start the VPN service", null)
                }
            }
            "stopVless" -> {
                val handler = Handler(Looper.getMainLooper())
                val completed = AtomicBoolean(false)
                val deadline = Runnable {
                    if (completed.compareAndSet(false, true)) {
                        result.error("VPN_STOP_ERROR", "Timed out waiting for the VPN to stop. Retry stopping the VPN.", null)
                    }
                }
                handler.postDelayed(deadline, 30_000)
                val intent = Intent(context, XrayVPNService::class.java)
                intent.putExtra("COMMAND", AppConfigs.V2RAY_SERVICE_COMMANDS.STOP_SERVICE)
                intent.putExtra("stop_receiver", object : ResultReceiver(handler) {
                    override fun onReceiveResult(resultCode: Int, resultData: Bundle?) {
                        if (!completed.compareAndSet(false, true)) return
                        handler.removeCallbacks(deadline)
                        if (resultCode == 0) result.success(null)
                        else result.error("VPN_STOP_ERROR", "Unable to finish stopping the VPN. Retry stopping the VPN.", null)
                    }
                })
                try { context.startService(intent) }
                catch (_: Exception) {
                    if (completed.compareAndSet(false, true)) {
                        handler.removeCallbacks(deadline)
                        result.error("VPN_STOP_ERROR", "Android could not stop the VPN service. Retry stopping the VPN.", null)
                    }
                }
            }
            "initializeVless" -> {
                // Store notification icon settings globally
                val iconResourceName = call.argument<String>("notificationIconResourceName")
                val iconResourceType = call.argument<String>("notificationIconResourceType")
                if (iconResourceName != null && iconResourceType != null) {
                    AppConfigs.NOTIFICATION_ICON_RESOURCE_NAME = iconResourceName
                    AppConfigs.NOTIFICATION_ICON_RESOURCE_TYPE = iconResourceType
                }
                result.success(null)
            }
            "getServerDelay" -> {
                // Measures delay (ping) to a target URL using a specific config (without connecting)
                android.util.Log.d("FlutterVlessPlugin", "getServerDelay called")
                val configJson = call.argument<String>("config")
                val url = call.argument<String>("url") ?: "https://www.google.com"

                if (configJson == null) {
                    result.error("INVALID_CONFIG", "Config is null", null)
                    return
                }

                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("NO_ACTIVITY", "Activity is null", null)
                    return
                }

                executor.execute {
                    val delay = XrayCoreManager.getServerDelay(currentActivity, configJson, url)
                    currentActivity.runOnUiThread {
                        result.success(delay)
                    }
                }
            }
            "getConnectedServerDelay" -> {
                // Measures delay through the CURRENTLY active connection
                val url = call.argument<String>("url") ?: "https://www.google.com"
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error("NO_ACTIVITY", "Activity is null", null)
                    return
                }
                val handler = Handler(Looper.getMainLooper())
                var completed = false
                val timeout = Runnable { if (!completed) { completed = true; result.success(-1L) } }
                handler.postDelayed(timeout, 15000)
                val intent = Intent(context, XrayVPNService::class.java).setAction(XrayVPNService.ACTION_MEASURE_DELAY)
                intent.putExtra("url", url)
                intent.putExtra("receiver", object : ResultReceiver(handler) {
                    override fun onReceiveResult(resultCode: Int, resultData: Bundle?) {
                        if (!completed) {
                            completed = true; handler.removeCallbacks(timeout)
                            result.success(resultData?.getLong("delay", -1L) ?: -1L)
                        }
                    }
                })
                context.startService(intent)
            }
            "getCoreVersion" -> {
                // Returns the version of the underlying libxray.so
                executor.submit {
                    try {
                        val nativeLibraryDir = context.applicationInfo.nativeLibraryDir
                        val xrayExecutable = File(nativeLibraryDir, "libxray.so")
                        if (xrayExecutable.exists()) {
                            val p = ProcessBuilder(xrayExecutable.absolutePath, "-version").redirectErrorStream(true).start()
                            val version = BoundedProcessOutput.read(p, maxBytes = 4096).lineSequence().firstOrNull()
                            result.success(version)
                        } else {
                            result.success("Xray not found")
                        }
                    } catch (e: Exception) {
                        result.success("Version unavailable")
                    }
                }
            }
            "getProviderDebugSnapshot" -> {
                result.success(XrayCoreManager.getProviderDebugSnapshot(context))
            }
            "getTunnelStatus" -> {
                // Read-only query used at startup to adopt a tunnel that is
                // still running after the app was closed and reopened.
                result.success(stateName(AppConfigs.V2RAY_STATE))
            }
            "requestPermission" -> {
                val current = activity
                if (current == null) {
                    result.error("NO_ACTIVITY", "Open the app before requesting VPN permission", null)
                    return
                }
                val notificationsRequired = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    ActivityCompat.checkSelfPermission(current, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                if (!permissionRequests.request(notificationsRequired) { result.success(it) }) {
                    result.error("PERMISSION_REQUEST_IN_PROGRESS", "A VPN permission request is already pending", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Sends a status payload to Dart. Also used by onListen so a relaunched app
     * learns the state the service last published instead of assuming
     * DISCONNECTED while the tunnel is still up.
     */
    private fun emitStatus(
        state: AppConfigs.V2RAY_STATES?,
        duration: String?,
        uploadSpeed: Long = 0,
        downloadSpeed: Long = 0,
        uploadTraffic: Long = 0,
        downloadTraffic: Long = 0,
    ) {
        val data = ArrayList<String>()
        data.add(duration ?: "0")
        data.add(uploadSpeed.toString())
        data.add(downloadSpeed.toString())
        data.add(uploadTraffic.toString())
        data.add(downloadTraffic.toString())
        data.add(stateName(state))
        vpnStatusSink?.success(data)
    }

    private fun stateName(state: AppConfigs.V2RAY_STATES?): String = when (state) {
        AppConfigs.V2RAY_STATES.V2RAY_CONNECTED -> "CONNECTED"
        AppConfigs.V2RAY_STATES.V2RAY_CONNECTING -> "CONNECTING"
        AppConfigs.V2RAY_STATES.V2RAY_PERMISSION_REQUIRED -> "PERMISSION_REQUIRED"
        else -> "DISCONNECTED"
    }

    /**
     * Registers a BroadcastReceiver to listen for updates from XrayVPNService.
     * This allows us to receive state changes (Connected/Disconnected) and traffic stats.
     */
    private fun registerReceiver() {
        if (activity == null) return
        if (xrayReceiver == null) {
            xrayReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent == null || vpnStatusSink == null) return
                    val state = intent.getSerializableExtra("STATE") as? AppConfigs.V2RAY_STATES
                    emitStatus(
                        state = state,
                        duration = intent.getStringExtra("DURATION"),
                        uploadSpeed = intent.getLongExtra("UPLOAD_SPEED", 0),
                        downloadSpeed = intent.getLongExtra("DOWNLOAD_SPEED", 0),
                        uploadTraffic = intent.getLongExtra("UPLOAD_TRAFFIC", 0),
                        downloadTraffic = intent.getLongExtra("DOWNLOAD_TRAFFIC", 0),
                    )
                }
            }
        }
        val filter = IntentFilter(AppConfigs.V2RAY_CONNECTION_INFO)
        // AndroidX also enforces a same-app signature permission before API 33.
        // The legacy platform overload accepts spoofed status from other apps.
        activity?.let {
            ContextCompat.registerReceiver(it, xrayReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        }
    }

    private fun unregisterReceiver() {
        if (activity != null && xrayReceiver != null) {
            try {
                activity?.unregisterReceiver(xrayReceiver)
            } catch (e: Exception) {
                // ignore
            }
            xrayReceiver = null
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        permissionRequests.cancel()
        unregisterReceiver()
        vpnControlMethod.setMethodCallHandler(null)
        vpnStatusEvent.setStreamHandler(null)
        executor.shutdown()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
        if (vpnStatusSink != null) {
            registerReceiver()
        }
    }

    private fun detachActivity() {
        unregisterReceiver()
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() { detachActivity() }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
        permissionRequests.cancel()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_VPN_PERMISSION) {
            return permissionRequests.vpnCompleted(resultCode == Activity.RESULT_OK)
        }
        return false
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        // Notifications are optional for VPN operation, including when denied or dismissed.
        return requestCode == REQUEST_CODE_POST_NOTIFICATIONS && permissionRequests.notificationsCompleted()
    }
}
