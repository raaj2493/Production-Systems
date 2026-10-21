package com.arete.app.arete

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat

object AreteNotificationHelper {

    const val CHANNEL_REMINDERS = "arete_reminders_channel"
    const val CHANNEL_HIGH_PRIORITY = "arete_reminders_high"
    const val CHANNEL_MEDIUM_PRIORITY = "arete_reminders_medium"
    const val CHANNEL_LOW_PRIORITY = "arete_reminders_low"
    const val CHANNEL_SCREEN_TIME = "arete_screen_time_channel"
    const val CHANNEL_DISTRACTION_ALERT = "arete_distraction_channel"
    const val CHANNEL_FOCUS_TIMER = "arete_focus_timer_channel"
    const val CHANNEL_FOCUS_COMPLETE = "arete_focus_complete_channel"

    const val NOTIFICATION_ID_SCREEN_TIME = 9001
    const val NOTIFICATION_ID_DISTRACTION_ALERT = 9002
    const val NOTIFICATION_ID_FOCUS_TIMER = 9005
    const val NOTIFICATION_ID_FOCUS_COMPLETE = 9006

    const val ACTION_HABIT_DONE = "com.arete.app.ACTION_HABIT_DONE"
    const val ACTION_HABIT_SNOOZE = "com.arete.app.ACTION_HABIT_SNOOZE"
    const val ACTION_TASK_DONE = "com.arete.app.ACTION_TASK_DONE"
    const val ACTION_TASK_SNOOZE = "com.arete.app.ACTION_TASK_SNOOZE"
    const val ACTION_REMINDER_DONE = "com.arete.app.ACTION_REMINDER_DONE"
    const val ACTION_REMINDER_SNOOZE = "com.arete.app.ACTION_REMINDER_SNOOZE"
    const val ACTION_START_FOCUS = "com.arete.app.ACTION_START_FOCUS"
    const val ACTION_FOCUS_PAUSE = "com.arete.app.ACTION_FOCUS_PAUSE"
    const val ACTION_FOCUS_RESUME = "com.arete.app.ACTION_FOCUS_RESUME"
    const val ACTION_FOCUS_STOP = "com.arete.app.ACTION_FOCUS_STOP"
    const val ACTION_FOCUS_ADD_TIME = "com.arete.app.ACTION_FOCUS_ADD_TIME"

    const val EXTRA_ITEM_ID = "extra_item_id"
    const val EXTRA_ITEM_TITLE = "extra_item_title"
    const val EXTRA_DURATION_MINS = "extra_duration_mins"
    const val EXTRA_IS_FIFTEEN_MIN = "extra_is_fifteen_min"
    const val EXTRA_REMINDER_ID = "extra_reminder_id"
    const val EXTRA_TARGET_TYPE = "extra_target_type"
    const val EXTRA_TARGET_ID = "extra_target_id"
    const val EXTRA_PRIORITY = "extra_priority"
    const val EXTRA_IS_STICKY = "extra_is_sticky"
    const val EXTRA_SOUND_MODE = "extra_sound_mode"
    const val EXTRA_INTERVAL_MINS = "extra_interval_mins"
    const val EXTRA_TRIGGER_TYPE = "extra_trigger_type"

