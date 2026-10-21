package com.arete.app.arete

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

object ScreenTimePreferences {
    private const val PREF_NAME = "arete_screen_time_prefs"

    private const val KEY_MONITORING_ENABLED = "monitoring_enabled"
    private const val KEY_HABIT_REMINDERS_ENABLED = "habit_reminders_enabled"
    private const val KEY_TASK_ALERTS_ENABLED = "task_alerts_enabled"
    private const val KEY_MORNING_REMINDER_TIME = "morning_reminder_time" // "08:30"
    private const val KEY_EVENING_REMINDER_TIME = "evening_reminder_time" // "20:00"
    private const val KEY_DISTRACTION_LIMIT_MINS = "distraction_limit_mins" // e.g. 30
    private const val KEY_AUTO_SHIELD_ON_LIMIT = "auto_shield_on_limit"
    private const val KEY_APP_CATEGORIES_JSON = "app_categories_json"
    private const val KEY_PENDING_ACTIONS_JSON = "pending_actions_json"

    // Default distraction keywords & packages
    val DEFAULT_DISTRACTIONS = setOf(
        "com.instagram.android",
        "com.facebook.katana",
        "com.twitter.android",
        "com.zhiliaoapp.musically", // TikTok
        "com.ss.android.ugc.trill",
        "com.reddit.frontpage",
        "com.netflix.mediaclient",
        "com.google.android.youtube",
        "com.snapchat.android",
        "tv.twitch.android.app",
        "com.pinterest",
        "com.supercell.clashofclans",
        "com.supercell.brawlstars"
    )

