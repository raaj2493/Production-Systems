package com.arete.app.arete

import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build
import android.util.Log

object AreteAlarmHelper {
    private const val TAG = "AreteAlarmHelper"

    fun scheduleAlarmSafe(alarmManager: AlarmManager, triggerAtMs: Long, pendingIntent: PendingIntent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                    Log.d(TAG, "Scheduled exact alarm at $triggerAtMs")
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                    Log.d(TAG, "Exact alarm permission missing; fallback to setAndAllowWhileIdle at $triggerAtMs")
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                Log.d(TAG, "Scheduled exact alarm (API M) at $triggerAtMs")
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                Log.d(TAG, "Scheduled exact alarm (< API M) at $triggerAtMs")
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "SecurityException scheduling exact alarm: ${e.message}; falling back", e)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
                }
            } catch (ignored: Exception) {
                Log.e(TAG, "Failed to schedule fallback alarm: ${ignored.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error scheduling alarm: ${e.message}", e)
        }
    }
}
