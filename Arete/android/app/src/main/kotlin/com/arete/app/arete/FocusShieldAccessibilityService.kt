package com.arete.app.arete

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class FocusShieldAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "FocusShieldService"
        var isServiceConnected: Boolean = false
            private set

        // Critical system packages that must never be blocked under any circumstances
        private val SYSTEM_WHITELIST = setOf(
            "com.arete.app.arete",
            "com.android.systemui",
            "com.android.settings",
            "android",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.google.android.dialer",
            "com.android.dialer",
            "com.google.android.inputmethod.latin",
            "com.android.inputmethod.latin",
            "com.samsung.android.honeyboard"
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceConnected = true
        Log.i(TAG, "Areté Focus Shield Accessibility Service connected successfully.")
    }

    override fun onDestroy() {
        isServiceConnected = false
        super.onDestroy()
        Log.i(TAG, "Areté Focus Shield Accessibility Service destroyed.")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val foregroundPackage = event.packageName?.toString() ?: return

        // Update active foreground package for Screen Time Monitoring
        ScreenTimeMonitoringService.currentForegroundPackage = foregroundPackage

        // 1. Never intercept Areté or core system components
        if (SYSTEM_WHITELIST.contains(foregroundPackage)) {
            return
        }

        // 2. Check if the package is the current default home launcher (so user can go home)
        if (isHomeLauncher(foregroundPackage)) {
            return
        }

        // 3. Check if Focus Shield is currently active
        if (!FocusShieldPreferences.isShieldActive(this)) {
            return
        }

        // 4. Check if the foreground package is on the user's blocked list
        val blockedPackages = FocusShieldPreferences.getBlockedPackages(this)
        if (!blockedPackages.contains(foregroundPackage)) {
            return
        }

        // 5. Throttle to prevent visual loops or flicker
        if (FocusShieldPreferences.shouldThrottleInterruption(this, foregroundPackage)) {
            return
        }

        // 6. Record the distraction attempt
        FocusShieldPreferences.incrementInterruptionCount(this)
        Log.w(TAG, "Blocked distracting app: $foregroundPackage during active focus session.")

        // 7. Launch the calm Interruption Screen
        val intent = Intent(this, FocusShieldInterruptionActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(FocusShieldInterruptionActivity.EXTRA_PACKAGE_NAME, foregroundPackage)
            putExtra(FocusShieldInterruptionActivity.EXTRA_SESSION_LABEL, FocusShieldPreferences.getSessionLabel(this@FocusShieldAccessibilityService))
            putExtra(FocusShieldInterruptionActivity.EXTRA_END_TIME_MS, FocusShieldPreferences.getEndTimeMs(this@FocusShieldAccessibilityService))
            putExtra(FocusShieldInterruptionActivity.EXTRA_STRICT_MODE, FocusShieldPreferences.isStrictMode(this@FocusShieldAccessibilityService))
        }
        startActivity(intent)
    }

    override fun onInterrupt() {
        Log.i(TAG, "Areté Focus Shield interrupted.")
    }

    private fun isHomeLauncher(packageName: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            resolveInfo?.activityInfo?.packageName == packageName
        } catch (e: Exception) {
            false
        }
    }
}