    fun initNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Legacy reminders channel
            val remindersChannel = NotificationChannel(
                CHANNEL_REMINDERS,
                "Areté Habits & Task Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Daily ritual reminders and active task scheduled alerts"
                enableLights(true)
                lightColor = Color.parseColor("#4D7C5D")
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(remindersChannel)

            // 1. High Priority Reminders Channel (Urgent / Health: Heads-up banner, sound, vibration)
            val highChannel = NotificationChannel(
                CHANNEL_HIGH_PRIORITY,
                "Areté Urgent & Health Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Urgent health, hydration, medication, and high-priority reminders"
                enableLights(true)
                lightColor = Color.parseColor("#E25545")
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(highChannel)

            // 2. Medium Priority Reminders Channel (Habits & Tasks: Standard drawer item)
            val medChannel = NotificationChannel(
                CHANNEL_MEDIUM_PRIORITY,
                "Areté Standard Reminders",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Habit rituals and scheduled task alerts in the notification drawer"
                enableLights(true)
                lightColor = Color.parseColor("#4D7C5D")
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(medChannel)

            // 3. Low Priority Reminders Channel (Mindful Nudges: Silent notification entry)
            val lowChannel = NotificationChannel(
                CHANNEL_LOW_PRIORITY,
                "Areté Mindful Nudges",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Silent mindful nudges, reflection prompts, and subtle reminders"
                setShowBadge(false)
                enableVibration(false)
            }
            notificationManager.createNotificationChannel(lowChannel)

            // 4. Screen Time channel (Low importance for smooth, silent ongoing status)
            val screenTimeChannel = NotificationChannel(
                CHANNEL_SCREEN_TIME,
                "Areté Screen Time Tracker",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent status bar tracker for device screen time and active apps"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(screenTimeChannel)

            // 5. Distraction Warning channel
            val distractionChannel = NotificationChannel(
                CHANNEL_DISTRACTION_ALERT,
                "Areté Distraction Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts triggered when distraction app limits are reached"
                enableLights(true)
                lightColor = Color.parseColor("#FF7A59")
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(distractionChannel)

            // 6. Focus Timer channel (Low importance for smooth, silent ongoing timer updates)
            val focusChannel = NotificationChannel(
                CHANNEL_FOCUS_TIMER,
                "Areté Focus Session Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active countdown and controls for your current focus session"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }
            notificationManager.createNotificationChannel(focusChannel)

            // 7. Focus Session Complete celebration channel
            val completeChannel = NotificationChannel(
                CHANNEL_FOCUS_COMPLETE,
                "Areté Focus Session Complete",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Celebration alerts when your focus session completes"
                setShowBadge(true)
                enableVibration(true)
                enableLights(true)
                lightColor = Color.parseColor("#4D7C5D")
            }
            notificationManager.createNotificationChannel(completeChannel)
        }
    }

    private fun getLaunchIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, 0, intent, flags)
    }

    // --- 1. Habit Reminder Notification ---
    fun showHabitReminderNotification(
        context: Context,
        habitId: String,
        habitTitle: String,
        durationMinutes: Int
    ) {
        initNotificationChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifId = (habitId.hashCode() and 0x7FFFFFFF) % 100000 + 1000

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Action: Done
        val doneIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_HABIT_DONE
            putExtra(EXTRA_ITEM_ID, habitId)
            putExtra(EXTRA_ITEM_TITLE, habitTitle)
        }
        val donePendingIntent = PendingIntent.getBroadcast(
            context,
            notifId * 10 + 1,
            doneIntent,
            flags
        )

        // Action: Snooze (10m)
        val snoozeIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_HABIT_SNOOZE
            putExtra(EXTRA_ITEM_ID, habitId)
            putExtra(EXTRA_ITEM_TITLE, habitTitle)
            putExtra(EXTRA_DURATION_MINS, durationMinutes)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            context,
            notifId * 10 + 2,
            snoozeIntent,
            flags
        )

        val durationLabel = if (durationMinutes > 0) " ($durationMinutes mins)" else ""
        val builder = NotificationCompat.Builder(context, CHANNEL_REMINDERS)
            .setSmallIcon(R.drawable.ic_stat_arete)
            .setContentTitle("⏰ Habit Ritual: $habitTitle")
            .setContentText("Time for your ritual: $habitTitle$durationLabel. Build your streak!")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Time for your daily ritual: $habitTitle$durationLabel. Consistent micro-actions compound into greatness."))
            .setColor(Color.parseColor("#4D7C5D")) // Material You Sage Forest
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(getLaunchIntent(context))
            .addAction(android.R.drawable.checkbox_on_background, "✓ Done", donePendingIntent)
            .addAction(android.R.drawable.ic_popup_sync, "⏱ Snooze (10m)", snoozePendingIntent)

