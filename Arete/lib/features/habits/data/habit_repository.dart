import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../reminders/data/reminder_repository.dart';
import '../domain/habit_completion_model.dart';
import '../domain/habit_model.dart';

class HabitRepository {
  final DatabaseService _dbService;

  HabitRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<List<Habit>> getAllHabits({bool includeArchived = false}) async {
    final db = await _dbService.database;
    final String whereClause = includeArchived ? '' : 'WHERE archived_at IS NULL';

    final results = await db.rawQuery('''
      SELECT * FROM ${AppTables.habits}
      $whereClause
      ORDER BY created_at ASC
    ''');

    final today = AppDateUtils.todayIso;
    final List<Habit> habits = [];

    for (final row in results) {
      final habitId = row['id'] as String;
      final completions = await getCompletionsForHabit(habitId);
      final completionDates = completions.map((c) => c.completionDate).toSet();

      final baseHabit = Habit.fromMap(row);
      final isCompletedToday = completionDates.contains(today);
      final currentStreak = calculateCurrentStreak(baseHabit, completionDates);
      final bestStreak = calculateBestStreak(baseHabit, completionDates);

      habits.add(
        baseHabit.copyWith(
          isCompletedToday: isCompletedToday,
          currentStreak: currentStreak,
          bestStreak: bestStreak,
        ),
      );
    }

    return habits;
  }

  Future<List<HabitCompletion>> getCompletionsForHabit(String habitId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      AppTables.habitCompletions,
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'completion_date ASC',
    );
    return rows.map((r) => HabitCompletion.fromMap(r)).toList();
  }

  /// Returns a map of completion counts per date for the last [days] days
  Future<Map<String, int>> getHeatmapData(int days) async {
    final db = await _dbService.database;
    final cutoff = AppDateUtils.toIsoDate(
      DateTime.now().subtract(Duration(days: days)),
    );

    final rows = await db.rawQuery('''
      SELECT completion_date, COUNT(*) as count
      FROM ${AppTables.habitCompletions}
      WHERE completion_date >= ?
      GROUP BY completion_date
    ''', [cutoff]);

    final Map<String, int> map = {};
    for (final row in rows) {
      map[row['completion_date'] as String] = (row['count'] as num).toInt();
    }
    return map;
  }

  Future<void> createHabit(Habit habit) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.habits,
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateHabit(Habit habit) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.habits,
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<void> deleteHabit(String id) async {
    final db = await _dbService.database;
    await db.delete(
      AppTables.habits,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> toggleCompletion(String habitId, String dateIso) async {
    final db = await _dbService.database;
    final existing = await db.query(
      AppTables.habitCompletions,
      where: 'habit_id = ? AND completion_date = ?',
      whereArgs: [habitId, dateIso],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.delete(
        AppTables.habitCompletions,
        where: 'habit_id = ? AND completion_date = ?',
        whereArgs: [habitId, dateIso],
      );
      return false; // Removed
    } else {
      await db.insert(
        AppTables.habitCompletions,
        {
          'id': const Uuid().v4(),
          'habit_id': habitId,
          'completion_date': dateIso,
          'completed_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true; // Added
    }
  }

  /// Calculates current streak respecting non-scheduled days without breaking artificially
  static int calculateCurrentStreak(Habit habit, Set<String> completionDates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = AppDateUtils.toIsoDate(today);

    int streak = 0;
    DateTime checkDate;

    if (completionDates.contains(todayIso)) {
      streak = 1;
      checkDate = today.subtract(const Duration(days: 1));
    } else {
      // If today is not completed yet, the streak is not broken if today is still in progress,
      // or if today was not a scheduled day.
      checkDate = today.subtract(const Duration(days: 1));
    }

    // Go back up to 365 days
    for (int i = 0; i < 365; i++) {
      if (!habit.isScheduledForDate(checkDate)) {
        // Non-scheduled day: does NOT break the streak
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      final dateIso = AppDateUtils.toIsoDate(checkDate);
      if (completionDates.contains(dateIso)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        // Scheduled day missing completion breaks the streak!
        break;
      }
    }

    return streak;
  }

  /// Calculates all-time best streak respecting non-scheduled days
  static int calculateBestStreak(Habit habit, Set<String> completionDates) {
    if (completionDates.isEmpty) return 0;

    final sortedDates = completionDates.map(AppDateUtils.parseIsoDate).toList()
      ..sort((a, b) => a.compareTo(b));

    if (sortedDates.isEmpty) return 0;

    DateTime current = sortedDates.first;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int maxStreak = 0;
    int currentStreak = 0;

    while (!current.isAfter(today)) {
      if (!habit.isScheduledForDate(current)) {
        // Skip non-scheduled day without resetting streak
        current = current.add(const Duration(days: 1));
        continue;
      }

      final dateIso = AppDateUtils.toIsoDate(current);
      if (completionDates.contains(dateIso)) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }

      current = current.add(const Duration(days: 1));
    }

    return maxStreak;
  }
}

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository();
});

class HabitsNotifier extends StateNotifier<AsyncValue<List<Habit>>> {
  final HabitRepository _repository;

  HabitsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadHabits();
  }

  Future<void> loadHabits() async {
    try {
      final habits = await _repository.getAllHabits();
      if (mounted) state = AsyncValue.data(habits);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> addHabit(Habit habit) async {
    await _repository.createHabit(habit);
    await loadHabits();
  }

  Future<void> updateHabit(Habit habit) async {
    await _repository.updateHabit(habit);
    await loadHabits();
  }

  Future<void> deleteHabit(String id) async {
    await _repository.deleteHabit(id);
    await ReminderRepository().deleteRemindersForTarget('habit', id);
    await loadHabits();
  }

  Future<void> toggleHabitCompletion(String habitId, [String? dateIso]) async {
    final targetDate = dateIso ?? AppDateUtils.todayIso;
    await _repository.toggleCompletion(habitId, targetDate);
    await loadHabits();
  }

  void reorderHabits(int oldIndex, int newIndex) {
    state.whenData((currentList) {
      final list = List<Habit>.from(currentList);
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      state = AsyncValue.data(list);
    });
  }
}

final habitsProvider =
    StateNotifierProvider<HabitsNotifier, AsyncValue<List<Habit>>>((ref) {
  final repo = ref.watch(habitRepositoryProvider);
  return HabitsNotifier(repo);
});

final todayHabitsProvider = Provider<List<Habit>>((ref) {
  final habitsState = ref.watch(habitsProvider);
  final now = DateTime.now();

  return habitsState.maybeWhen(
    data: (habits) => habits.where((h) => h.isScheduledForDate(now)).toList(),
    orElse: () => [],
  );
});

final heatmapDataProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(habitRepositoryProvider);
  ref.watch(habitsProvider); // reload when habits change
  return repo.getHeatmapData(30);
});
