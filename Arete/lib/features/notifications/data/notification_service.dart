import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../habits/domain/habit_model.dart';
import '../../tasks/domain/task_model.dart';
import '../domain/notification_preferences_model.dart';

class NotificationService {
  static const MethodChannel _channel = MethodChannel('com.arete.app/notifications_and_screentime');

  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Check whether notification permissions are granted
  Future<bool> isNotificationPermissionGranted() async {
    if (!isAndroid) return true;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('isNotificationPermissionGranted');
      return granted ?? false;
    } catch (e) {
      debugPrint('NotificationService: isNotificationPermissionGranted error: $e');
      return false;
    }
  }

  /// Request runtime POST_NOTIFICATIONS permission
  Future<bool> requestNotificationPermission() async {
    if (!isAndroid) return true;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return ok ?? false;
    } catch (e) {
      debugPrint('NotificationService: requestNotificationPermission error: $e');
      return false;
    }
  }

  /// Open system app notification settings
  Future<void> openNotificationSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('NotificationService: openNotificationSettings error: $e');
    }
  }

  /// Sync notification preferences to native background receivers
  Future<void> syncNotificationPreferences(NotificationPreferences prefs) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('setNotificationPreferences', {
        'habitReminders': prefs.habitRemindersEnabled,
        'taskAlerts': prefs.taskAlertsEnabled,
        'morningTime': '${prefs.morningReminderHour.toString().padLeft(2, '0')}:${prefs.morningReminderMinute.toString().padLeft(2, '0')}',
        'eveningTime': '${prefs.eveningReminderHour.toString().padLeft(2, '0')}:${prefs.eveningReminderMinute.toString().padLeft(2, '0')}',
      });
    } catch (e) {
      debugPrint('NotificationService: syncNotificationPreferences error: $e');
    }
  }

  /// Schedule daily habit reminder with Android AlarmManager
  Future<void> scheduleHabitReminder({
    required String id,
    required String title,
    required int durationMinutes,
    required int hour,
    required int minute,
  }) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleHabitReminder', {
        'id': id,
        'title': title,
        'duration': durationMinutes,
        'hour': hour,
        'minute': minute,
      });
    } catch (e) {
      debugPrint('NotificationService: scheduleHabitReminder error: $e');
    }
  }

  /// Cancel scheduled habit reminder
  Future<void> cancelHabitReminder(String id) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('cancelHabitReminder', {'id': id});
    } catch (e) {
      debugPrint('NotificationService: cancelHabitReminder error: $e');
    }
  }

  /// Schedule task deadline reminder (15m before and at due time)
  Future<void> scheduleTaskAlert({
    required String id,
    required String title,
    required DateTime dueDateTime,
  }) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleTaskAlert', {
        'id': id,
        'title': title,
        'dueTimestampMs': dueDateTime.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('NotificationService: scheduleTaskAlert error: $e');
    }
  }

  /// Cancel scheduled task alerts
  Future<void> cancelTaskAlert(String id) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('cancelTaskAlert', {'id': id});
    } catch (e) {
      debugPrint('NotificationService: cancelTaskAlert error: $e');
    }
  }

  /// Synchronize all habits with daily morning/evening reminder schedules
  Future<void> syncHabitsReminders(List<Habit> habits, NotificationPreferences prefs) async {
    if (!isAndroid) return;
    if (!prefs.habitRemindersEnabled) {
      for (final habit in habits) {
        await cancelHabitReminder(habit.id);
      }
      return;
    }

    for (final habit in habits) {
      // Schedule morning or evening based on habit or defaults
      final hour = prefs.morningReminderHour;
      final minute = prefs.morningReminderMinute;
      await scheduleHabitReminder(
        id: habit.id,
        title: habit.title,
        durationMinutes: 15,
        hour: hour,
        minute: minute,
      );
    }
  }

  /// Synchronize active tasks with due dates
  Future<void> syncTasksAlerts(List<Task> tasks, NotificationPreferences prefs) async {
    if (!isAndroid) return;
    if (!prefs.taskAlertsEnabled) {
      for (final task in tasks) {
        await cancelTaskAlert(task.id);
      }
      return;
    }

    final now = DateTime.now();
    for (final task in tasks) {
      if (task.isCompleted || task.dueDate == null) {
        await cancelTaskAlert(task.id);
        continue;
      }

      // Parse due date
      try {
        final parsed = DateTime.tryParse(task.dueDate!);
        if (parsed != null && parsed.isAfter(now)) {
          await scheduleTaskAlert(
            id: task.id,
            title: task.title,
            dueDateTime: parsed,
          );
        }
      } catch (e) {
        // Ignore unparseable
      }
    }
  }

  /// Retrieve and pop actions performed directly in the notification shade (Done / Snooze)
  Future<List<Map<String, dynamic>>> popPendingNotificationActions() async {
    if (!isAndroid) return [];
    try {
      final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>('popPendingActions');
      if (raw == null) return [];
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('NotificationService: popPendingNotificationActions error: $e');
      return [];
    }
  }

  /// Checks if app was launched via notification action (e.g. "⚡ Start 25m Focus Session")
  Future<Map<String, dynamic>?> getInitialAction() async {
    if (!isAndroid) return null;
    try {
      final dynamic raw = await _channel.invokeMethod('getInitialAction');
      if (raw == null) return null;
      return Map<String, dynamic>.from(raw as Map);
    } catch (e) {
      debugPrint('NotificationService: getInitialAction error: $e');
      return null;
    }
  }

  /// Schedule flexible interval or fixed-time recurring reminder
  Future<void> scheduleFlexibleReminder(dynamic reminderConfig) async {
    if (!isAndroid) return;
    try {
      final map = reminderConfig.toMethodChannelMap();
      await _channel.invokeMethod('scheduleFlexibleReminder', map);
    } catch (e) {
      debugPrint('NotificationService: scheduleFlexibleReminder error: $e');
    }
  }

  /// Cancel flexible reminder alarm and dismiss notification
  Future<void> cancelFlexibleReminder(String reminderId) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('cancelFlexibleReminder', {'id': reminderId});
    } catch (e) {
      debugPrint('NotificationService: cancelFlexibleReminder error: $e');
    }
  }

  /// Immediately trigger a flexible reminder notification for testing / live preview
  Future<void> showFlexibleReminderNow(dynamic reminderConfig) async {
    if (!isAndroid) return;
    try {
      final map = reminderConfig.toMethodChannelMap();
      await _channel.invokeMethod('showFlexibleReminderNow', map);
    } catch (e) {
      debugPrint('NotificationService: showFlexibleReminderNow error: $e');
    }
  }

  /// Show or update persistent ongoing Focus session notification in notification shade
  Future<void> showFocusTimerNotification({
    required int remainingSeconds,
    required int totalSeconds,
    required bool isRunning,
    String sessionType = 'focus',
    String? sessionLabel,
  }) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('showFocusTimerNotification', {
        'remainingSeconds': remainingSeconds,
        'totalSeconds': totalSeconds,
        'isRunning': isRunning,
        'sessionType': sessionType,
        'sessionLabel': sessionLabel,
      });
    } catch (e) {
      debugPrint('NotificationService: showFocusTimerNotification error: $e');
    }
  }

  /// Dismiss persistent Focus session notification
  Future<void> cancelFocusTimerNotification() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('cancelFocusTimerNotification');
    } catch (e) {
      debugPrint('NotificationService: cancelFocusTimerNotification error: $e');
    }
  }

  /// Show completion alert notification with sound/vibration
  Future<void> showFocusCompletionNotification({
    required int durationMinutes,
    String sessionType = 'focus',
  }) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('showFocusCompletionNotification', {
        'durationMinutes': durationMinutes,
        'sessionType': sessionType,
      });
    } catch (e) {
      debugPrint('NotificationService: showFocusCompletionNotification error: $e');
    }
  }
}

