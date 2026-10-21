import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../focus/data/focus_repository.dart';
import '../../habits/data/habit_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../domain/daily_consistency_model.dart';

final consistencyMatrixProvider = FutureProvider<ConsistencyMatrixSummary>((ref) async {
  // Watch providers to trigger reactive recalculation
  ref.watch(tasksProvider);
  ref.watch(habitsProvider);
  ref.watch(todayFocusSecondsProvider);
  ref.watch(recentFocusSessionsProvider);

  final db = await DatabaseService.instance.database;
  final now = DateTime.now();
  final todayMidnight = DateTime(now.year, now.month, now.day);
  final start28DaysAgo = todayMidnight.subtract(const Duration(days: 27));

  // 1. Fetch focus seconds grouped by date
  final focusRows = await db.rawQuery('''
    SELECT 
      substr(started_at, 1, 10) AS date_str,
      SUM(completed_seconds) AS total_sec
    FROM ${AppTables.focusSessions}
    WHERE session_type = 'focus' AND started_at >= ?
    GROUP BY date_str
  ''', [start28DaysAgo.toIso8601String()]);

  final Map<String, int> focusMinutesByDate = {};
  for (final row in focusRows) {
    final dateStr = row['date_str'] as String?;
    final sec = (row['total_sec'] as num?)?.toInt() ?? 0;
    if (dateStr != null) {
      focusMinutesByDate[dateStr] = sec ~/ 60;
    }
  }

  // 2. Fetch habit completions grouped by completion_date
  final habitRows = await db.rawQuery('''
    SELECT 
      completion_date,
      COUNT(*) AS total_completions
    FROM ${AppTables.habitCompletions}
    WHERE completion_date >= ?
    GROUP BY completion_date
  ''', [AppDateUtils.toIsoDate(start28DaysAgo)]);

  final Map<String, int> habitsByDate = {};
  for (final row in habitRows) {
    final dateStr = row['completion_date'] as String?;
    final count = (row['total_completions'] as num?)?.toInt() ?? 0;
    if (dateStr != null) {
      habitsByDate[dateStr] = count;
    }
  }

  // 3. Fetch task completions grouped by completed_at date
  final taskRows = await db.rawQuery('''
    SELECT 
      substr(completed_at, 1, 10) AS date_str,
      COUNT(*) AS total_tasks
    FROM ${AppTables.tasks}
    WHERE is_completed = 1 AND completed_at >= ?
    GROUP BY date_str
  ''', [start28DaysAgo.toIso8601String()]);

  final Map<String, int> tasksByDate = {};
  for (final row in taskRows) {
    final dateStr = row['date_str'] as String?;
    final count = (row['total_tasks'] as num?)?.toInt() ?? 0;
    if (dateStr != null) {
      tasksByDate[dateStr] = count;
    }
  }

  // 4. Build exactly 28 days of DailyConsistency items
  final List<DailyConsistency> daysList = [];
  for (int i = 0; i < 28; i++) {
    final currentDay = start28DaysAgo.add(Duration(days: i));
    final iso = AppDateUtils.toIsoDate(currentDay);
    final focusMins = focusMinutesByDate[iso] ?? 0;
    final habitCount = habitsByDate[iso] ?? 0;
    final taskCount = tasksByDate[iso] ?? 0;

    daysList.add(
      DailyConsistency(
        date: currentDay,
        dateIso: iso,
        focusMinutes: focusMins,
        habitsCompleted: habitCount,
        tasksCompleted: taskCount,
      ),
    );
  }

  // 5. Compute current active streak
  // Walk backwards from today; if today has no activity yet, start checking from yesterday
  int currentStreak = 0;
  final reversedDays = daysList.reversed.toList();
  bool isFirst = true;

  for (final day in reversedDays) {
    if (isFirst) {
      isFirst = false;
      if (day.hasActivity) {
        currentStreak++;
      }
      // If today has no activity yet, streak isn't broken if yesterday had activity
      continue;
    }
    if (day.hasActivity) {
      currentStreak++;
    } else {
      break;
    }
  }

  // 6. Compute weekly stats (last 7 days)
  final last7Days = daysList.sublist(21); // indices 21 to 27
  int weeklyFocusMinutes = 0;
  int weeklyHabits = 0;
  int weeklyTasks = 0;

  for (final day in last7Days) {
    weeklyFocusMinutes += day.focusMinutes;
    weeklyHabits += day.habitsCompleted;
    weeklyTasks += day.tasksCompleted;
  }

  final weeklyHours = double.parse((weeklyFocusMinutes / 60.0).toStringAsFixed(1));

  return ConsistencyMatrixSummary(
    days: daysList,
    currentStreak: currentStreak,
    weeklyFocusHours: weeklyHours,
    weeklyHabitsCompleted: weeklyHabits,
    weeklyTasksCompleted: weeklyTasks,
  );
});