        notificationManager.notify(notifId, builder.build())
    }

    // --- 2. Task Due Alert Notification ---
    fun showTaskDueNotification(
        context: Context,
        taskId: String,
        taskTitle: String,
        isFifteenMinWarning: Boolean
    ) {
        initNotificationChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifId = (taskId.hashCode() and 0x7FFFFFFF) % 100000 + 2000

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Action: Done
        val doneIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_TASK_DONE
            putExtra(EXTRA_ITEM_ID, taskId)
            putExtra(EXTRA_ITEM_TITLE, taskTitle)
        }
        val donePendingIntent = PendingIntent.getBroadcast(
            context,
            notifId * 10 + 1,
            doneIntent,
            flags
        )

        // Action: Snooze (10m)
        val snoozeIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_TASK_SNOOZE
            putExtra(EXTRA_ITEM_ID, taskId)
            putExtra(EXTRA_ITEM_TITLE, taskTitle)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            context,
            notifId * 10 + 2,
            snoozeIntent,
            flags
        )

        val title = if (isFifteenMinWarning) "⏳ Task Due in 15 Minutes" else "🎯 Task Due Now: $taskTitle"
        val body = if (isFifteenMinWarning) {
            "\"$taskTitle\" is due shortly. Wrap up and get ready to complete it!"
        } else {
            "Time to complete \"$taskTitle\". Keep your momentum going!"
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_REMINDERS)
            .setSmallIcon(R.drawable.ic_stat_arete)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setColor(if (isFifteenMinWarning) Color.parseColor("#E6A23C") else Color.parseColor("#4D7C5D"))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(getLaunchIntent(context))
            .addAction(android.R.drawable.checkbox_on_background, "✓ Mark Done", donePendingIntent)
            .addAction(android.R.drawable.ic_popup_sync, "⏱ Snooze (10m)", snoozePendingIntent)

        notificationManager.notify(notifId, builder.build())
    }

    // --- 3. Persistent Screen Time & Foreground App Notification ---
    fun buildScreenTimeNotification(
        context: Context,
        totalScreenTimeMinutes: Int,
        foregroundAppPackage: String,
        foregroundAppName: String,
        foregroundDurationMinutes: Int,
        category: String
    ): Notification {
        initNotificationChannels(context)

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val totalHours = totalScreenTimeMinutes / 60
        val totalMins = totalScreenTimeMinutes % 60
        val totalFormatted = if (totalHours > 0) "${totalHours}h ${totalMins}m" else "${totalMins}m"

        val currDurationFormatted = if (foregroundDurationMinutes >= 60) {
            "${foregroundDurationMinutes / 60}h ${foregroundDurationMinutes % 60}m"
        } else {
            "${foregroundDurationMinutes}m"
        }

        val appDisplay = if (foregroundAppName.isNotBlank()) foregroundAppName else "System"

        val builder = NotificationCompat.Builder(context, CHANNEL_SCREEN_TIME)
            .setSmallIcon(R.drawable.ic_stat_arete)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(getLaunchIntent(context))

        when (category) {
            "distraction" -> {
                builder.setContentTitle("⚠️ Distraction Alert • $appDisplay ($currDurationFormatted)")
                    .setContentText("You've spent $currDurationFormatted on $appDisplay. Time to refocus with Areté!")
                    .setStyle(NotificationCompat.BigTextStyle().bigText("📱 Total Today: $totalFormatted | $appDisplay ($currDurationFormatted)\nYou've spent $currDurationFormatted on $appDisplay. Tap below to launch a deep work session."))
                    .setColor(Color.parseColor("#FF7A59")) // Material You Warm Terracotta

                // Action button: ⚡ Start 25m Focus Session
                val focusIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
                    action = ACTION_START_FOCUS
                    putExtra(EXTRA_DURATION_MINS, 25)
                }
                val focusPendingIntent = PendingIntent.getBroadcast(
                    context,
                    9003,
                    focusIntent,
                    flags
                )
                builder.addAction(android.R.drawable.ic_media_play, "⚡ Start 25m Focus Session", focusPendingIntent)
            }

            "productive" -> {
                builder.setContentTitle("🎯 Deep Focus • $appDisplay ($currDurationFormatted)")
                    .setContentText("Great productivity momentum! Total screen time: $totalFormatted")
                    .setStyle(NotificationCompat.BigTextStyle().bigText("🎯 Deep Focus Momentum!\nCurrent App: $appDisplay ($currDurationFormatted)\nTotal Screen Time Today: $totalFormatted. Excellent focus discipline!"))
                    .setColor(Color.parseColor("#4D7C5D")) // Material You Sage Forest
            }

            else -> {
                builder.setContentTitle("📱 Total Today: $totalFormatted | Current: $appDisplay ($currDurationFormatted)")
                    .setContentText("Areté Screen Time Tracker • Stay mindful of your digital balance")
                    .setStyle(NotificationCompat.BigTextStyle().bigText("📱 Daily Screen Time: $totalFormatted\nCurrent Active App: $appDisplay ($currDurationFormatted)\nMindfulness and intentional technology usage."))
                    .setColor(Color.parseColor("#6B7A82"))
            }
        }

        return builder.build()
    }

    fun updateScreenTimeNotification(
        context: Context,
        totalScreenTimeMinutes: Int,
        foregroundAppPackage: String,
        foregroundAppName: String,
        foregroundDurationMinutes: Int,
        category: String
    ) {
        val notification = buildScreenTimeNotification(
            context,
            totalScreenTimeMinutes,
            foregroundAppPackage,
            foregroundAppName,
            foregroundDurationMinutes,
            category
        )
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID_SCREEN_TIME, notification)
    }

    fun showDistractionLimitAlert(
        context: Context,
        appName: String,
        spentMinutes: Int,
        limitMinutes: Int
    ) {
        initNotificationChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val focusIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_START_FOCUS
            putExtra(EXTRA_DURATION_MINS, 25)
        }
        val focusPendingIntent = PendingIntent.getBroadcast(
            context,
            9004,
            focusIntent,
            flags
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_DISTRACTION_ALERT)
            .setSmallIcon(R.drawable.ic_stat_arete)
            .setContentTitle("⚠️ Distraction Limit Reached: $appName")
            .setContentText("You've exceeded your $limitMinutes min limit ($spentMinutes mins). Time to refocus!")
            .setStyle(NotificationCompat.BigTextStyle().bigText("You have spent $spentMinutes mins on $appName (exceeding your $limitMinutes min daily limit). Step away and reclaim your focus!"))
            .setColor(Color.parseColor("#E25545"))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(getLaunchIntent(context))
            .addAction(android.R.drawable.ic_media_play, "⚡ Start 25m Focus Session", focusPendingIntent)

        notificationManager.notify(NOTIFICATION_ID_DISTRACTION_ALERT, builder.build())
    }

    // --- 4. Flexible Recurring & Priority Reminder Notification ---
    fun showFlexibleReminderNotification(
        context: Context,
        reminderId: String,
        title: String,
        description: String?,
        targetType: String,
        targetId: String?,
        priority: String,
        isSticky: Boolean,
        soundMode: String,
        intervalMinutes: Int? = null,
        triggerType: String? = null
    ) {
        initNotificationChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifId = (reminderId.hashCode() and 0x7FFFFFFF) % 100000 + 4000

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val channelId = when (priority.lowercase()) {
            "high" -> CHANNEL_HIGH_PRIORITY
            "low" -> CHANNEL_LOW_PRIORITY
            else -> CHANNEL_MEDIUM_PRIORITY
        }

        val compatPriority = when (priority.lowercase()) {
            "high" -> NotificationCompat.PRIORITY_HIGH
            "low" -> NotificationCompat.PRIORITY_LOW
            else -> NotificationCompat.PRIORITY_DEFAULT
        }

        val accentColor = when (priority.lowercase()) {
            "high" -> Color.parseColor("#E25545") // Crimson / High urgency
            "low" -> Color.parseColor("#7E8B92")  // Muted Slate
            else -> Color.parseColor("#4D7C5D")   // Sage Forest
        }

        // Inline Action 1: "✅ Mark Done"
        val doneIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_REMINDER_DONE
            putExtra(EXTRA_REMINDER_ID, reminderId)
            putExtra(EXTRA_TARGET_TYPE, targetType)
            putExtra(EXTRA_TARGET_ID, targetId ?: "")
            putExtra(EXTRA_ITEM_ID, targetId ?: "")
            putExtra("notification_id", notifId)
            putExtra(EXTRA_INTERVAL_MINS, intervalMinutes ?: 0)
            putExtra(EXTRA_TRIGGER_TYPE, triggerType ?: "fixed_time")
        }
        val donePendingIntent = PendingIntent.getBroadcast(
            context,
            notifId * 10 + 1,
            doneIntent,
            flags
        )

        // Inline Action 2: "⏰ Snooze (15m)"
        val snoozeIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_REMINDER_SNOOZE
            putExtra(EXTRA_REMINDER_ID, reminderId)
            putExtra(EXTRA_ITEM_TITLE, title)
            putExtra(EXTRA_TARGET_TYPE, targetType)
            putExtra(EXTRA_TARGET_ID, targetId ?: "")
            putExtra(EXTRA_PRIORITY, priority)
            putExtra(EXTRA_IS_STICKY, isSticky)
            putExtra(EXTRA_SOUND_MODE, soundMode)
            putExtra(EXTRA_INTERVAL_MINS, intervalMinutes ?: 0)
            putExtra(EXTRA_TRIGGER_TYPE, triggerType ?: "fixed_time")
            putExtra("notification_id", notifId)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            context,
            notifId * 10 + 2,
            snoozeIntent,
            flags
        )

        // Inline Action 3: "⚡ Start Focus Session"
        val focusIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_START_FOCUS
            putExtra(EXTRA_DURATION_MINS, 25)
            putExtra(EXTRA_ITEM_TITLE, title)
            putExtra("notification_id", notifId)
        }
        val focusPendingIntent = PendingIntent.getBroadcast(
            context,
            notifId * 10 + 3,
            focusIntent,
            flags
        )

        val displayText = if (!description.isNullOrBlank()) description else "Time for your scheduled Areté ritual. Stay focused!"

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_stat_arete)
            .setContentTitle(title)
            .setContentText(displayText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(displayText))
            .setColor(accentColor)
            .setPriority(compatPriority)
            .setContentIntent(getLaunchIntent(context))
            .addAction(android.R.drawable.checkbox_on_background, "✅ Mark Done", donePendingIntent)
            .addAction(android.R.drawable.ic_popup_sync, "⏰ Snooze (15m)", snoozePendingIntent)
            .addAction(android.R.drawable.ic_media_play, "⚡ Start Focus Session", focusPendingIntent)

        // Persistent / Sticky configuration:
        // When enabled, the notification is set as non-cancelable (FLAG_NO_CLEAR / ongoing)
        // and cannot be swiped away until user explicitly taps "Mark Done".
        if (isSticky) {
            builder.setOngoing(true)
            builder.setAutoCancel(false)
            builder.setSubText("📌 Sticky • Must Mark Done")
        } else {
            builder.setOngoing(false)
            builder.setAutoCancel(true)
            if (triggerType == "interval" && (intervalMinutes ?: 0) > 0) {
                builder.setSubText("⏱ Interval • Every ${intervalMinutes}m")
            }
        }

        if (soundMode.equals("silent", ignoreCase = true)) {
            builder.setSilent(true)
        }

        notificationManager.notify(notifId, builder.build())
    }

    fun cancelNotification(context: Context, notificationId: Int) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(notificationId)
    }

    // --- 5. Ongoing Focus Session Notification ---
    fun showFocusTimerNotification(
        context: Context,
        remainingSeconds: Int,
        totalSeconds: Int,
        isRunning: Boolean,
        sessionType: String = "focus",
        sessionLabel: String? = null
    ) {
        initNotificationChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val mins = remainingSeconds / 60
        val secs = remainingSeconds % 60
        val formattedTime = String.format("%02d:%02d", mins, secs)

        val typeLabel = when (sessionType.lowercase()) {
            "shortbreak" -> "Short Break"
            "longbreak" -> "Long Break"
            else -> "Deep Focus"
        }

        val title = if (isRunning) {
            "⚡ $typeLabel: $formattedTime remaining"
        } else {
            "⏸ $typeLabel: $formattedTime (Paused)"
        }

        val subtitle = if (!sessionLabel.isNullOrBlank()) {
            "$sessionLabel • Tap to return to Areté"
        } else {
            "Tap to return to Areté"
        }

        val toggleActionIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = if (isRunning) ACTION_FOCUS_PAUSE else ACTION_FOCUS_RESUME
        }
        val togglePendingIntent = PendingIntent.getBroadcast(
            context,
            9010,
            toggleActionIntent,
            flags
        )
        val toggleTitle = if (isRunning) "⏸ Pause" else "▶ Resume"

        val stopActionIntent = Intent(context, AreteNotificationActionReceiver::class.java).apply {
            action = ACTION_FOCUS_STOP
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            9011,
            stopActionIntent,
            flags
        )

        val progressMax = if (totalSeconds > 0) totalSeconds else 100
        val progressCurrent = (totalSeconds - remainingSeconds).coerceIn(0, progressMax)

        val builder = NotificationCompat.Builder(context, CHANNEL_FOCUS_TIMER)
            .setSmallIcon(R.drawable.ic_stat_arete)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setColor(Color.parseColor("#4D7C5D"))
            .setOngoing(isRunning)
            .setAutoCancel(!isRunning)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(getLaunchIntent(context))
            .setProgress(progressMax, progressCurrent, false)
            .addAction(
                if (isRunning) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                toggleTitle,
                togglePendingIntent
            )
            .addAction(android.R.drawable.ic_delete, "⏹ Stop", stopPendingIntent)

        notificationManager.notify(NOTIFICATION_ID_FOCUS_TIMER, builder.build())
    }

    fun cancelFocusTimerNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID_FOCUS_TIMER)
    }

    // --- 6. Focus Session Completion Notification ---
    fun showFocusCompletionNotification(context: Context, durationMinutes: Int, sessionType: String) {
        initNotificationChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val title = if (sessionType.lowercase() == "focus") {
            "🎉 Focus Session Complete!"
        } else {
            "☕ Break Complete!"
        }

        val message = if (sessionType.lowercase() == "focus") {
            "Awesome dedication! You completed $durationMinutes minutes of deep focus."
        } else {
            "Break is over. Ready to dive back into deep work?"
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_FOCUS_COMPLETE)
            .setSmallIcon(R.drawable.ic_stat_arete)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setColor(Color.parseColor("#4D7C5D"))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(getLaunchIntent(context))

        notificationManager.notify(NOTIFICATION_ID_FOCUS_COMPLETE, builder.build())
    }
}
