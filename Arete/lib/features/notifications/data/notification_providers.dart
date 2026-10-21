import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../habits/data/habit_repository.dart';
import '../../reminders/data/reminder_providers.dart';
import '../../tasks/data/task_repository.dart';
import '../domain/notification_preferences_model.dart';
import 'notification_service.dart';

import '../../focus/presentation/focus_timer_controller.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationPermissionGrantedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.isNotificationPermissionGranted();
});

final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = ref.watch(notificationServiceProvider);
  return NotificationPreferencesNotifier(prefs, service, ref);
});

class NotificationPreferencesNotifier extends StateNotifier<NotificationPreferences> {
  static const String _prefKey = 'arete_notification_preferences_v1';

  final SharedPreferences? _prefs;
  final NotificationService _service;
  final Ref _ref;

  NotificationPreferencesNotifier(this._prefs, this._service, this._ref)
      : super(const NotificationPreferences()) {
    _loadPreferences();
  }

  void _loadPreferences() {
    if (_prefs == null) return;
    final jsonStr = _prefs.getString(_prefKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = NotificationPreferences.fromMap(map);
      } catch (e) {
        debugPrint('Error parsing notification preferences: $e');
      }
    }
  }

  Future<void> _savePreferences() async {
    final map = state.toMap();
    await _prefs?.setString(_prefKey, jsonEncode(map));
    await _service.syncNotificationPreferences(state);
  }

  Future<void> setHabitRemindersEnabled(bool enabled) async {
    state = state.copyWith(habitRemindersEnabled: enabled);
    await _savePreferences();

    // Trigger sync
    final habits = _ref.read(habitsProvider).valueOrNull ?? [];
    await _service.syncHabitsReminders(habits, state);
  }

  Future<void> setMorningReminderTime(TimeOfDay time) async {
    state = state.copyWith(
      morningReminderHour: time.hour,
      morningReminderMinute: time.minute,
    );
    await _savePreferences();

    final habits = _ref.read(habitsProvider).valueOrNull ?? [];
    await _service.syncHabitsReminders(habits, state);
  }

  Future<void> setEveningReminderTime(TimeOfDay time) async {
    state = state.copyWith(
      eveningReminderHour: time.hour,
      eveningReminderMinute: time.minute,
    );
    await _savePreferences();

    final habits = _ref.read(habitsProvider).valueOrNull ?? [];
    await _service.syncHabitsReminders(habits, state);
  }

  Future<void> setTaskAlertsEnabled(bool enabled) async {
    state = state.copyWith(taskAlertsEnabled: enabled);
    await _savePreferences();

    final tasks = _ref.read(tasksProvider).valueOrNull ?? [];
    await _service.syncTasksAlerts(tasks, state);
  }

  Future<void> setTaskFifteenMinWarning(bool enabled) async {
    state = state.copyWith(taskFifteenMinWarning: enabled);
    await _savePreferences();

    final tasks = _ref.read(tasksProvider).valueOrNull ?? [];
    await _service.syncTasksAlerts(tasks, state);
  }

  Future<void> setScreenTimeMonitoringEnabled(bool enabled) async {
    state = state.copyWith(screenTimeMonitoringEnabled: enabled);
    await _savePreferences();
  }

  Future<void> setDistractionLimitMinutes(int minutes) async {
    state = state.copyWith(distractionLimitMinutes: minutes);
    await _savePreferences();
  }

  Future<void> setAutoShieldOnLimit(bool enabled) async {
    state = state.copyWith(autoShieldOnLimit: enabled);
    await _savePreferences();
  }

  /// Process any actions completed directly in the Android notification shade
  Future<int> processPendingShadeActions() async {
    final actions = await _service.popPendingNotificationActions();
    if (actions.isEmpty) return 0;

    int processedCount = 0;
    for (final action in actions) {
      final type = action['type'] as String?;
      final id = action['id'] as String?;

      if (type == 'focus_pause') {
        _ref.read(focusTimerProvider.notifier).pause();
        processedCount++;
        continue;
      } else if (type == 'focus_resume') {
        _ref.read(focusTimerProvider.notifier).resume();
        processedCount++;
        continue;
      } else if (type == 'focus_stop') {
        _ref.read(focusTimerProvider.notifier).reset();
        processedCount++;
        continue;
      } else if (type == 'focus_add_time') {
        final mins = int.tryParse(id ?? '') ?? 5;
        _ref.read(focusTimerProvider.notifier).addMinutes(mins);
        processedCount++;
        continue;
      }

      if (id == null || id.isEmpty) continue;

      if (type == 'task_done') {
        final tasks = _ref.read(tasksProvider).valueOrNull ?? [];
        final task = tasks.where((t) => t.id == id).firstOrNull;
        if (task != null && !task.isCompleted) {
          await _ref.read(tasksProvider.notifier).toggleTask(id);
          processedCount++;
        }
      } else if (type == 'habit_done') {
        final today = AppDateUtils.todayIso;
        await _ref.read(habitsProvider.notifier).toggleHabitCompletion(id, today);
        processedCount++;
      } else if (type == 'reminder_done') {
        // Refresh reminders list
        await _ref.read(remindersProvider.notifier).loadReminders();
        processedCount++;
      }
    }
    return processedCount;
  }
}
