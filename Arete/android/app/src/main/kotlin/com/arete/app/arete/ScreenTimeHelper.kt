package com.arete.app.arete

import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import java.util.Calendar

object ScreenTimeHelper {

    private const val TAG = "ScreenTimeHelper"

    // Packages that should not be counted toward personal screen time
    private val EXCLUDED_PACKAGES = setOf(
        "com.android.systemui",
        "android",
        "com.google.android.inputmethod.latin",
        "com.android.inputmethod.latin",
        "com.samsung.android.honeyboard",
        "com.motorola.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.android.launcher",
        "com.sec.android.app.launcher",
        "com.miui.home",
        "com.oppo.launcher",
        "com.oneplus.launcher",
        "com.huawei.android.launcher",
        "com.transsion.launcher",
        "com.nothing.launcher",
        "com.bbk.launcher2",
        "com.motorola.mobiledesktop",
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.google.android.as",
        "com.android.settings.intelligence"
    )

    /**
     * Uses Android's foreground-duration aggregates for app usage. Visible time is
     * deliberately excluded because PiP and multi-window can count apps that are
     * visible without being the app the user is actively using.
     */
    fun getTodayUsageStats(context: Context): Map<String, Any> {
        val now = System.currentTimeMillis()
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = calendar.timeInMillis
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyMap()

        val packageUsageMap = mutableMapOf<String, Long>()
        val appLaunchCounts = mutableMapOf<String, Int>()
        var deviceUnlockCount = 0
        var notificationCount = 0
        var lastResumedPackage = ""
        var screenIsInteractive = true

        // 1. Process high-resolution UsageEvents from midnight to now
        try {
            val events = usageStatsManager.queryEvents(startTime, now)
            val event = UsageEvents.Event()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val pkg = event.packageName?.toString()

                when (event.eventType) {
                    UsageEvents.Event.KEYGUARD_HIDDEN -> {
                        deviceUnlockCount++
                    }
                    UsageEvents.Event.SCREEN_INTERACTIVE -> {
                        screenIsInteractive = true
                    }
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE, UsageEvents.Event.KEYGUARD_SHOWN -> {
                        screenIsInteractive = false
                        lastResumedPackage = ""
                    }
                    12 /* NOTIFICATION_INTERRUPTION */ -> {
                        if (pkg != null && !isExcluded(context, pkg)) {
                            notificationCount++
                        }
                    }
                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        if (pkg != null && !isExcluded(context, pkg)) {
                            appLaunchCounts[pkg] = (appLaunchCounts[pkg] ?: 0) + 1
                            lastResumedPackage = pkg
                            screenIsInteractive = true
                        } else if (pkg != null) {
                            lastResumedPackage = ""
                        }
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> {
                        if (pkg != null && lastResumedPackage == pkg) lastResumedPackage = ""
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing usage events: ${e.message}")
        }

        // 2. Query OS-level aggregated usage stats (official queryAndAggregateUsageStats)
        val osAggregated = try {
            usageStatsManager.queryAndAggregateUsageStats(startTime, now)
        } catch (e: Exception) {
            Log.e(TAG, "Error querying aggregated usage stats: ${e.message}")
            emptyMap<String, UsageStats>()
        }

        // UsageStats is the authoritative duration source. Event-derived durations
        // can drift from OS accounting across activity transitions and OEM behavior.
        for ((pkg, stat) in osAggregated) {
            if (isExcluded(context, pkg) || stat.lastTimeUsed < startTime) continue
            val foregroundMs = stat.totalTimeInForeground
            if (foregroundMs > 0L) packageUsageMap[pkg] = foregroundMs
        }

        var totalScreenTimeMs = 0L
        val appMinutesMap = mutableMapOf<String, Int>()
        val appDetailsList = mutableListOf<Map<String, Any>>()
        val pm = context.packageManager

        var productiveTimeMs = 0L
        var distractionTimeMs = 0L
        var neutralTimeMs = 0L

        for ((pkg, ms) in packageUsageMap) {
            val mins = ((ms + 30000L) / 60000L).toInt()
            totalScreenTimeMs += ms
            appMinutesMap[pkg] = mins

                val appLabel = try {
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: Exception) {
                    pkg
                }
                val category = ScreenTimePreferences.getAppCategory(context, pkg, appLabel)
                when (category) {
                    "productive" -> productiveTimeMs += ms
                    "distraction" -> distractionTimeMs += ms
                    else -> neutralTimeMs += ms
                }

                appDetailsList.add(
                    mapOf(
                        "packageName" to pkg,
                        "appName" to appLabel,
                        "minutes" to mins,
                        "category" to category,
                        "launches" to (appLaunchCounts[pkg] ?: 0)
                    )
                )
            }

        // Sort app list descending by usage minutes
        appDetailsList.sortByDescending { (it["minutes"] as? Int) ?: 0 }

        val totalMinutes = ((totalScreenTimeMs + 30000L) / 60000L).toInt()
        val productiveMinutes = ((productiveTimeMs + 30000L) / 60000L).toInt()
        val distractionMinutes = ((distractionTimeMs + 30000L) / 60000L).toInt()
        val neutralMinutes = ((neutralTimeMs + 30000L) / 60000L).toInt()
        val currentPkg = if (screenIsInteractive) lastResumedPackage else ""
        val currentAppMinutes = appMinutesMap[currentPkg] ?: 0
        val currentAppName = try {
            if (currentPkg.isNotBlank()) {
                val info = pm.getApplicationInfo(currentPkg, 0)
                pm.getApplicationLabel(info).toString()
            } else ""
        } catch (e: Exception) {
            currentPkg
        }

        val category = ScreenTimePreferences.getAppCategory(context, currentPkg, currentAppName)

        return mapOf(
            "totalScreenTimeMinutes" to totalMinutes,
            "currentPackage" to currentPkg,
            "currentAppName" to currentAppName,
            "currentAppMinutes" to currentAppMinutes,
            "category" to category,
            "appUsageMinutes" to appMinutesMap,
            "deviceUnlockCount" to deviceUnlockCount,
            "notificationCount" to notificationCount,
            "productiveMinutes" to productiveMinutes,
            "distractionMinutes" to distractionMinutes,
            "neutralMinutes" to neutralMinutes,
            "appDetails" to appDetailsList,
            "shortFormBlockedCount" to 0,
            "isShortFormBlockingEnabled" to false,
            "remainingQuickPassSeconds" to 0
        )
    }

    private fun isExcluded(context: Context, pkg: String?): Boolean {
        if (pkg.isNullOrBlank()) return true
        if (EXCLUDED_PACKAGES.contains(pkg)) return true
        if (pkg.startsWith("com.android.internal")) return true
        return isHomeLauncher(context, pkg)
    }

    private fun isHomeLauncher(context: Context, pkg: String): Boolean {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
            val resolveInfo = context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            return resolveInfo?.activityInfo?.packageName == pkg
        } catch (e: Exception) {
            return false
        }
    }
}
