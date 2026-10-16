package com.oculve.app

import android.app.Application
import android.app.UiModeManager
import android.os.Build
import java.util.Calendar

class OculveApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        syncLaunchTheme()
    }

    fun isDarkLaunchTheme(): Boolean {
        val mode = runCatching {
            getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                .getString("flutter.app_theme_mode", "auto")
        }.getOrNull()
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return resolveLaunchDark(mode, hour)
    }

    fun syncLaunchTheme() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        // Android persists this per-app override for the system's next splash.
        getSystemService(UiModeManager::class.java).setApplicationNightMode(
            if (isDarkLaunchTheme()) UiModeManager.MODE_NIGHT_YES else UiModeManager.MODE_NIGHT_NO,
        )
    }
}

internal fun resolveLaunchDark(mode: String?, hour: Int): Boolean = when (mode) {
    "dark" -> true
    "light" -> false
    else -> hour >= 18 || hour < 6
}
