package com.arete.app.arete

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import java.util.Locale
import java.util.concurrent.TimeUnit

class FocusShieldAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "FocusShieldService"
        var isServiceConnected: Boolean = false
            private set
        var instance: FocusShieldAccessibilityService? = null
            private set

        // Critical system packages that must never be blocked
        private val SYSTEM_WHITELIST = setOf(
            "com.arete.app.arete",
            "com.android.systemui",
            "com.android.settings",
            "android",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller",
            "com.google.android.permissioncontroller",
            "com.android.permissioncontroller",
            "com.google.android.dialer",
            "com.android.dialer",
            "com.samsung.android.dialer",
            "com.google.android.inputmethod.latin",
            "com.android.inputmethod.latin",
            "com.samsung.android.honeyboard",
            "com.touchtype.swiftkey",
            "com.miui.securityadd",
            "com.miui.securitycenter",
            "com.miui.guardprovider",
            "com.miui.powerkeeper",
            "com.miui.cleanmaster",
            "com.lbe.security.miui"
        )
    }

    private val cachedLaunchers = mutableSetOf<String>()
    private var lastLauncherRefreshTime = 0L

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false
    private var currentBlockedPackage: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var countdownRunnable: Runnable? = null
    private var emergencyExitPending = false

    override fun onServiceConnected() {
        try {
            super.onServiceConnected()
            instance = this
            isServiceConnected = true

            // Programmatically ensure valid service info so Android OS never flags malfunction
            val info = serviceInfo ?: AccessibilityServiceInfo()
            info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            info.notificationTimeout = 100L
            serviceInfo = info

            windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            refreshLauncherPackages()
            Log.i(TAG, "Areté Focus Shield Accessibility Service connected successfully.")
        } catch (t: Throwable) {
            Log.e(TAG, "Safe catch in onServiceConnected: ${t.message}", t)
        }
    }

    override fun onDestroy() {
        try {
            hideAccessibilityOverlay()
            if (instance == this) {
                instance = null
            }
            isServiceConnected = false
            super.onDestroy()
            Log.i(TAG, "Areté Focus Shield Accessibility Service destroyed.")
        } catch (t: Throwable) {
            Log.e(TAG, "Safe catch in onDestroy: ${t.message}", t)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            handleAccessibilityEvent(event)
        } catch (t: Throwable) {
            Log.e(TAG, "Safe catch in onAccessibilityEvent: ${t.message}", t)
        }
    }

    private fun handleAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            return
        }

        // 1. Identify foreground package directly from event without allocating nodes
        var foregroundPackage = event.packageName?.toString()

        // 2. If event packageName is null, safely inspect rootInActiveWindow and RECYCLE immediately
        if (foregroundPackage.isNullOrBlank()) {
            var node: AccessibilityNodeInfo? = null
            try {
                node = rootInActiveWindow
                foregroundPackage = node?.packageName?.toString()
            } catch (_: Throwable) {
                // Ignore node query errors
            } finally {
                node?.recycle()
            }
        }

        if (foregroundPackage.isNullOrBlank()) return

        // Update active package for Screen Time Monitoring
        ScreenTimeMonitoringService.currentForegroundPackage = foregroundPackage

        // 3. Areté itself (including our own overlay & activities) -> NEVER dismiss overlay, simply return
        if (foregroundPackage == "com.arete.app.arete") {
            return
        }

        // 4. Critical system packages (status bar, keyboard, system dialogs, MIUI security services)
        // -> Never dismiss overlay or expose blocked app behind
        if (SYSTEM_WHITELIST.contains(foregroundPackage)) {
            return
        }

        // 5. Home launchers -> user exited/swiped to home screen -> dismiss overlay
        if (isHomeLauncher(foregroundPackage)) {
            hideAccessibilityOverlay()
            return
        }

        // 6. Check if Focus Shield is active (only during an active focus session)
        val isShieldActive = FocusShieldPreferences.isShieldActive(this)
        if (!isShieldActive) {
            hideAccessibilityOverlay()
            return
        }

        // 7. Check if foreground package is on user's blocked list
        val blockedPackages = FocusShieldPreferences.getBlockedPackages(this)
        if (blockedPackages.contains(foregroundPackage)) {
            // Already firmly showing the overlay covering this exact blocked package -> stay solid
            if (isOverlayShowing && currentBlockedPackage == foregroundPackage) {
                return
            }

            // Debounce repeated burst events within 350ms
            if (FocusShieldPreferences.shouldThrottleInterruption(this, foregroundPackage)) {
                return
            }

            // Record distraction count
            FocusShieldPreferences.incrementInterruptionCount(this)
            Log.w(TAG, "Focus Shield active: blocking $foregroundPackage")

            // Show rock-solid full screen overlay
            showAccessibilityOverlay(foregroundPackage)
            return
        }

        // 8. Normal allowed / unblocked app is opened -> dismiss overlay
        hideAccessibilityOverlay()
    }

    private fun showAccessibilityOverlay(packageName: String) {
        mainHandler.post {
            try {
                if (windowManager == null) {
                    windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
                }

                if (isOverlayShowing && overlayView != null) {
                    if (currentBlockedPackage != packageName) {
                        currentBlockedPackage = packageName
                        updateOverlayViews(overlayView!!, packageName)
                    }
                    return@post
                }

                currentBlockedPackage = packageName
                val themedContext = ContextThemeWrapper(this, R.style.InterruptionTheme)
                val inflater = LayoutInflater.from(themedContext)
                val view = inflater.inflate(R.layout.activity_focus_shield_interruption, null)
                overlayView = view

                val layoutParams = WindowManager.LayoutParams().apply {
                    width = WindowManager.LayoutParams.MATCH_PARENT
                    height = WindowManager.LayoutParams.MATCH_PARENT
                    type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                    flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                            WindowManager.LayoutParams.FLAG_FULLSCREEN or
                            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
                    format = PixelFormat.TRANSLUCENT
                    gravity = Gravity.CENTER
                }

                setupOverlayViews(view, packageName)
                windowManager?.addView(view, layoutParams)
                isOverlayShowing = true
                Log.i(TAG, "Accessibility overlay rendered successfully for $packageName")
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to render accessibility overlay: ${t.message}", t)
                isOverlayShowing = false
                currentBlockedPackage = null
                performGlobalAction(GLOBAL_ACTION_HOME)
                launchInterruptionScreen(packageName)
            }
        }
    }

    private fun hideAccessibilityOverlay() {
        mainHandler.post {
            try {
                countdownRunnable?.let { mainHandler.removeCallbacks(it) }
                if (isOverlayShowing && overlayView != null) {
                    windowManager?.removeView(overlayView)
                    Log.i(TAG, "Accessibility overlay dismissed")
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Error removing accessibility overlay: ${t.message}")
            } finally {
                overlayView = null
                isOverlayShowing = false
                currentBlockedPackage = null
                emergencyExitPending = false
            }
        }
    }

    private fun setupOverlayViews(view: View, packageName: String) {
        val ivAppIcon = view.findViewById<ImageView>(R.id.ivBlockedAppIcon)
        val tvAppName = view.findViewById<TextView>(R.id.tvBlockedAppName)
        val tvTimerCountdown = view.findViewById<TextView>(R.id.tvTimerCountdown)
        val btnReturn = view.findViewById<Button>(R.id.btnReturnToArete)
        val tvEmergency = view.findViewById<TextView>(R.id.tvEmergencyExit)
        val llQuickPass = view.findViewById<View>(R.id.llQuickPassContainer)

        llQuickPass?.visibility = View.GONE
        btnReturn?.text = "Breathe & Return to Areté"

        var appLabel = packageName
        try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            appLabel = packageManager.getApplicationLabel(appInfo).toString()
            val appIcon = packageManager.getApplicationIcon(appInfo)
            ivAppIcon?.setImageDrawable(appIcon)
            ivAppIcon?.visibility = View.VISIBLE
        } catch (_: Throwable) {
            ivAppIcon?.visibility = View.GONE
        }

        tvAppName?.text = "$appLabel is Blocked"

        btnReturn?.setOnClickListener {
            hideAccessibilityOverlay()
            performGlobalAction(GLOBAL_ACTION_HOME)
            try {
                val launchIntent = packageManager.getLaunchIntentForPackage("com.arete.app.arete")
                if (launchIntent != null) {
                    launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    startActivity(launchIntent)
                }
            } catch (_: Throwable) {}
        }

        emergencyExitPending = false
        tvEmergency?.setOnClickListener {
            val isStrict = FocusShieldPreferences.isStrictMode(this)
            if (isStrict && !emergencyExitPending) {
                emergencyExitPending = true
                tvEmergency.text = "Strict Mode: Tap once more to break session"
                mainHandler.postDelayed({
                    emergencyExitPending = false
                    tvEmergency.text = "Emergency Exit"
                }, 5000L)
            } else {
                FocusShieldPreferences.pauseShield(this)
                hideAccessibilityOverlay()
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }

        if (tvTimerCountdown != null) {
            startOverlayCountdown(tvTimerCountdown)
        }
    }

    private fun updateOverlayViews(view: View, packageName: String) {
        val ivAppIcon = view.findViewById<ImageView>(R.id.ivBlockedAppIcon)
        val tvAppName = view.findViewById<TextView>(R.id.tvBlockedAppName)
        val tvTimerCountdown = view.findViewById<TextView>(R.id.tvTimerCountdown)

        var appLabel = packageName
        try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            appLabel = packageManager.getApplicationLabel(appInfo).toString()
            val appIcon = packageManager.getApplicationIcon(appInfo)
            ivAppIcon?.setImageDrawable(appIcon)
            ivAppIcon?.visibility = View.VISIBLE
        } catch (_: Throwable) {
            ivAppIcon?.visibility = View.GONE
        }

        tvAppName?.text = "$appLabel is Blocked"
        if (tvTimerCountdown != null) {
            startOverlayCountdown(tvTimerCountdown)
        }
    }

    private fun startOverlayCountdown(tvCountdown: TextView) {
        countdownRunnable?.let { mainHandler.removeCallbacks(it) }
        countdownRunnable = object : Runnable {
            override fun run() {
                val endTimeMs = FocusShieldPreferences.getEndTimeMs(this@FocusShieldAccessibilityService)
                if (endTimeMs <= 0L) {
                    tvCountdown.text = "Focus Shield Active"
                    return
                }

                val now = System.currentTimeMillis()
                val remainingMs = endTimeMs - now

                if (remainingMs <= 0) {
                    tvCountdown.text = "Session Complete"
                    hideAccessibilityOverlay()
                    return
                }

                val minutes = TimeUnit.MILLISECONDS.toMinutes(remainingMs)
                val seconds = TimeUnit.MILLISECONDS.toSeconds(remainingMs) % 60
                tvCountdown.text = String.format(Locale.getDefault(), "Focus remaining: %02d:%02d", minutes, seconds)
                mainHandler.postDelayed(this, 1000)
            }
        }
        mainHandler.post(countdownRunnable!!)
    }

    private fun launchInterruptionScreen(foregroundPackage: String) {
        val intent = Intent(this, FocusShieldInterruptionActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra(FocusShieldInterruptionActivity.EXTRA_PACKAGE_NAME, foregroundPackage)
            putExtra(FocusShieldInterruptionActivity.EXTRA_SESSION_LABEL, FocusShieldPreferences.getSessionLabel(this@FocusShieldAccessibilityService))
            putExtra(FocusShieldInterruptionActivity.EXTRA_END_TIME_MS, FocusShieldPreferences.getEndTimeMs(this@FocusShieldAccessibilityService))
            putExtra(FocusShieldInterruptionActivity.EXTRA_STRICT_MODE, FocusShieldPreferences.isStrictMode(this@FocusShieldAccessibilityService))
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34+
                val options = ActivityOptions.makeBasic()
                try {
                    val method = ActivityOptions::class.java.getMethod(
                        "setPendingIntentBackgroundActivityStartMode",
                        Int::class.javaPrimitiveType
                    )
                    method.invoke(options, 1) // MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                } catch (_: Throwable) {}

                val pendingIntent = PendingIntent.getActivity(
                    this,
                    (System.currentTimeMillis() % 10000).toInt(),
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    options.toBundle()
                )
                pendingIntent.send()
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { // Android 10 to 13 (API 29-33)
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                val pendingIntent = PendingIntent.getActivity(
                    this,
                    (System.currentTimeMillis() % 10000).toInt(),
                    intent,
                    flags
                )
                try {
                    pendingIntent.send()
                } catch (_: Throwable) {
                    startActivity(intent)
                }
            } else { // Android 9 (API 28) and below
                startActivity(intent)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to launch InterruptionActivity: ${t.message}", t)
        }
    }

    override fun onInterrupt() {
        Log.i(TAG, "Areté Focus Shield interrupted.")
    }

    private fun isHomeLauncher(packageName: String): Boolean {
        val now = System.currentTimeMillis()
        if (cachedLaunchers.isEmpty() || (now - lastLauncherRefreshTime) > 60000L) {
            refreshLauncherPackages()
            lastLauncherRefreshTime = now
        }
        return cachedLaunchers.contains(packageName)
    }

    private fun refreshLauncherPackages() {
        try {
            cachedLaunchers.clear()
            // Known default & OEM launcher packages
            cachedLaunchers.addAll(listOf(
                "com.google.android.apps.nexuslauncher",
                "com.android.launcher3",
                "com.sec.android.app.launcher",
                "com.miui.home",
                "com.mi.android.globallauncher",
                "com.huawei.android.launcher",
                "com.oppo.launcher",
                "com.coloros.launcher",
                "com.oneplus.launcher",
                "com.vivo.launcher",
                "com.bbk.launcher2",
                "com.transsion.hilauncher",
                "com.teslacoilsw.launcher",
                "bitpit.launcher",
                "ch.deletescape.lawnchair.plah"
            ))

            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(intent, 0)
            }

            for (info in resolveInfos) {
                info.activityInfo?.packageName?.let { cachedLaunchers.add(it) }
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Error refreshing launcher packages: ${t.message}")
        }
    }
}
