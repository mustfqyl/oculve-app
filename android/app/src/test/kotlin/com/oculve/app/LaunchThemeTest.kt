package com.oculve.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LaunchThemeTest {
    @Test
    fun explicitAppearanceWinsOverTheLocalClock() {
        assertTrue(resolveLaunchDark("dark", 12))
        assertFalse(resolveLaunchDark("light", 0))
    }

    @Test
    fun automaticAndInvalidPreferencesMatchFlutterTimeBoundaries() {
        for (mode in listOf("auto", null, "invalid")) {
            assertTrue(resolveLaunchDark(mode, 0))
            assertTrue(resolveLaunchDark(mode, 5))
            assertFalse(resolveLaunchDark(mode, 6))
            assertFalse(resolveLaunchDark(mode, 17))
            assertTrue(resolveLaunchDark(mode, 18))
            assertTrue(resolveLaunchDark(mode, 23))
        }
    }
}
