package com.arete.app.arete

import android.content.Context
import android.content.SharedPreferences

object FocusShieldPreferences {
    private const val PREFS_NAME = "arete_focus_shield_prefs"

    private const val KEY_IS_ACTIVE = "shield_is_active"
    private const val KEY_BLOCKED_PACKAGES = "shield_blocked_packages"
    private const val KEY_SESSION_END_TIME_MS = "shield_end_time_ms"
    private const val KEY_STRICT_MODE = "shield_strict_mode"
    private const val KEY_SESSION_LABEL = "shield_session_label"
    private const val KEY_SESSION_ID = "shield_session_id"
    private const val KEY_INTERRUPTION_COUNT = "shield_interruption_count"
    private const val KEY_LAST_INTERRUPTED_PACKAGE = "shield_last_pkg"
    private const val KEY_LAST_INTERRUPTED_TIME = "shield_last_time"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun isShieldActive(context: Context): Boolean {
        val prefs = getPrefs(context)
        val active = prefs.getBoolean(KEY_IS_ACTIVE, false)
        if (!active) return false

        val endTime = prefs.getLong(KEY_SESSION_END_TIME_MS, 0L)
        if (endTime > 0 && System.currentTimeMillis() >= endTime) {
            // Automatically deactivate expired shield
            deactivateShield(context)
            return false
        }
        return true
    }

    fun activateShield(
        context: Context,
        blockedPackages: Set<String>,
        endTimeMs: Long,
        strictMode: Boolean,
        sessionLabel: String,
        sessionId: String
    ) {
        getPrefs(context).edit()
            .putBoolean(KEY_IS_ACTIVE, true)
            .putStringSet(KEY_BLOCKED_PACKAGES, blockedPackages)
            .putLong(KEY_SESSION_END_TIME_MS, endTimeMs)
            .putBoolean(KEY_STRICT_MODE, strictMode)
            .putString(KEY_SESSION_LABEL, sessionLabel)
            .putString(KEY_SESSION_ID, sessionId)
            .putInt(KEY_INTERRUPTION_COUNT, 0)
            .apply()
    }

    fun deactivateShield(context: Context) {
        getPrefs(context).edit()
            .putBoolean(KEY_IS_ACTIVE, false)
            .apply()
    }

    fun pauseShield(context: Context) {
        getPrefs(context).edit()
            .putBoolean(KEY_IS_ACTIVE, false)
            .apply()
    }

    fun resumeShield(context: Context, newEndTimeMs: Long) {
        getPrefs(context).edit()
            .putBoolean(KEY_IS_ACTIVE, true)
            .putLong(KEY_SESSION_END_TIME_MS, newEndTimeMs)
            .apply()
    }

    fun getBlockedPackages(context: Context): Set<String> {
        return getPrefs(context).getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
    }

    fun setBlockedPackages(context: Context, packages: Set<String>) {
        getPrefs(context).edit()
            .putStringSet(KEY_BLOCKED_PACKAGES, packages)
            .apply()
    }

    fun getEndTimeMs(context: Context): Long {
        return getPrefs(context).getLong(KEY_SESSION_END_TIME_MS, 0L)
    }

    fun isStrictMode(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_STRICT_MODE, false)
    }

    fun getSessionLabel(context: Context): String {
        return getPrefs(context).getString(KEY_SESSION_LABEL, "Deep Focus Session") ?: "Deep Focus Session"
    }

    fun getSessionId(context: Context): String {
        return getPrefs(context).getString(KEY_SESSION_ID, "") ?: ""
    }

    fun getInterruptionCount(context: Context): Int {
        return getPrefs(context).getInt(KEY_INTERRUPTION_COUNT, 0)
    }

    fun incrementInterruptionCount(context: Context): Int {
        val prefs = getPrefs(context)
        val current = prefs.getInt(KEY_INTERRUPTION_COUNT, 0) + 1
        prefs.edit().putInt(KEY_INTERRUPTION_COUNT, current).apply()
        return current
    }

    fun shouldThrottleInterruption(context: Context, packageName: String): Boolean {
        val prefs = getPrefs(context)
        val lastPkg = prefs.getString(KEY_LAST_INTERRUPTED_PACKAGE, null)
        val lastTime = prefs.getLong(KEY_LAST_INTERRUPTED_TIME, 0L)
        val now = System.currentTimeMillis()

        if (lastPkg == packageName && (now - lastTime) < 1800) {
            return true // Throttle within 1.8 seconds to avoid flickering
        }

        prefs.edit()
            .putString(KEY_LAST_INTERRUPTED_PACKAGE, packageName)
            .putLong(KEY_LAST_INTERRUPTED_TIME, now)
            .apply()
        return false
    }
}
