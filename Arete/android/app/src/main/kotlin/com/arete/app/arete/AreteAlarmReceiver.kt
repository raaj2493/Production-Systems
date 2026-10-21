package com.arete.app.arete

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AreteAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AreteAlarmReceiver"
        const val ACTION_ALARM_HABIT = "com.arete.app.ALARM_HABIT"
        const val ACTION_ALARM_TASK_DUE = "com.arete.app.ALARM_TASK_DUE"
        const val ACTION_ALARM_FLEXIBLE_REMINDER = "com.arete.app.ALARM_FLEXIBLE_REMINDER"

        const val EXTRA_WINDOW_START_HOUR = "extra_window_start_hour"
        const val EXTRA_WINDOW_START_MINUTE = "extra_window_start_minute"
        const val EXTRA_WINDOW_END_HOUR = "extra_window_end_hour"
        const val EXTRA_WINDOW_END_MINUTE = "extra_window_end_minute"
        const val EXTRA_FIXED_HOUR = "extra_fixed_hour"
        const val EXTRA_FIXED_MINUTE = "extra_fixed_minute"
        const val EXTRA_DAYS_OF_WEEK = "extra_days_of_week"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        Log.i(TAG, "Alarm triggered: $action")

        when (action) {
            ACTION_ALARM_FLEXIBLE_REMINDER -> {
                handleFlexibleReminder(context, intent)
            }

            ACTION_ALARM_HABIT -> {
                if (!ScreenTimePreferences.areHabitRemindersEnabled(context)) {
                    Log.i(TAG, "Habit reminders disabled in preferences, skipping.")
                    return
                }
                val habitId = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_ID) ?: ""
                val title = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE) ?: "Daily Habit"
                val duration = intent.getIntExtra(AreteNotificationHelper.EXTRA_DURATION_MINS, 15)

                if (habitId.isNotBlank()) {
                    AreteNotificationHelper.showHabitReminderNotification(context, habitId, title, duration)
                }
            }

            ACTION_ALARM_TASK_DUE -> {
                if (!ScreenTimePreferences.areTaskAlertsEnabled(context)) {
                    Log.i(TAG, "Task alerts disabled in preferences, skipping.")
                    return
                }
                val taskId = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_ID) ?: ""
                val title = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE) ?: "Task"
                val isFifteenMin = intent.getBooleanExtra(AreteNotificationHelper.EXTRA_IS_FIFTEEN_MIN, false)

                if (taskId.isNotBlank()) {
                    AreteNotificationHelper.showTaskDueNotification(context, taskId, title, isFifteenMin)
                }
            }

            Intent.ACTION_BOOT_COMPLETED -> {
                Log.i(TAG, "Boot completed received in AreteAlarmReceiver.")
                if (ScreenTimePreferences.isMonitoringEnabled(context)) {
                    val serviceIntent = Intent(context, ScreenTimeMonitoringService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                }
            }
        }
    }

    private fun handleFlexibleReminder(context: Context, intent: Intent) {
        val reminderId = intent.getStringExtra(AreteNotificationHelper.EXTRA_REMINDER_ID) ?: return
        val title = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE) ?: "Reminder"
        val description = intent.getStringExtra("extra_description")
        val targetType = intent.getStringExtra(AreteNotificationHelper.EXTRA_TARGET_TYPE) ?: "standalone"
        val targetId = intent.getStringExtra(AreteNotificationHelper.EXTRA_TARGET_ID)
        val triggerType = intent.getStringExtra(AreteNotificationHelper.EXTRA_TRIGGER_TYPE) ?: "fixed_time"
        val intervalMinutes = intent.getIntExtra(AreteNotificationHelper.EXTRA_INTERVAL_MINS, 60)
        val windowStartHour = intent.getIntExtra(EXTRA_WINDOW_START_HOUR, 9)
        val windowStartMinute = intent.getIntExtra(EXTRA_WINDOW_START_MINUTE, 0)
        val windowEndHour = intent.getIntExtra(EXTRA_WINDOW_END_HOUR, 21)
        val windowEndMinute = intent.getIntExtra(EXTRA_WINDOW_END_MINUTE, 0)
        val fixedHour = intent.getIntExtra(EXTRA_FIXED_HOUR, 10)
        val fixedMinute = intent.getIntExtra(EXTRA_FIXED_MINUTE, 0)
        val daysOfWeek = intent.getStringExtra(EXTRA_DAYS_OF_WEEK)
        val priority = intent.getStringExtra(AreteNotificationHelper.EXTRA_PRIORITY) ?: "medium"
        val isSticky = intent.getBooleanExtra(AreteNotificationHelper.EXTRA_IS_STICKY, false)
        val soundMode = intent.getStringExtra(AreteNotificationHelper.EXTRA_SOUND_MODE) ?: "gentle_chime"

        val nowCal = java.util.Calendar.getInstance()

        if (triggerType == "interval") {
            val currentMinutesFromMidnight = nowCal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + nowCal.get(java.util.Calendar.MINUTE)
            val windowStartMinutes = windowStartHour * 60 + windowStartMinute
            val windowEndMinutes = windowEndHour * 60 + windowEndMinute

            val isInWindow = if (windowStartMinutes <= windowEndMinutes) {
                currentMinutesFromMidnight in windowStartMinutes..windowEndMinutes
            } else {
                currentMinutesFromMidnight >= windowStartMinutes || currentMinutesFromMidnight <= windowEndMinutes
            }

            if (isInWindow) {
                // Show notification inside the active window
                AreteNotificationHelper.showFlexibleReminderNotification(
                    context = context,
                    reminderId = reminderId,
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

                // Reschedule next interval tick
                val nextTriggerMs = System.currentTimeMillis() + (intervalMinutes * 60 * 1000L)
                val nextCal = java.util.Calendar.getInstance().apply { timeInMillis = nextTriggerMs }
                val nextMinutes = nextCal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + nextCal.get(java.util.Calendar.MINUTE)

                val nextInWindow = if (windowStartMinutes <= windowEndMinutes) {
                    nextMinutes in windowStartMinutes..windowEndMinutes
                } else {
                    nextMinutes >= windowStartMinutes || nextMinutes <= windowEndMinutes
                }

                val finalTriggerMs = if (nextInWindow) {
                    nextTriggerMs
                } else {
                    // Next interval exceeds window end -> schedule for start of next window tomorrow morning
                    java.util.Calendar.getInstance().apply {
                        set(java.util.Calendar.HOUR_OF_DAY, windowStartHour)
                        set(java.util.Calendar.MINUTE, windowStartMinute)
                        set(java.util.Calendar.SECOND, 0)
                        set(java.util.Calendar.MILLISECOND, 0)
                        if (timeInMillis <= System.currentTimeMillis()) {
                            add(java.util.Calendar.DAY_OF_YEAR, 1)
                        }
                    }.timeInMillis
                }
                rescheduleAlarm(context, intent, reminderId, finalTriggerMs)
            } else {
                // Outside active window: silently defer until the start of next active window
                val nextStartCal = java.util.Calendar.getInstance().apply {
                    set(java.util.Calendar.HOUR_OF_DAY, windowStartHour)
                    set(java.util.Calendar.MINUTE, windowStartMinute)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                    if (timeInMillis <= System.currentTimeMillis()) {
                        add(java.util.Calendar.DAY_OF_YEAR, 1)
                    }
                }
                rescheduleAlarm(context, intent, reminderId, nextStartCal.timeInMillis)
            }
        } else {
            // Fixed Time trigger
            val daysList = if (!daysOfWeek.isNullOrBlank()) {
                daysOfWeek.split(",").mapNotNull { it.trim().toIntOrNull() }
            } else {
                listOf(1, 2, 3, 4, 5, 6, 7)
            }

            // ISO day: 1 = Mon ... 7 = Sun
            val calDow = nowCal.get(java.util.Calendar.DAY_OF_WEEK)
            val currentIsoDay = if (calDow == java.util.Calendar.SUNDAY) 7 else calDow - 1

            if (daysList.contains(currentIsoDay)) {
                AreteNotificationHelper.showFlexibleReminderNotification(
                    context = context,
                    reminderId = reminderId,
                    title = title,
                    description = description,
                    targetType = targetType,
                    targetId = targetId,
                    priority = priority,
                    isSticky = isSticky,
                    soundMode = soundMode,
                    intervalMinutes = null,
                    triggerType = triggerType
                )
            }

            // Find next scheduled day
            val nextCal = java.util.Calendar.getInstance().apply {
                add(java.util.Calendar.DAY_OF_YEAR, 1)
                set(java.util.Calendar.HOUR_OF_DAY, fixedHour)
                set(java.util.Calendar.MINUTE, fixedMinute)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            for (i in 0..7) {
                val dow = nextCal.get(java.util.Calendar.DAY_OF_WEEK)
                val iso = if (dow == java.util.Calendar.SUNDAY) 7 else dow - 1
                if (daysList.contains(iso)) {
                    break
                }
                nextCal.add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
            rescheduleAlarm(context, intent, reminderId, nextCal.timeInMillis)
        }
    }

    private fun rescheduleAlarm(context: Context, originalIntent: Intent, reminderId: String, triggerAtMs: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? android.app.AlarmManager ?: return
        val reqCode = (reminderId.hashCode() and 0x7FFFFFFF) % 100000 + 4000
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        } else {
            android.app.PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(context, reqCode, originalIntent, flags)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
        } else {
            alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
        }
    }
}
