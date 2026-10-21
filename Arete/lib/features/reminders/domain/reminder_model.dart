import 'package:flutter/material.dart';

enum ReminderTriggerType {
  interval,
  fixedTime;

  String get dbValue {
    switch (this) {
      case ReminderTriggerType.interval:
        return 'interval';
      case ReminderTriggerType.fixedTime:
        return 'fixed_time';
    }
  }

  static ReminderTriggerType fromDbValue(String? val) {
    if (val == 'interval') return ReminderTriggerType.interval;
    return ReminderTriggerType.fixedTime;
  }
}

enum ReminderPriority {
  high,
  medium,
  low;

  String get dbValue => name;

  static ReminderPriority fromDbValue(String? val) {
    switch (val?.toLowerCase()) {
      case 'high':
        return ReminderPriority.high;
      case 'low':
        return ReminderPriority.low;
      case 'medium':
      default:
        return ReminderPriority.medium;
    }
  }

  String get label {
    switch (this) {
      case ReminderPriority.high:
        return 'High Priority';
      case ReminderPriority.medium:
        return 'Medium Priority';
      case ReminderPriority.low:
        return 'Low Priority';
    }
  }

  String get description {
    switch (this) {
      case ReminderPriority.high:
        return 'Heads-up banner, sound/vibration, persistent icon';
      case ReminderPriority.medium:
        return 'Standard notification drawer item';
      case ReminderPriority.low:
        return 'Silent notification entry without vibration';
    }
  }

  Color get color {
    switch (this) {
      case ReminderPriority.high:
        return const Color(0xFFE25545); // Terracotta Crimson
      case ReminderPriority.medium:
        return const Color(0xFF4D7C5D); // Sage Green
      case ReminderPriority.low:
        return const Color(0xFF7E8B92); // Muted Slate
    }
  }
}

enum ReminderSound {
  gentleChime,
  vibrantPing,
  silent;

  String get dbValue {
    switch (this) {
      case ReminderSound.gentleChime:
        return 'gentle_chime';
      case ReminderSound.vibrantPing:
        return 'vibrant_ping';
      case ReminderSound.silent:
        return 'silent';
    }
  }

  static ReminderSound fromDbValue(String? val) {
    switch (val?.toLowerCase()) {
      case 'vibrant_ping':
        return ReminderSound.vibrantPing;
      case 'silent':
        return ReminderSound.silent;
      case 'gentle_chime':
      default:
        return ReminderSound.gentleChime;
    }
  }

  String get label {
    switch (this) {
      case ReminderSound.gentleChime:
        return 'Gentle Chime';
      case ReminderSound.vibrantPing:
        return 'Vibrant Ping';
      case ReminderSound.silent:
        return 'Silent';
    }
  }
}

class ReminderConfig {
  final String id;
  final String targetType; // 'habit', 'task', or 'standalone'
  final String? targetId;
  final String title;
  final String? description;
  final ReminderTriggerType triggerType;
  final int intervalMinutes; // e.g. 15, 30, 45, 60, 90, 120
  final int windowStartHour; // 0..23 (e.g. 9 for 9:00 AM)
  final int windowStartMinute; // 0..59
  final int windowEndHour; // 0..23 (e.g. 21 for 9:00 PM)
  final int windowEndMinute; // 0..59
  final int fixedHour; // 0..23 (e.g. 22 for 10:00 PM)
  final int fixedMinute; // 0..59
  final List<int> daysOfWeek; // 1 = Monday ... 7 = Sunday
  final ReminderPriority priority;
  final bool isSticky; // Persistent / un-dismissible until "Mark Done"
  final ReminderSound soundMode;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReminderConfig({
    required this.id,
    required this.targetType,
    this.targetId,
    required this.title,
    this.description,
    this.triggerType = ReminderTriggerType.fixedTime,
    this.intervalMinutes = 60,
    this.windowStartHour = 9,
    this.windowStartMinute = 0,
    this.windowEndHour = 21,
    this.windowEndMinute = 0,
    this.fixedHour = 10,
    this.fixedMinute = 0,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.priority = ReminderPriority.medium,
    this.isSticky = false,
    this.soundMode = ReminderSound.gentleChime,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Readable schedule summary for UI cards
  String get formattedSchedule {
    if (triggerType == ReminderTriggerType.interval) {
      final startStr = _formatTime(windowStartHour, windowStartMinute);
      final endStr = _formatTime(windowEndHour, windowEndMinute);
      return 'Every ${_formatInterval(intervalMinutes)} ($startStr – $endStr)';
    } else {
      final timeStr = _formatTime(fixedHour, fixedMinute);
      return '${_formatDays(daysOfWeek)} at $timeStr';
    }
  }

  static String _formatInterval(int minutes) {
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    } else if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    } else {
      return '$minutes mins';
    }
  }