    // Default productive keywords & packages
    val DEFAULT_PRODUCTIVES = setOf(
        "com.arete.app.arete",
        "com.notion.id",
        "org.coursera.android",
        "com.duolingo",
        "md.obsidian",
        "com.github.android",
        "com.google.android.apps.docs",
        "com.google.android.apps.books",
        "com.amazon.kindle",
        "com.linkedin.android",
        "com.todoist"
    )

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
    }

    fun isMonitoringEnabled(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_MONITORING_ENABLED, false)
    }

    fun setMonitoringEnabled(context: Context, enabled: Boolean) {
        getPrefs(context).edit().putBoolean(KEY_MONITORING_ENABLED, enabled).apply()
    }

    fun areHabitRemindersEnabled(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_HABIT_REMINDERS_ENABLED, true)
    }

    fun setHabitRemindersEnabled(context: Context, enabled: Boolean) {
        getPrefs(context).edit().putBoolean(KEY_HABIT_REMINDERS_ENABLED, enabled).apply()
    }

    fun areTaskAlertsEnabled(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_TASK_ALERTS_ENABLED, true)
    }

    fun setTaskAlertsEnabled(context: Context, enabled: Boolean) {
        getPrefs(context).edit().putBoolean(KEY_TASK_ALERTS_ENABLED, enabled).apply()
    }

    fun getMorningReminderTime(context: Context): String {
        return getPrefs(context).getString(KEY_MORNING_REMINDER_TIME, "08:30") ?: "08:30"
    }

    fun setMorningReminderTime(context: Context, timeStr: String) {
        getPrefs(context).edit().putString(KEY_MORNING_REMINDER_TIME, timeStr).apply()
    }

    fun getEveningReminderTime(context: Context): String {
        return getPrefs(context).getString(KEY_EVENING_REMINDER_TIME, "20:00") ?: "20:00"
    }

    fun setEveningReminderTime(context: Context, timeStr: String) {
        getPrefs(context).edit().putString(KEY_EVENING_REMINDER_TIME, timeStr).apply()
    }

    fun getDistractionLimitMinutes(context: Context): Int {
        return getPrefs(context).getInt(KEY_DISTRACTION_LIMIT_MINS, 30)
    }

    fun setDistractionLimitMinutes(context: Context, minutes: Int) {
        getPrefs(context).edit().putInt(KEY_DISTRACTION_LIMIT_MINS, minutes).apply()
    }

    fun isAutoShieldOnLimit(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_AUTO_SHIELD_ON_LIMIT, true)
    }

    fun setAutoShieldOnLimit(context: Context, enabled: Boolean) {
        getPrefs(context).edit().putBoolean(KEY_AUTO_SHIELD_ON_LIMIT, enabled).apply()
    }

    /**
     * Returns category for a package: "productive", "distraction", or "neutral"
     */
    fun getAppCategory(context: Context, packageName: String, appName: String = ""): String {
        val categories = getAppCategories(context)
        if (categories.containsKey(packageName)) {
            return categories[packageName] ?: "neutral"
        }

        // Smart automatic heuristics if not explicitly categorized by user
        val lowerPkg = packageName.lowercase()
        val lowerName = appName.lowercase()

        if (DEFAULT_PRODUCTIVES.contains(lowerPkg) ||
            lowerPkg.contains("learn") || lowerPkg.contains("study") || lowerPkg.contains("read") ||
            lowerPkg.contains("book") || lowerPkg.contains("code") || lowerPkg.contains("editor") ||
            lowerName.contains("notion") || lowerName.contains("notes") || lowerName.contains("reader")) {
            return "productive"
        }

        if (DEFAULT_DISTRACTIONS.contains(lowerPkg) ||
            lowerPkg.contains("tiktok") || lowerPkg.contains("instagram") || lowerPkg.contains("twitter") ||
            lowerPkg.contains("facebook") || lowerPkg.contains("game") || lowerPkg.contains("reels") ||
            lowerName.contains("tiktok") || lowerName.contains("instagram") || lowerName.contains("game")) {
            return "distraction"
        }

        return "neutral"
    }

    fun getAppCategories(context: Context): Map<String, String> {
        val jsonStr = getPrefs(context).getString(KEY_APP_CATEGORIES_JSON, "{}") ?: "{}"
        val result = mutableMapOf<String, String>()
        try {
            val json = JSONObject(jsonStr)
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                result[key] = json.optString(key, "neutral")
            }
        } catch (e: Exception) {
            // Ignore
        }
        return result
    }

    fun saveAppCategories(context: Context, categories: Map<String, String>) {
        val json = JSONObject()
        for ((pkg, cat) in categories) {
            json.put(pkg, cat)
        }
        getPrefs(context).edit().putString(KEY_APP_CATEGORIES_JSON, json.toString()).apply()
    }

    /**
     * Enqueue action done/snoozed from Notification Shade so Flutter can process it
     */
    fun queuePendingAction(context: Context, type: String, id: String, extra: String = "") {
        val prefs = getPrefs(context)
        val currentJson = prefs.getString(KEY_PENDING_ACTIONS_JSON, "[]") ?: "[]"
        try {
            val array = JSONArray(currentJson)
            val item = JSONObject().apply {
                put("type", type)
                put("id", id)
                put("extra", extra)
                put("timestamp", System.currentTimeMillis())
            }
            array.put(item)
            prefs.edit().putString(KEY_PENDING_ACTIONS_JSON, array.toString()).apply()
        } catch (e: Exception) {
            // Ignore
        }
    }

    fun popPendingActions(context: Context): List<Map<String, Any>> {
        val prefs = getPrefs(context)
        val currentJson = prefs.getString(KEY_PENDING_ACTIONS_JSON, "[]") ?: "[]"
        val result = mutableListOf<Map<String, Any>>()
        try {
            val array = JSONArray(currentJson)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                result.add(
                    mapOf(
                        "type" to obj.optString("type"),
                        "id" to obj.optString("id"),
                        "extra" to obj.optString("extra"),
                        "timestamp" to obj.optLong("timestamp")
                    )
                )
            }
            // Clear once consumed
            prefs.edit().putString(KEY_PENDING_ACTIONS_JSON, "[]").apply()
        } catch (e: Exception) {
            // Ignore
        }
        return result
    }
}
