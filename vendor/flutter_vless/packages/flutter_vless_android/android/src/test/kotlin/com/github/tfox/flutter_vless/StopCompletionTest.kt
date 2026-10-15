package com.github.tfox.flutter_vless

import android.content.Context
import android.content.Intent
import android.os.Parcelable
import android.os.Handler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Test
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito.*

class StopCompletionTest {
    @Test fun stopWaitsForNativeAcknowledgement() = acknowledgement(0)
    @Test fun failedNativeStopDoesNotReportSuccess() = acknowledgement(1)

    private fun acknowledgement(code: Int) {
        val context = mock(Context::class.java)
        val result = mock(MethodChannel.Result::class.java)
        val plugin = FlutterVlessPlugin()
        FlutterVlessPlugin::class.java.getDeclaredField("context").apply {
            isAccessible = true; set(plugin, context)
        }
        mockConstruction(Intent::class.java).use { intents ->
            plugin.onMethodCall(MethodCall("stopVless", null), result)
            verifyNoInteractions(result)
            val intent = intents.constructed().single()
            verify(context).startService(intent)
            val receiver = ArgumentCaptor.forClass(Parcelable::class.java)
            verify(intent).putExtra(eq("stop_receiver"), receiver.capture())
            receiver.value.javaClass.getDeclaredMethod("onReceiveResult", Int::class.javaPrimitiveType,
                android.os.Bundle::class.java).apply {
                isAccessible = true; invoke(receiver.value, code, null)
            }
            if (code == 0) verify(result).success(null)
            else {
                verify(result).error(eq("VPN_STOP_ERROR"), anyString(), isNull())
                verify(result, never()).success(any())
            }
        }
    }

    @Test fun refusedStopServiceDoesNotReportSuccess() {
        val context = mock(Context::class.java)
        val result = mock(MethodChannel.Result::class.java)
        val plugin = FlutterVlessPlugin()
        FlutterVlessPlugin::class.java.getDeclaredField("context").apply {
            isAccessible = true; set(plugin, context)
        }
        `when`(context.startService(any(Intent::class.java))).thenThrow(IllegalStateException())
        plugin.onMethodCall(MethodCall("stopVless", null), result)
        verify(result).error(eq("VPN_STOP_ERROR"), anyString(), isNull())
        verify(result, never()).success(any())
    }

    @Test fun missingAcknowledgementTimesOutAndIgnoresLateReply() {
        val context = mock(Context::class.java)
        val result = mock(MethodChannel.Result::class.java)
        val plugin = FlutterVlessPlugin()
        FlutterVlessPlugin::class.java.getDeclaredField("context").apply {
            isAccessible = true; set(plugin, context)
        }
        mockConstruction(Handler::class.java).use { handlers ->
            mockConstruction(Intent::class.java).use { intents ->
                plugin.onMethodCall(MethodCall("stopVless", null), result)
                verifyNoInteractions(result)
                val deadline = ArgumentCaptor.forClass(Runnable::class.java)
                verify(handlers.constructed().single()).postDelayed(deadline.capture(), eq(30_000L))
                deadline.value.run()
                verify(result).error(eq("VPN_STOP_ERROR"), anyString(), isNull())
                val receiver = ArgumentCaptor.forClass(Parcelable::class.java)
                verify(intents.constructed().single()).putExtra(eq("stop_receiver"), receiver.capture())
                receiver.value.javaClass.getDeclaredMethod("onReceiveResult", Int::class.javaPrimitiveType,
                    android.os.Bundle::class.java).apply {
                    isAccessible = true; invoke(receiver.value, 0, null)
                }
                verifyNoMoreInteractions(result)
            }
        }
    }
}
