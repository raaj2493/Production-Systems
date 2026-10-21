import 'package:flutter/material.dart';

class NotificationPreferences {
  final bool habitRemindersEnabled;
  final int morningReminderHour;
  final int morningReminderMinute;
  final int eveningReminderHour;
  final int eveningReminderMinute;
  final bool taskAlertsEnabled;
  final bool taskFifteenMinWarning;
  final bool screenTimeMonitoringEnabled;
  final int distractionLimitMinutes;
  final bool autoShieldOnLimit;

  const NotificationPreferences({
    this.habitRemindersEnabled = true,
    this.morningReminderHour = 8,
    this.morningReminderMinute = 30,
    this.eveningReminderHour = 20,
    this.eveningReminderMinute = 0,
    this.taskAlertsEnabled = true,
    this.taskFifteenMinWarning = true,
    this.screenTimeMonitoringEnabled = false,
    this.distractionLimitMinutes = 30,
    this.autoShieldOnLimit = true,
  });

  TimeOfDay get morningTime => TimeOfDay(hour: morningReminderHour, minute: morningReminderMinute);
  TimeOfDay get eveningTime => TimeOfDay(hour: eveningReminderHour, minute: eveningReminderMinute);

  String get morningFormatted => _formatTime(morningReminderHour, morningReminderMinute);
  String get eveningFormatted => _formatTime(eveningReminderHour, eveningReminderMinute);

  static String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  NotificationPreferences copyWith({
    bool? habitRemindersEnabled,
    int? morningReminderHour,
    int? morningReminderMinute,
    int? eveningReminderHour,
    int? eveningReminderMinute,
    bool? taskAlertsEnabled,
    bool? taskFifteenMinWarning,
    bool? screenTimeMonitoringEnabled,
    int? distractionLimitMinutes,
    bool? autoShieldOnLimit,
  }) {
    return NotificationPreferences(
      habitRemindersEnabled: habitRemindersEnabled ?? this.habitRemindersEnabled,
      morningReminderHour: morningReminderHour ?? this.morningReminderHour,
      morningReminderMinute: morningReminderMinute ?? this.morningReminderMinute,
      eveningReminderHour: eveningReminderHour ?? this.eveningReminderHour,
      eveningReminderMinute: eveningReminderMinute ?? this.eveningReminderMinute,
      taskAlertsEnabled: taskAlertsEnabled ?? this.taskAlertsEnabled,
      taskFifteenMinWarning: taskFifteenMinWarning ?? this.taskFifteenMinWarning,
      screenTimeMonitoringEnabled: screenTimeMonitoringEnabled ?? this.screenTimeMonitoringEnabled,
      distractionLimitMinutes: distractionLimitMinutes ?? this.distractionLimitMinutes,
      autoShieldOnLimit: autoShieldOnLimit ?? this.autoShieldOnLimit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'habitRemindersEnabled': habitRemindersEnabled,
      'morningReminderHour': morningReminderHour,
      'morningReminderMinute': morningReminderMinute,
      'eveningReminderHour': eveningReminderHour,
      'eveningReminderMinute': eveningReminderMinute,
      'taskAlertsEnabled': taskAlertsEnabled,
      'taskFifteenMinWarning': taskFifteenMinWarning,
      'screenTimeMonitoringEnabled': screenTimeMonitoringEnabled,
      'distractionLimitMinutes': distractionLimitMinutes,
      'autoShieldOnLimit': autoShieldOnLimit,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      habitRemindersEnabled: map['habitRemindersEnabled'] as bool? ?? true,
      morningReminderHour: map['morningReminderHour'] as int? ?? 8,
      morningReminderMinute: map['morningReminderMinute'] as int? ?? 30,
      eveningReminderHour: map['eveningReminderHour'] as int? ?? 20,
      eveningReminderMinute: map['eveningReminderMinute'] as int? ?? 0,
      taskAlertsEnabled: map['taskAlertsEnabled'] as bool? ?? true,
      taskFifteenMinWarning: map['taskFifteenMinWarning'] as bool? ?? true,
      screenTimeMonitoringEnabled: map['screenTimeMonitoringEnabled'] as bool? ?? false,
      distractionLimitMinutes: map['distractionLimitMinutes'] as int? ?? 30,
      autoShieldOnLimit: map['autoShieldOnLimit'] as bool? ?? true,
    );
  }
}
