package com.arete.app.arete

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AreteNotificationActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AreteNotifAction"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        Log.i(TAG, "Notification action received: $action")

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

        when (action) {
            AreteNotificationHelper.ACTION_HABIT_DONE -> {
                val habitId = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_ID) ?: ""
                if (habitId.isNotBlank()) {
                    ScreenTimePreferences.queuePendingAction(context, "habit_done", habitId)
                    val notifId = (habitId.hashCode() and 0x7FFFFFFF) % 100000 + 1000
                    AreteNotificationHelper.cancelNotification(context, notifId)
                }
            }

            AreteNotificationHelper.ACTION_HABIT_SNOOZE -> {
                val habitId = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_ID) ?: ""
                val habitTitle = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE) ?: "Habit"
                val duration = intent.getIntExtra(AreteNotificationHelper.EXTRA_DURATION_MINS, 0)
                if (habitId.isNotBlank()) {
                    val notifId = (habitId.hashCode() and 0x7FFFFFFF) % 100000 + 1000
                    AreteNotificationHelper.cancelNotification(context, notifId)

                    // Reschedule alarm in 10 minutes (600,000 ms)
                    val snoozeAlarmIntent = Intent(context, AreteAlarmReceiver::class.java).apply {
                        this.action = AreteAlarmReceiver.ACTION_ALARM_HABIT
                        putExtra(AreteNotificationHelper.EXTRA_ITEM_ID, habitId)
                        putExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE, habitTitle)
                        putExtra(AreteNotificationHelper.EXTRA_DURATION_MINS, duration)
                    }
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        notifId + 500,
                        snoozeAlarmIntent,
                        flags
                    )
                    val triggerAt = System.currentTimeMillis() + 10 * 60 * 1000L
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager?.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    } else {
                        alarmManager?.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    }
                }
            }

            AreteNotificationHelper.ACTION_TASK_DONE -> {
                val taskId = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_ID) ?: ""
                if (taskId.isNotBlank()) {
                    ScreenTimePreferences.queuePendingAction(context, "task_done", taskId)
                    val notifId = (taskId.hashCode() and 0x7FFFFFFF) % 100000 + 2000
                    AreteNotificationHelper.cancelNotification(context, notifId)
                }
            }

            AreteNotificationHelper.ACTION_TASK_SNOOZE -> {
                val taskId = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_ID) ?: ""
                val taskTitle = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE) ?: "Task"
                if (taskId.isNotBlank()) {
                    val notifId = (taskId.hashCode() and 0x7FFFFFFF) % 100000 + 2000
                    AreteNotificationHelper.cancelNotification(context, notifId)

                    // Reschedule alarm in 10 minutes
                    val snoozeAlarmIntent = Intent(context, AreteAlarmReceiver::class.java).apply {
                        this.action = AreteAlarmReceiver.ACTION_ALARM_TASK_DUE
                        putExtra(AreteNotificationHelper.EXTRA_ITEM_ID, taskId)
                        putExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE, taskTitle)
                        putExtra(AreteNotificationHelper.EXTRA_IS_FIFTEEN_MIN, false)
                    }
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        notifId + 500,
                        snoozeAlarmIntent,
                        flags
                    )
                    val triggerAt = System.currentTimeMillis() + 10 * 60 * 1000L
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager?.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    } else {
                        alarmManager?.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    }
                }
            }

            AreteNotificationHelper.ACTION_REMINDER_DONE -> {
                val reminderId = intent.getStringExtra(AreteNotificationHelper.EXTRA_REMINDER_ID) ?: ""
                val targetType = intent.getStringExtra(AreteNotificationHelper.EXTRA_TARGET_TYPE) ?: ""
                val targetId = intent.getStringExtra(AreteNotificationHelper.EXTRA_TARGET_ID) ?: ""
                val notifId = intent.getIntExtra("notification_id", 0)

                if (notifId != 0) {
                    AreteNotificationHelper.cancelNotification(context, notifId)
                } else if (reminderId.isNotBlank()) {
                    val fallbackId = (reminderId.hashCode() and 0x7FFFFFFF) % 100000 + 4000
                    AreteNotificationHelper.cancelNotification(context, fallbackId)
                }

                if (reminderId.isNotBlank()) {
                    ScreenTimePreferences.queuePendingAction(context, "reminder_done", reminderId)
                }
                if (targetType == "habit" && targetId.isNotBlank()) {
                    ScreenTimePreferences.queuePendingAction(context, "habit_done", targetId)
                } else if (targetType == "task" && targetId.isNotBlank()) {
                    ScreenTimePreferences.queuePendingAction(context, "task_done", targetId)
                }
            }

            AreteNotificationHelper.ACTION_REMINDER_SNOOZE -> {
                val reminderId = intent.getStringExtra(AreteNotificationHelper.EXTRA_REMINDER_ID) ?: ""
                val title = intent.getStringExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE) ?: "Reminder"
                val targetType = intent.getStringExtra(AreteNotificationHelper.EXTRA_TARGET_TYPE) ?: ""
                val targetId = intent.getStringExtra(AreteNotificationHelper.EXTRA_TARGET_ID) ?: ""
                val priority = intent.getStringExtra(AreteNotificationHelper.EXTRA_PRIORITY) ?: "medium"
                val isSticky = intent.getBooleanExtra(AreteNotificationHelper.EXTRA_IS_STICKY, false)
                val soundMode = intent.getStringExtra(AreteNotificationHelper.EXTRA_SOUND_MODE) ?: "gentle_chime"
                val intervalMinutes = intent.getIntExtra(AreteNotificationHelper.EXTRA_INTERVAL_MINS, 0)
                val triggerType = intent.getStringExtra(AreteNotificationHelper.EXTRA_TRIGGER_TYPE) ?: "fixed_time"
                val notifId = intent.getIntExtra("notification_id", 0)

                if (notifId != 0) {
                    AreteNotificationHelper.cancelNotification(context, notifId)
                } else if (reminderId.isNotBlank()) {
                    val fallbackId = (reminderId.hashCode() and 0x7FFFFFFF) % 100000 + 4000
                    AreteNotificationHelper.cancelNotification(context, fallbackId)
                }

                if (reminderId.isNotBlank()) {
                    // Reschedule reminder alarm in 15 minutes (15 * 60 * 1000L)
                    val snoozeAlarmIntent = Intent(context, AreteAlarmReceiver::class.java).apply {
                        this.action = AreteAlarmReceiver.ACTION_ALARM_FLEXIBLE_REMINDER
                        putExtra(AreteNotificationHelper.EXTRA_REMINDER_ID, reminderId)
                        putExtra(AreteNotificationHelper.EXTRA_ITEM_TITLE, title)
                        putExtra(AreteNotificationHelper.EXTRA_TARGET_TYPE, targetType)
                        putExtra(AreteNotificationHelper.EXTRA_TARGET_ID, targetId)
                        putExtra(AreteNotificationHelper.EXTRA_PRIORITY, priority)
                        putExtra(AreteNotificationHelper.EXTRA_IS_STICKY, isSticky)
                        putExtra(AreteNotificationHelper.EXTRA_SOUND_MODE, soundMode)
                        putExtra(AreteNotificationHelper.EXTRA_INTERVAL_MINS, intervalMinutes)
                        putExtra(AreteNotificationHelper.EXTRA_TRIGGER_TYPE, triggerType)
                    }
                    val reqCode = (reminderId.hashCode() and 0x7FFFFFFF) % 100000 + 4500
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        reqCode,
                        snoozeAlarmIntent,
                        flags
                    )
                    val triggerAt = System.currentTimeMillis() + 15 * 60 * 1000L
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager?.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    } else {
                        alarmManager?.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                    }
                }
            }

            AreteNotificationHelper.ACTION_START_FOCUS -> {
                val duration = intent.getIntExtra(AreteNotificationHelper.EXTRA_DURATION_MINS, 25)
                val notifId = intent.getIntExtra("notification_id", 0)
                if (notifId != 0) {
                    AreteNotificationHelper.cancelNotification(context, notifId)
                }
                AreteNotificationHelper.cancelNotification(context, AreteNotificationHelper.NOTIFICATION_ID_DISTRACTION_ALERT)

                // Launch MainActivity directly into Focus session
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("action", "start_focus_session")
                    putExtra("duration_minutes", duration)
                }
                context.startActivity(launchIntent)
            }

            AreteNotificationHelper.ACTION_FOCUS_PAUSE -> {
                ScreenTimePreferences.queuePendingAction(context, "focus_pause", "")
                // Update notification immediately to reflect paused state
                AreteNotificationHelper.showFocusTimerNotification(
                    context = context,
                    remainingSeconds = 0,
                    totalSeconds = 0,
                    isRunning = false
                )
            }

            AreteNotificationHelper.ACTION_FOCUS_RESUME -> {
                ScreenTimePreferences.queuePendingAction(context, "focus_resume", "")
                // Update notification immediately to reflect running state
                AreteNotificationHelper.showFocusTimerNotification(
                    context = context,
                    remainingSeconds = 0,
                    totalSeconds = 0,
                    isRunning = true
                )
            }

            AreteNotificationHelper.ACTION_FOCUS_STOP -> {
                AreteNotificationHelper.cancelFocusTimerNotification(context)
                ScreenTimePreferences.queuePendingAction(context, "focus_stop", "")
            }

            AreteNotificationHelper.ACTION_FOCUS_ADD_TIME -> {
                val mins = intent.getIntExtra("extra_minutes", 5)
                ScreenTimePreferences.queuePendingAction(context, "focus_add_time", mins.toString())
            }
        }
    }
}
