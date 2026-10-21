import '../../../core/utils/date_utils.dart';

class DailyConsistency {
  final DateTime date;
  final String dateIso;
  final int focusMinutes;
  final int habitsCompleted;
  final int tasksCompleted;

  const DailyConsistency({
    required this.date,
    required this.dateIso,
    this.focusMinutes = 0,
    this.habitsCompleted = 0,
    this.tasksCompleted = 0,
  });

  bool get hasActivity => focusMinutes > 0 || habitsCompleted > 0 || tasksCompleted > 0;

  bool get isToday => AppDateUtils.isSameDay(date, DateTime.now());

  /// Pastel Color Density Scale:
  /// 0 = 0m (light ceramic container)
  /// 1 = 1-29m or habit/task activity (soft sage)
  /// 2 = 30m+ (light sage #D2E8D4)
  /// 3 = 60m+ (medium forest #4D7C5D)
  /// 4 = 120m+ (deep olive #1B3623)
  int get intensityLevel {
    if (focusMinutes >= 120) return 4;
    if (focusMinutes >= 60) return 3;
    if (focusMinutes >= 30) return 2;
    if (focusMinutes > 0 || habitsCompleted > 0 || tasksCompleted > 0) return 1;
    return 0;
  }

  String get formattedFocusTime {
    if (focusMinutes == 0) return '0 mins';
    final hours = focusMinutes ~/ 60;
    final mins = focusMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  String get dayStatusBadge {
    if (focusMinutes >= 120) return '⚡ Deep Work Master';
    if (focusMinutes >= 60) return '🔥 High Momentum';
    if (focusMinutes >= 30) return '🌱 Consistent Focus';
    if (hasActivity) return '✓ Daily Progress';
    return 'Rest & Recharge';
  }
}

class ConsistencyMatrixSummary {
  final List<DailyConsistency> days; // 28 days
  final int currentStreak;
  final double weeklyFocusHours;
  final int weeklyHabitsCompleted;
  final int weeklyTasksCompleted;

  const ConsistencyMatrixSummary({
    required this.days,
    required this.currentStreak,
    required this.weeklyFocusHours,
    required this.weeklyHabitsCompleted,
    required this.weeklyTasksCompleted,
  });
}
