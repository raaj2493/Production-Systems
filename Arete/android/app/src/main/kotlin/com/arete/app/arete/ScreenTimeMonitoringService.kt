package com.arete.app.arete

import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import java.util.Calendar

class ScreenTimeMonitoringService : Service() {

    companion object {
        private const val TAG = "ScreenTimeService"
        var isServiceRunning: Boolean = false
            private set

        // Active foreground package reported by AccessibilityService or UsageStats
        @Volatile
        var currentForegroundPackage: String = ""

        @Volatile
        var latestTotalScreenTimeMinutes: Int = 0

        @Volatile
        var latestCurrentAppName: String = ""

        @Volatile
        var latestCurrentAppMinutes: Int = 0

        @Volatile
        var latestCategory: String = "neutral"

        @Volatile
        var lastDistractionAlertPackage: String = ""

        @Volatile
        var lastDistractionAlertTime: Long = 0L

        fun start(context: Context) {
            val intent = Intent(context, ScreenTimeMonitoringService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, ScreenTimeMonitoringService::class.java)
            context.stopService(intent)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastObservedPackage: String = ""
    private var currentAppStartTimeMs: Long = System.currentTimeMillis()

    private val updateRunnable = object : Runnable {
        override fun run() {
            try {
                pollScreenTimeAndApp()
            } catch (e: Exception) {
                Log.e(TAG, "Error polling screen time: ${e.message}")
            }
            // Poll every 10 seconds for responsive notification updates
            handler.postDelayed(this, 10000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        Log.i(TAG, "ScreenTimeMonitoringService created.")

        // Start foreground immediately
        val initialNotification = AreteNotificationHelper.buildScreenTimeNotification(
            context = this,
            totalScreenTimeMinutes = 0,
            foregroundAppPackage = "",
            foregroundAppName = "Starting Areté Tracker...",
            foregroundDurationMinutes = 0,
            category = "neutral"
        )
        try {
            startForeground(AreteNotificationHelper.NOTIFICATION_ID_SCREEN_TIME, initialNotification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to startForeground: ${e.localizedMessage}")
        }

        handler.post(updateRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        isServiceRunning = false
        handler.removeCallbacks(updateRunnable)
        stopForeground(true)
        Log.i(TAG, "ScreenTimeMonitoringService destroyed.")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun pollScreenTimeAndApp() {
        val now = System.currentTimeMillis()
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager

        // 1. Calculate Daily Total Screen Time (from 00:00:00 today)
        var totalScreenTimeMs = 0L
        val packageUsageMap = mutableMapOf<String, Long>()

        if (usageStatsManager != null) {
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val startTime = calendar.timeInMillis
            val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, now)
            if (stats != null) {
                for (stat in stats) {
                    if (stat.totalTimeInForeground > 0) {
                        totalScreenTimeMs += stat.totalTimeInForeground
                        packageUsageMap[stat.packageName] = stat.totalTimeInForeground
                    }
                }
            }
        }

        val totalMinutes = (totalScreenTimeMs / (1000 * 60)).toInt()
        latestTotalScreenTimeMinutes = totalMinutes

        // 2. Identify Current Foreground App
        var foregroundPkg = currentForegroundPackage
        if (foregroundPkg.isBlank() && usageStatsManager != null) {
            foregroundPkg = queryForegroundAppFromEvents(usageStatsManager, now)
        }

        // If package changed, record start time
        if (foregroundPkg.isNotBlank() && foregroundPkg != lastObservedPackage) {
            lastObservedPackage = foregroundPkg
            currentAppStartTimeMs = now
        }

        var appLabel = foregroundPkg
        if (foregroundPkg.isNotBlank()) {
            try {
                val appInfo = packageManager.getApplicationInfo(foregroundPkg, 0)
                appLabel = packageManager.getApplicationLabel(appInfo).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                appLabel = foregroundPkg
            }
        }

        // Calculate foreground time: combination of accumulated today + current session
        val todayAccumulatedMs = packageUsageMap[foregroundPkg] ?: 0L
        val sessionMs = if (lastObservedPackage == foregroundPkg) (now - currentAppStartTimeMs) else 0L
        val effectiveAppMs = Math.max(todayAccumulatedMs, sessionMs)
        val appMinutes = (effectiveAppMs / (1000 * 60)).toInt()

        // 3. Classify app
        val category = ScreenTimePreferences.getAppCategory(this, foregroundPkg, appLabel)

        latestCurrentAppName = appLabel
        latestCurrentAppMinutes = appMinutes
        latestCategory = category

        // 4. Distraction Limit Check
        if (category == "distraction") {
            val limitMinutes = ScreenTimePreferences.getDistractionLimitMinutes(this)
            if (appMinutes >= limitMinutes && limitMinutes > 0) {
                // Throttle alert: only fire once per 30 minutes for the same app
                if (lastDistractionAlertPackage != foregroundPkg || (now - lastDistractionAlertTime) > 30 * 60 * 1000L) {
                    lastDistractionAlertPackage = foregroundPkg
                    lastDistractionAlertTime = now

                    AreteNotificationHelper.showDistractionLimitAlert(
                        context = this,
                        appName = appLabel,
                        spentMinutes = appMinutes,
                        limitMinutes = limitMinutes
                    )

                    // Auto-Shield if configured
                    if (ScreenTimePreferences.isAutoShieldOnLimit(this)) {
                        FocusShieldPreferences.activateShield(
                            context = this,
                            blockedPackages = setOf(foregroundPkg),
                            endTimeMs = now + 25 * 60 * 1000L,
                            strictMode = false,
                            sessionLabel = "Daily Limit Reached: $appLabel",
                            sessionId = "auto_limit_${System.currentTimeMillis()}"
                        )
                    }
                }
            }
        }

        // 5. Update Persistent Status Bar Notification
        AreteNotificationHelper.updateScreenTimeNotification(
            context = this,
            totalScreenTimeMinutes = totalMinutes,
            foregroundAppPackage = foregroundPkg,
            foregroundAppName = appLabel,
            foregroundDurationMinutes = appMinutes,
            category = category
        )
    }

    private fun queryForegroundAppFromEvents(usageStatsManager: UsageStatsManager, now: Long): String {
        try {
            // Query events from last 2 minutes
            val events = usageStatsManager.queryEvents(now - 120000L, now)
            val event = UsageEvents.Event()
            var lastPkg = ""
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                    event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    lastPkg = event.packageName ?: lastPkg
                }
            }
            return lastPkg
        } catch (e: Exception) {
            return ""
        }
    }
}