  static String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  static String _formatDays(List<int> days) {
    if (days.length == 7) return 'Daily';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Mon-Fri (Weekdays)';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Weekends';
    }
    const dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return days.map((d) => dayLabels[d] ?? '').where((s) => s.isNotEmpty).join(', ');
  }

  /// Checks whether a given [dateTime] falls within the active daily interval window
  bool isWithinActiveWindow(DateTime dateTime) {
    final currentMinutes = dateTime.hour * 60 + dateTime.minute;
    final startMinutes = windowStartHour * 60 + windowStartMinute;
    final endMinutes = windowEndHour * 60 + windowEndMinute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight window (e.g. 21:00 to 03:00)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  /// Calculates the next trigger DateTime based on recurrence/interval rules
  DateTime nextTriggerTime([DateTime? from]) {
    final now = from ?? DateTime.now();

    if (triggerType == ReminderTriggerType.interval) {
      final inWindow = isWithinActiveWindow(now);
      if (inWindow) {
        final next = now.add(Duration(minutes: intervalMinutes));
        if (isWithinActiveWindow(next)) {
          return next;
        }
      }

      // If outside window or next interval exceeds window end, trigger at next window start
      DateTime candidate = DateTime(now.year, now.month, now.day, windowStartHour, windowStartMinute);
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    } else {
      // Fixed time
      DateTime candidate = DateTime(now.year, now.month, now.day, fixedHour, fixedMinute);
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }

      // Find next matching weekday
      for (int i = 0; i < 7; i++) {
        if (daysOfWeek.contains(candidate.weekday)) {
          return candidate;
        }
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target_type': targetType,
      'target_id': targetId,
      'title': title,
      'description': description,
      'trigger_type': triggerType.dbValue,
      'interval_minutes': intervalMinutes,
      'window_start_hour': windowStartHour,
      'window_start_minute': windowStartMinute,
      'window_end_hour': windowEndHour,
      'window_end_minute': windowEndMinute,
      'fixed_hour': fixedHour,
      'fixed_minute': fixedMinute,
      'days_of_week': daysOfWeek.join(','),
      'priority': priority.dbValue,
      'is_sticky': isSticky ? 1 : 0,
      'sound_mode': soundMode.dbValue,
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ReminderConfig.fromMap(Map<String, dynamic> map) {
    List<int> parsedDays = const [1, 2, 3, 4, 5, 6, 7];
    final daysStr = map['days_of_week'] as String?;
    if (daysStr != null && daysStr.isNotEmpty) {
      parsedDays = daysStr
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
      if (parsedDays.isEmpty) parsedDays = const [1, 2, 3, 4, 5, 6, 7];
    }

    return ReminderConfig(
      id: map['id'] as String,
      targetType: map['target_type'] as String? ?? 'standalone',
      targetId: map['target_id'] as String?,
      title: map['title'] as String? ?? 'Reminder',
      description: map['description'] as String?,
      triggerType: ReminderTriggerType.fromDbValue(map['trigger_type'] as String?),
      intervalMinutes: (map['interval_minutes'] as num?)?.toInt() ?? 60,
      windowStartHour: (map['window_start_hour'] as num?)?.toInt() ?? 9,
      windowStartMinute: (map['window_start_minute'] as num?)?.toInt() ?? 0,
      windowEndHour: (map['window_end_hour'] as num?)?.toInt() ?? 21,
      windowEndMinute: (map['window_end_minute'] as num?)?.toInt() ?? 0,
      fixedHour: (map['fixed_hour'] as num?)?.toInt() ?? 10,
      fixedMinute: (map['fixed_minute'] as num?)?.toInt() ?? 0,
      daysOfWeek: parsedDays,
      priority: ReminderPriority.fromDbValue(map['priority'] as String?),
      isSticky: (map['is_sticky'] as num?)?.toInt() == 1,
      soundMode: ReminderSound.fromDbValue(map['sound_mode'] as String?),
      isEnabled: (map['is_enabled'] as num?)?.toInt() != 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMethodChannelMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetType': targetType,
      'targetId': targetId,
      'triggerType': triggerType.dbValue,
      'intervalMinutes': intervalMinutes,
      'windowStartHour': windowStartHour,
      'windowStartMinute': windowStartMinute,
      'windowEndHour': windowEndHour,
      'windowEndMinute': windowEndMinute,
      'fixedHour': fixedHour,
      'fixedMinute': fixedMinute,
      'daysOfWeek': daysOfWeek.join(','),
      'priority': priority.dbValue,
      'isSticky': isSticky,
      'soundMode': soundMode.dbValue,
      'isEnabled': isEnabled,
    };
  }

  ReminderConfig copyWith({
    String? id,
    String? targetType,
    String? targetId,
    String? title,
    String? description,
    ReminderTriggerType? triggerType,
    int? intervalMinutes,
    int? windowStartHour,
    int? windowStartMinute,
    int? windowEndHour,
    int? windowEndMinute,
    int? fixedHour,
    int? fixedMinute,
    List<int>? daysOfWeek,
    ReminderPriority? priority,
    bool? isSticky,
    ReminderSound? soundMode,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderConfig(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      title: title ?? this.title,
      description: description ?? this.description,
      triggerType: triggerType ?? this.triggerType,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      windowStartHour: windowStartHour ?? this.windowStartHour,
      windowStartMinute: windowStartMinute ?? this.windowStartMinute,
      windowEndHour: windowEndHour ?? this.windowEndHour,
      windowEndMinute: windowEndMinute ?? this.windowEndMinute,
      fixedHour: fixedHour ?? this.fixedHour,
      fixedMinute: fixedMinute ?? this.fixedMinute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      priority: priority ?? this.priority,
      isSticky: isSticky ?? this.isSticky,
      soundMode: soundMode ?? this.soundMode,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
