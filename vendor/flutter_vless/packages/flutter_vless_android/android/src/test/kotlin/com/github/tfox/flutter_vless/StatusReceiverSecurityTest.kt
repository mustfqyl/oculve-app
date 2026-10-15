package com.github.tfox.flutter_vless

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import com.github.tfox.flutter_vless.xray.utils.AppConfigs
import io.flutter.plugin.common.EventChannel
import org.junit.Assert.assertEquals
import org.junit.Test
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.eq
import org.mockito.ArgumentMatchers.isNull
import org.mockito.Mockito.*

class StatusReceiverSecurityTest {
    @Test fun legacyAndroidRequiresSameAppPermissionAndStillDeliversStatus() {
        // JVM Android stubs use SDK_INT=0, exercising AndroidX's pre-26 branch.
        // That branch must require the manifest's signature permission instead
        // of accepting arbitrary applications' connection-state broadcasts.
        val activity = mock(Activity::class.java)
        `when`(activity.packageName).thenReturn("com.oculve.app")
        val sink = mock(EventChannel.EventSink::class.java)
        val plugin = FlutterVlessPlugin()
        FlutterVlessPlugin::class.java.getDeclaredField("activity").apply {
            isAccessible = true; set(plugin, activity)
        }
        FlutterVlessPlugin::class.java.getDeclaredField("vpnStatusSink").apply {
            isAccessible = true; set(plugin, sink)
        }
        FlutterVlessPlugin::class.java.getDeclaredMethod("registerReceiver").apply {
            isAccessible = true; invoke(plugin)
        }

        val receiver = ArgumentCaptor.forClass(BroadcastReceiver::class.java)
        verify(activity).registerReceiver(receiver.capture(), any(IntentFilter::class.java),
            eq("com.oculve.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"), isNull())
        verify(activity, never()).registerReceiver(any(BroadcastReceiver::class.java), any(IntentFilter::class.java))

        val intent = mock(Intent::class.java)
        `when`(intent.getSerializableExtra("STATE")).thenReturn(AppConfigs.V2RAY_STATES.V2RAY_CONNECTED)
        receiver.value.onReceive(activity, intent)
        val event = ArgumentCaptor.forClass(Any::class.java)
        verify(sink).success(event.capture())
        assertEquals("CONNECTED", (event.value as List<*>).last())
        `when`(intent.getSerializableExtra("STATE")).thenReturn(AppConfigs.V2RAY_STATES.V2RAY_PERMISSION_REQUIRED)
        receiver.value.onReceive(activity, intent)
        verify(sink, times(2)).success(event.capture())
        assertEquals("PERMISSION_REQUIRED", (event.value as List<*>).last())
    }
}
