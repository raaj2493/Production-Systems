package com.arete.app.arete

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import android.util.Rational
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Calendar

class MainActivity : FlutterActivity() {

    companion object {
        var pipMethodChannel: MethodChannel? = null

        fun sendTimerAction(action: String) {
            pipMethodChannel?.invokeMethod("onOverlayAction", action)
        }
    }

    private val FOCUS_SHIELD_CHANNEL = "com.arete.app/focus_shield"
    private val NOTIFICATIONS_CHANNEL = "com.arete.app/notifications_and_screentime"
    private val PIP_CHANNEL = "com.arete.app/pip"
    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    private var initialAction: String? = null
    private var initialDurationMinutes: Int = 25
    private var isTimerRunning = false
    private var currentRemainingSeconds = 25 * 60
    private var currentTotalSeconds = 25 * 60
    private var currentIsBreak = false
    private var autoEnterOverlayEnabled = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        AreteNotificationHelper.initNotificationChannels(this)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra("action")
        if (action != null) {
            initialAction = action
            initialDurationMinutes = intent.getIntExtra("duration_minutes", 25)
            sendTimerAction(action)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Focus Shield Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_SHIELD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(this))
                }

                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }

                "getInstalledApps" -> {
                    coroutineScope.launch {
                        try {
                            val apps = withContext(Dispatchers.IO) {
                                InstalledAppsHelper.getInstalledLaunchableApps(this@MainActivity)
                            }
                            result.success(apps)
                        } catch (e: Exception) {
                            result.error("APP_QUERY_ERROR", e.localizedMessage, null)
                        }
                    }
                }

                "startShield" -> {
                    val rawPackages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                    val endTimeMs = call.argument<Number>("endTimeMs")?.toLong() ?: 0L
                    val strictMode = call.argument<Boolean>("strictMode") ?: false
                    val sessionLabel = call.argument<String>("sessionLabel") ?: "Deep Focus Session"
                    val sessionId = call.argument<String>("sessionId") ?: ""

                    FocusShieldPreferences.activateShield(
                        context = this,
                        blockedPackages = rawPackages.toSet(),
                        endTimeMs = endTimeMs,
                        strictMode = strictMode,
                        sessionLabel = sessionLabel,
                        sessionId = sessionId
                    )
                    result.success(true)
                }

                "stopShield" -> {
                    FocusShieldPreferences.deactivateShield(this)
                    result.success(true)
                }

                "pauseShield" -> {
                    FocusShieldPreferences.pauseShield(this)
                    result.success(true)
                }

                "resumeShield" -> {
                    val newEndTimeMs = call.argument<Number>("newEndTimeMs")?.toLong() ?: 0L
                    FocusShieldPreferences.resumeShield(this, newEndTimeMs)
                    result.success(true)
                }

                "getShieldStatus" -> {
                    val isServiceEnabled = isAccessibilityServiceEnabled(this)
                    val isActive = FocusShieldPreferences.isShieldActive(this)
                    val interruptionCount = FocusShieldPreferences.getInterruptionCount(this)
                    val endTimeMs = FocusShieldPreferences.getEndTimeMs(this)
                    val isStrict = FocusShieldPreferences.isStrictMode(this)
                    val sessionLabel = FocusShieldPreferences.getSessionLabel(this)
                    val blockedList = FocusShieldPreferences.getBlockedPackages(this).toList()

                    result.success(
                        mapOf(
                            "isActive" to isActive,
                            "isServiceEnabled" to isServiceEnabled,
                            "isStrictMode" to isStrict,
                            "interruptionCount" to interruptionCount,
                            "endTimeMs" to endTimeMs,
                            "sessionLabel" to sessionLabel,
                            "blockedPackages" to blockedList
                        )
                    )
                }

                "resetInterruptionCount" -> {
                    val count = FocusShieldPreferences.getInterruptionCount(this)
                    FocusShieldPreferences.activateShield(
                        context = this,
                        blockedPackages = FocusShieldPreferences.getBlockedPackages(this),
                        endTimeMs = FocusShieldPreferences.getEndTimeMs(this),
                        strictMode = FocusShieldPreferences.isStrictMode(this),
                        sessionLabel = FocusShieldPreferences.getSessionLabel(this),
                        sessionId = FocusShieldPreferences.getSessionId(this)
                    )
                    result.success(count)
                }

                "playAmbientSound" -> {
                    val type = call.argument<String>("type") ?: "rain"
                    val volume = call.argument<Number>("volume")?.toFloat() ?: 0.6f
                    AmbientSoundscapePlayer.play(type, volume)
                    result.success(true)
                }

                "stopAmbientSound" -> {
                    AmbientSoundscapePlayer.stop()
                    result.success(true)
                }

                "setAmbientVolume" -> {
                    val volume = call.argument<Number>("volume")?.toFloat() ?: 0.6f
                    AmbientSoundscapePlayer.setVolume(volume)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // 2. Notifications & Screen Time Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isUsageStatsPermissionGranted" -> {
                    result.success(isUsageStatsPermissionGranted(this))
                }

                "openUsageStatsSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }

                "isNotificationPermissionGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        val manager = NotificationManagerCompat.from(this)
                        result.success(manager.areNotificationsEnabled())
                    }
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                    }
                    result.success(true)
                }

                "startScreenTimeMonitoring" -> {
                    ScreenTimePreferences.setMonitoringEnabled(this, true)
                    ScreenTimeMonitoringService.start(this)
                    result.success(true)
                }

                "stopScreenTimeMonitoring" -> {
                    ScreenTimePreferences.setMonitoringEnabled(this, false)
                    ScreenTimeMonitoringService.stop(this)
                    result.success(true)
                }

                "getScreenTimeStatus" -> {
                    val isMonitoring = ScreenTimeMonitoringService.isServiceRunning || ScreenTimePreferences.isMonitoringEnabled(this)
                    val hasUsage = isUsageStatsPermissionGranted(this)
                    result.success(
                        mapOf(
                            "totalScreenTimeMinutes" to ScreenTimeMonitoringService.latestTotalScreenTimeMinutes,
                            "currentPackage" to ScreenTimeMonitoringService.currentForegroundPackage,
                            "currentAppName" to ScreenTimeMonitoringService.latestCurrentAppName,
                            "currentAppMinutes" to ScreenTimeMonitoringService.latestCurrentAppMinutes,
                            "category" to ScreenTimeMonitoringService.latestCategory,
                            "isMonitoring" to isMonitoring,
                            "hasUsagePermission" to hasUsage
                        )
                    )
                }

                "updateAppCategories" -> {
                    val map = call.argument<Map<String, String>>("categories") ?: emptyMap()
                    ScreenTimePreferences.saveAppCategories(this, map)
                    result.success(true)
                }

                "getAppCategories" -> {
                    result.success(ScreenTimePreferences.getAppCategories(this))
                }

                "setDistractionPreferences" -> {
                    val limit = call.argument<Int>("limitMinutes") ?: 30
                    val autoShield = call.argument<Boolean>("autoShield") ?: true
                    ScreenTimePreferences.setDistractionLimitMinutes(this, limit)
                    ScreenTimePreferences.setAutoShieldOnLimit(this, autoShield)
                    result.success(true)
                }

                "setNotificationPreferences" -> {
                    val habitEnabled = call.argument<Boolean>("habitReminders") ?: true
                    val taskEnabled = call.argument<Boolean>("taskAlerts") ?: true
                    val morning = call.argument<String>("morningTime") ?: "08:30"
                    val evening = call.argument<String>("eveningTime") ?: "20:00"

                    ScreenTimePreferences.setHabitRemindersEnabled(this, habitEnabled)
                    ScreenTimePreferences.setTaskAlertsEnabled(this, taskEnabled)
                    ScreenTimePreferences.setMorningReminderTime(this, morning)
                    ScreenTimePreferences.setEveningReminderTime(this, evening)
                    result.success(true)
                }

                "scheduleHabitReminder" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val duration = call.argument<Int>("duration") ?: 15
                    val hour = call.argument<Int>("hour") ?: 8
                    val minute = call.argument<Int>("minute") ?: 30
                    scheduleHabitAlarm(this, id, title, duration, hour, minute)
                    result.success(true)
                }

                "cancelHabitReminder" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelHabitAlarm(this, id)
                    result.success(true)
                }

                "scheduleTaskAlert" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val dueTimestampMs = call.argument<Number>("dueTimestampMs")?.toLong() ?: 0L
                    scheduleTaskAlarms(this, id, title, dueTimestampMs)
                    result.success(true)
                }

                "cancelTaskAlert" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelTaskAlarms(this, id)
                    result.success(true)
                }

                "scheduleFlexibleReminder" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val description = call.argument<String>("description")
                    val targetType = call.argument<String>("targetType") ?: "standalone"
                    val targetId = call.argument<String>("targetId")
                    val triggerType = call.argument<String>("triggerType") ?: "fixed_time"
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 60
                    val windowStartHour = call.argument<Int>("windowStartHour") ?: 9
                    val windowStartMinute = call.argument<Int>("windowStartMinute") ?: 0
                    val windowEndHour = call.argument<Int>("windowEndHour") ?: 21
                    val windowEndMinute = call.argument<Int>("windowEndMinute") ?: 0
                    val fixedHour = call.argument<Int>("fixedHour") ?: 10
                    val fixedMinute = call.argument<Int>("fixedMinute") ?: 0
                    val daysOfWeek = call.argument<String>("daysOfWeek") ?: "1,2,3,4,5,6,7"
                    val priority = call.argument<String>("priority") ?: "medium"
                    val isSticky = call.argument<Boolean>("isSticky") ?: false
                    val soundMode = call.argument<String>("soundMode") ?: "gentle_chime"
                    val isEnabled = call.argument<Boolean>("isEnabled") ?: true

                    if (!isEnabled) {
                        cancelFlexibleReminderAlarm(this, id)
                    } else {
                        scheduleFlexibleReminderAlarm(
                            context = this,
                            id = id,
                            title = title,
                            description = description,
                            targetType = targetType,
                            targetId = targetId,
                            triggerType = triggerType,
                            intervalMinutes = intervalMinutes,
                            windowStartHour = windowStartHour,
                            windowStartMinute = windowStartMinute,
                            windowEndHour = windowEndHour,
                            windowEndMinute = windowEndMinute,
                            fixedHour = fixedHour,
                            fixedMinute = fixedMinute,
                            daysOfWeek = daysOfWeek,
                            priority = priority,
                            isSticky = isSticky,
                            soundMode = soundMode
                        )
                    }
                    result.success(true)
                }

                "cancelFlexibleReminder" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelFlexibleReminderAlarm(this, id)
                    result.success(true)
                }

                "showFlexibleReminderNow" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val description = call.argument<String>("description")
                    val targetType = call.argument<String>("targetType") ?: "standalone"
                    val targetId = call.argument<String>("targetId")
                    val priority = call.argument<String>("priority") ?: "medium"
                    val isSticky = call.argument<Boolean>("isSticky") ?: false
                    val soundMode = call.argument<String>("soundMode") ?: "gentle_chime"
                    val intervalMinutes = call.argument<Int>("intervalMinutes")
                    val triggerType = call.argument<String>("triggerType")

                    AreteNotificationHelper.showFlexibleReminderNotification(
                        context = this,
                        reminderId = id,
                        title = title,
                        description = description,
                        targetType = targetType,
                        targetId = targetId,
                        priority = priority,
                        isSticky = isSticky,
                        soundMode = soundMode,
                        intervalMinutes = intervalMinutes,
                        triggerType = triggerType
                    )
                    result.success(true)
                }

                "popPendingActions" -> {
                    val actions = ScreenTimePreferences.popPendingActions(this)
                    result.success(actions)
                }

                "getInitialAction" -> {
                    if (initialAction != null) {
                        val map = mapOf(
                            "action" to initialAction,
                            "durationMinutes" to initialDurationMinutes
                        )
                        initialAction = null
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                }

                "openNotificationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.localizedMessage, null)
                    }
                }

                "showFocusTimerNotification" -> {
                    val remainingSeconds = call.argument<Int>("remainingSeconds") ?: 0
                    val totalSeconds = call.argument<Int>("totalSeconds") ?: 0
                    val isRunning = call.argument<Boolean>("isRunning") ?: true
                    val sessionType = call.argument<String>("sessionType") ?: "focus"
                    val sessionLabel = call.argument<String>("sessionLabel")

                    currentRemainingSeconds = remainingSeconds
                    if (totalSeconds > 0) currentTotalSeconds = totalSeconds
                    isTimerRunning = isRunning
                    currentIsBreak = sessionType.lowercase() != "focus"

                    if (FloatingTimerOverlayService.isOverlayShowing) {
                        FloatingTimerOverlayService.update(
                            context = this,
                            remainingSeconds = remainingSeconds,
                            totalSeconds = currentTotalSeconds,
                            isRunning = isRunning,
                            isBreak = currentIsBreak
                        )
                    }

                    AreteNotificationHelper.showFocusTimerNotification(
                        context = this,
                        remainingSeconds = remainingSeconds,
                        totalSeconds = totalSeconds,
                        isRunning = isRunning,
                        sessionType = sessionType,
                        sessionLabel = sessionLabel
                    )
                    result.success(true)
                }

                "cancelFocusTimerNotification" -> {
                    isTimerRunning = false
                    FloatingTimerOverlayService.hide(this)
                    AreteNotificationHelper.cancelFocusTimerNotification(this)
                    result.success(true)
                }

                "showFocusCompletionNotification" -> {
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 25
                    val sessionType = call.argument<String>("sessionType") ?: "focus"
                    isTimerRunning = false
                    FloatingTimerOverlayService.hide(this)
                    AreteNotificationHelper.showFocusCompletionNotification(this, durationMinutes, sessionType)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // 3. Native System Overlay (WindowManager) Channel
        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported", "isOverlaySupported" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                        result.success(supported)
                    }

                    "hasOverlayPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this@MainActivity)
                        } else true
                        result.success(granted)
                    }

                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("PERMISSION_ERROR", e.localizedMessage, null)
                            }
                        } else {
                            result.success(true)
                        }
                    }

                    "isPipMode", "isOverlayShowing" -> {
                        result.success(FloatingTimerOverlayService.isOverlayShowing)
                    }

                    "enterPip", "showOverlay" -> {
                        val remaining = call.argument<Int>("remainingSeconds") ?: currentRemainingSeconds
                        val total = call.argument<Int>("totalSeconds") ?: currentTotalSeconds
                        val running = call.argument<Boolean>("isRunning") ?: isTimerRunning
                        val breakSession = call.argument<Boolean>("isBreak") ?: currentIsBreak
                        currentRemainingSeconds = remaining
                        if (total > 0) currentTotalSeconds = total
                        isTimerRunning = running
                        currentIsBreak = breakSession
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this@MainActivity)) {
                            FloatingTimerOverlayService.show(this@MainActivity, remaining, currentTotalSeconds, running, breakSession)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }

                    "setAutoEnterEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        autoEnterOverlayEnabled = enabled
                        if (!enabled) {
                            FloatingTimerOverlayService.hide(this@MainActivity)
                        }
                        result.success(true)
                    }

                    "exitPip", "hideOverlay" -> {
                        FloatingTimerOverlayService.hide(this@MainActivity)
                        result.success(true)
                    }

                    "updateOverlay" -> {
                        val remaining = call.argument<Int>("remainingSeconds") ?: currentRemainingSeconds
                        val total = call.argument<Int>("totalSeconds") ?: currentTotalSeconds
                        val running = call.argument<Boolean>("isRunning") ?: isTimerRunning
                        val breakSession = call.argument<Boolean>("isBreak") ?: currentIsBreak
                        currentRemainingSeconds = remaining
                        if (total > 0) currentTotalSeconds = total
                        isTimerRunning = running
                        currentIsBreak = breakSession
                        FloatingTimerOverlayService.update(this@MainActivity, remaining, currentTotalSeconds, running, breakSession)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        FloatingTimerOverlayService.hide(this)
        AmbientSoundscapePlayer.stop()
        super.onDestroy()
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedComponentName = ComponentName(context, FocusShieldAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)

        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledComponent = ComponentName.unflattenFromString(componentNameString)
            if (enabledComponent != null && enabledComponent == expectedComponentName) {
                return true
            }
        }
        return false
    }

    private fun isUsageStatsPermissionGranted(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun scheduleHabitAlarm(context: Context, id: String, title: String, duration: Int, hour: Int, minute: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, AreteAlarmReceiver::class.java).apply {
            action = AreteAlarmReceiver.ACTION_ALARM_HABIT
            putExtra(AreteNotificationHelper.EXTRA_ITEM_ID, id)
            putExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE, title)
            putExtra(AreteNotificationHelper.EXTRA_DURATION_MINS, duration)
        }
        val reqCode = (id.hashCode() and 0x7FFFFFFF) % 100000 + 1000
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(context, reqCode, intent, flags)

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }

    private fun cancelHabitAlarm(context: Context, id: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, AreteAlarmReceiver::class.java).apply {
            action = AreteAlarmReceiver.ACTION_ALARM_HABIT
        }
        val reqCode = (id.hashCode() and 0x7FFFFFFF) % 100000 + 1000
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(context, reqCode, intent, flags)
        alarmManager.cancel(pendingIntent)
    }

    private fun scheduleTaskAlarms(context: Context, id: String, title: String, dueTimestampMs: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val now = System.currentTimeMillis()
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // 1. Exact due time
        if (dueTimestampMs > now) {
            val exactIntent = Intent(context, AreteAlarmReceiver::class.java).apply {
                action = AreteAlarmReceiver.ACTION_ALARM_TASK_DUE
                putExtra(AreteNotificationHelper.EXTRA_ITEM_ID, id)
                putExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE, title)
                putExtra(AreteNotificationHelper.EXTRA_IS_FIFTEEN_MIN, false)
            }
            val exactReqCode = (id.hashCode() and 0x7FFFFFFF) % 100000 + 2000
            val exactPending = PendingIntent.getBroadcast(context, exactReqCode, exactIntent, flags)
            scheduleAlarmSafe(alarmManager, dueTimestampMs, exactPending)
        }

        // 2. 15-minute warning alert
        val fifteenMinBefore = dueTimestampMs - (15 * 60 * 1000L)
        if (fifteenMinBefore > now) {
            val warningIntent = Intent(context, AreteAlarmReceiver::class.java).apply {
                action = AreteAlarmReceiver.ACTION_ALARM_TASK_DUE
                putExtra(AreteNotificationHelper.EXTRA_ITEM_ID, id)
                putExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE, title)
                putExtra(AreteNotificationHelper.EXTRA_IS_FIFTEEN_MIN, true)
            }
            val warningReqCode = (id.hashCode() and 0x7FFFFFFF) % 100000 + 3000
            val warningPending = PendingIntent.getBroadcast(context, warningReqCode, warningIntent, flags)
            scheduleAlarmSafe(alarmManager, fifteenMinBefore, warningPending)
        }
    }

    private fun cancelTaskAlarms(context: Context, id: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val exactIntent = Intent(context, AreteAlarmReceiver::class.java).apply {
            action = AreteAlarmReceiver.ACTION_ALARM_TASK_DUE
        }
        val exactReqCode = (id.hashCode() and 0x7FFFFFFF) % 100000 + 2000
        val exactPending = PendingIntent.getBroadcast(context, exactReqCode, exactIntent, flags)
        alarmManager.cancel(exactPending)

        val warningIntent = Intent(context, AreteAlarmReceiver::class.java).apply {
            action = AreteAlarmReceiver.ACTION_ALARM_TASK_DUE
        }
        val warningReqCode = (id.hashCode() and 0x7FFFFFFF) % 100000 + 3000
        val warningPending = PendingIntent.getBroadcast(context, warningReqCode, warningIntent, flags)
        alarmManager.cancel(warningPending)
    }

    private fun scheduleFlexibleReminderAlarm(
        context: Context,
        id: String,
        title: String,
        description: String?,
        targetType: String,
        targetId: String?,
        triggerType: String,
        intervalMinutes: Int,
        windowStartHour: Int,
        windowStartMinute: Int,
        windowEndHour: Int,
        windowEndMinute: Int,
        fixedHour: Int,
        fixedMinute: Int,
        daysOfWeek: String?,
        priority: String,
        isSticky: Boolean,
        soundMode: String
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, AreteAlarmReceiver::class.java).apply {
            action = AreteAlarmReceiver.ACTION_ALARM_FLEXIBLE_REMINDER
            putExtra(AreteNotificationHelper.EXTRA_REMINDER_ID, id)
            putExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE, title)
            putExtra("extra_description", description)
            putExtra(AreteNotificationHelper.EXTRA_TARGET_TYPE, targetType)
            putExtra(AreteNotificationHelper.EXTRA_TARGET_ID, targetId)
            putExtra(AreteNotificationHelper.EXTRA_TRIGGER_TYPE, triggerType)
            putExtra(AreteNotificationHelper.EXTRA_INTERVAL_MINS, intervalMinutes)
            putExtra(AreteAlarmReceiver.EXTRA_WINDOW_START_HOUR, windowStartHour)
            putExtra(AreteAlarmReceiver.EXTRA_WINDOW_START_MINUTE, windowStartMinute)
            putExtra(AreteAlarmReceiver.EXTRA_WINDOW_END_HOUR, windowEndHour)
            putExtra(AreteAlarmReceiver.EXTRA_WINDOW_END_MINUTE, windowEndMinute)
            putExtra(AreteAlarmReceiver.EXTRA_FIXED_HOUR, fixedHour)
            putExtra(AreteAlarmReceiver.EXTRA_FIXED_MINUTE, fixedMinute)
            putExtra(AreteAlarmReceiver.EXTRA_DAYS_OF_WEEK, daysOfWeek)
            putExtra(AreteNotificationHelper.EXTRA_PRIORITY, priority)
            putExtra(AreteNotificationHelper.EXTRA_IS_STICKY, isSticky)
            putExtra(AreteNotificationHelper.EXTRA_SOUND_MODE, soundMode)
        }

        val reqCode = (id.hashCode() and 0x7FFFFFFF) % 100000 + 4000
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(context, reqCode, intent, flags)

        val triggerAtMs = if (triggerType == "interval") {
            val nowCal = Calendar.getInstance()
            val currentMinutes = nowCal.get(Calendar.HOUR_OF_DAY) * 60 + nowCal.get(Calendar.MINUTE)
            val startMinutes = windowStartHour * 60 + windowStartMinute
            val endMinutes = windowEndHour * 60 + windowEndMinute

            val inWindow = if (startMinutes <= endMinutes) {
                currentMinutes in startMinutes..endMinutes
            } else {
                currentMinutes >= startMinutes || currentMinutes <= endMinutes
            }

            if (inWindow) {
                System.currentTimeMillis() + (intervalMinutes * 60 * 1000L)
            } else {
                Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, windowStartHour)
                    set(Calendar.MINUTE, windowStartMinute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                    if (timeInMillis <= System.currentTimeMillis()) {
                        add(Calendar.DAY_OF_YEAR, 1)
                    }
                }.timeInMillis
            }
        } else {
            val daysList = if (!daysOfWeek.isNullOrBlank()) {
                daysOfWeek.split(",").mapNotNull { it.trim().toIntOrNull() }
            } else {
                listOf(1, 2, 3, 4, 5, 6, 7)
            }
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, fixedHour)
                set(Calendar.MINUTE, fixedMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }
            for (i in 0..7) {
                val dow = cal.get(Calendar.DAY_OF_WEEK)
                val iso = if (dow == Calendar.SUNDAY) 7 else dow - 1
                if (daysList.contains(iso)) break
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            cal.timeInMillis
        }

        scheduleAlarmSafe(alarmManager, triggerAtMs, pendingIntent)
    }

    private fun cancelFlexibleReminderAlarm(context: Context, id: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, AreteAlarmReceiver::class.java).apply {
            action = AreteAlarmReceiver.ACTION_ALARM_FLEXIBLE_REMINDER
        }
        val reqCode = (id.hashCode() and 0x7FFFFFFF) % 100000 + 4000
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(context, reqCode, intent, flags)
        alarmManager.cancel(pendingIntent)
        AreteNotificationHelper.cancelNotification(context, reqCode)
    }

    private fun scheduleAlarmSafe(alarmManager: AlarmManager, triggerAtMs: Long, pendingIntent: PendingIntent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            }
        } catch (e: SecurityException) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                }
            } catch (ignored: Exception) {}
        }
    }

    override fun onResume() {
        super.onResume()
        // Overlay is never shown while user is actively inside Areté
        FloatingTimerOverlayService.hide(this)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Automatically spawn native floating overlay micro circular bubble when user minimizes app during an active focus session
        if (autoEnterOverlayEnabled && isTimerRunning) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                FloatingTimerOverlayService.show(
                    context = this,
                    remainingSeconds = currentRemainingSeconds,
                    totalSeconds = currentTotalSeconds,
                    isRunning = true,
                    isBreak = currentIsBreak
                )
            }
        }
    }
}
