package com.arete.app.arete

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log

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

        // Start foreground immediately with type for Android 14+ (UPSIDE_DOWN_CAKE)
        val initialNotification = AreteNotificationHelper.buildScreenTimeNotification(
            context = this,
            totalScreenTimeMinutes = latestTotalScreenTimeMinutes,
            foregroundAppPackage = currentForegroundPackage,
            foregroundAppName = if (latestCurrentAppName.isNotBlank()) latestCurrentAppName else "Areté Tracker",
            foregroundDurationMinutes = latestCurrentAppMinutes,
            category = latestCategory
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    AreteNotificationHelper.NOTIFICATION_ID_SCREEN_TIME,
                    initialNotification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(AreteNotificationHelper.NOTIFICATION_ID_SCREEN_TIME, initialNotification)
            }
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
        val stats = ScreenTimeHelper.getTodayUsageStats(this)
        if (stats.isEmpty()) return

        val totalMinutes = (stats["totalScreenTimeMinutes"] as? Int) ?: 0
        var foregroundPkg = currentForegroundPackage
        if (foregroundPkg.isBlank()) {
            foregroundPkg = (stats["currentPackage"] as? String) ?: ""
        }
        currentForegroundPackage = foregroundPkg

        val appLabel = (stats["currentAppName"] as? String)?.ifEmpty { foregroundPkg } ?: foregroundPkg
        val appMinutes = (stats["currentAppMinutes"] as? Int) ?: 0
        val category = (stats["category"] as? String) ?: "neutral"

        latestTotalScreenTimeMinutes = totalMinutes
        latestCurrentAppName = appLabel
        latestCurrentAppMinutes = appMinutes
        latestCategory = category

        // Distraction Limit Check
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

        // Update Persistent Status Bar Notification
        AreteNotificationHelper.updateScreenTimeNotification(
            context = this,
            totalScreenTimeMinutes = totalMinutes,
            foregroundAppPackage = foregroundPkg,
            foregroundAppName = appLabel,
            foregroundDurationMinutes = appMinutes,
            category = category
        )
    }
}
