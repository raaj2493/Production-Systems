import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../goals/data/goal_repository.dart';
import '../../reminders/data/reminder_repository.dart';
import '../domain/task_model.dart';

class TaskRepository {
  final DatabaseService _dbService;

  TaskRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<List<Task>> getAllTasks() async {
    final db = await _dbService.database;
    final results = await db.rawQuery('''
      SELECT 
        t.*,
        g.title AS goal_title,
        g.color AS goal_color
      FROM ${AppTables.tasks} t
      LEFT JOIN ${AppTables.goals} g ON g.id = t.goal_id
      ORDER BY t.is_completed ASC, t.created_at DESC
    ''');
    return results.map((row) => Task.fromMap(row)).toList();
  }

  Future<List<Task>> getTodayTasks() async {
    final db = await _dbService.database;
    final today = AppDateUtils.todayIso;

    final results = await db.rawQuery('''
      SELECT 
        t.*,
        g.title AS goal_title,
        g.color AS goal_color
      FROM ${AppTables.tasks} t
      LEFT JOIN ${AppTables.goals} g ON g.id = t.goal_id
      WHERE t.is_daily_target = 1 OR t.due_date = ? OR t.is_completed = 0 OR (t.is_completed = 1 AND t.completed_at >= ?)
      ORDER BY t.is_completed ASC, t.is_daily_target DESC, t.created_at DESC
    ''', [today, '$today 00:00:00']);

    return results.map((row) => Task.fromMap(row)).toList();
  }

  Future<List<Task>> getTasksByGoal(String goalId) async {
    final db = await _dbService.database;
    final results = await db.rawQuery('''
      SELECT 
        t.*,
        g.title AS goal_title,
        g.color AS goal_color
      FROM ${AppTables.tasks} t
      LEFT JOIN ${AppTables.goals} g ON g.id = t.goal_id
      WHERE t.goal_id = ?
      ORDER BY t.is_completed ASC, t.created_at ASC
    ''', [goalId]);
    return results.map((row) => Task.fromMap(row)).toList();
  }

  Future<void> createTask(Task task) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.tasks,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTask(Task task) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.tasks,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> toggleTaskCompletion(String id) async {
    final db = await _dbService.database;
    final current = await db.query(
      AppTables.tasks,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (current.isEmpty) return;

    final isCompleted = (current.first['is_completed'] as int? ?? 0) == 1;
    final newCompleted = !isCompleted;
    final now = DateTime.now();

    await db.update(
      AppTables.tasks,
      {
        'is_completed': newCompleted ? 1 : 0,
        'completed_at': newCompleted ? now.toIso8601String() : null,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await _dbService.database;
    await db.delete(
      AppTables.tasks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getCompletedCountBetween(DateTime start, DateTime end) async {
    final db = await _dbService.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${AppTables.tasks} 
      WHERE is_completed = 1 AND completed_at >= ? AND completed_at <= ?
    ''', [startStr, endStr]);

    return Sqflite.firstIntValue(result) ?? 0;
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

class TasksNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskRepository _repository;
  final Ref _ref;

  TasksNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      final tasks = await _repository.getAllTasks();
      if (mounted) state = AsyncValue.data(tasks);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTask(Task task) async {
    await _repository.createTask(task);
    await loadTasks();
    _ref.invalidate(goalsProvider);
  }

  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task);
    await loadTasks();
    _ref.invalidate(goalsProvider);
  }

  Future<void> toggleTask(String id) async {
    await _repository.toggleTaskCompletion(id);
    await loadTasks();
    _ref.invalidate(goalsProvider);
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await ReminderRepository().deleteRemindersForTarget('task', id);
    await loadTasks();
    _ref.invalidate(goalsProvider);
  }
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, AsyncValue<List<Task>>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return TasksNotifier(repo, ref);
});

final todayTasksProvider = Provider<List<Task>>((ref) {
  final tasksState = ref.watch(tasksProvider);
  final today = AppDateUtils.todayIso;

  return tasksState.maybeWhen(
    data: (tasks) {
      final filtered = tasks.where((t) {
        // 1. Explicitly designated as daily target
        if (t.isDailyTarget) return true;
        // 2. Scheduled for today
        if (t.dueDate == today) return true;
        // 3. Active tasks (uncompleted) automatically synced to Today dashboard
        if (!t.isCompleted) return true;
        // 4. Tasks completed today remain visible on Today dashboard
        if (t.isCompleted && t.completedAt != null) {
          final completedIso = AppDateUtils.toIsoDate(t.completedAt!);
          if (completedIso == today) return true;
        }
        return false;
      }).toList();

      // Prioritize active daily targets first, then active tasks, then completed
      filtered.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (a.isDailyTarget != b.isDailyTarget) {
          return a.isDailyTarget ? -1 : 1;
        }
        if (a.dueDate != null && b.dueDate != null) {
          final dateComp = a.dueDate!.compareTo(b.dueDate!);
          if (dateComp != 0) return dateComp;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      return filtered;
    },
    orElse: () => [],
  );
});

class TaskVelocityStats {
  final int completedToday;
  final int activeCount;
  final int totalToday;
  final double completionRate;
  final double sevenDayAvg;
  final String velocityLabel;

  const TaskVelocityStats({
    required this.completedToday,
    required this.activeCount,
    required this.totalToday,
    required this.completionRate,
    required this.sevenDayAvg,
    required this.velocityLabel,
  });
}

final taskVelocityStatsProvider = Provider<TaskVelocityStats>((ref) {
  final todayTasks = ref.watch(todayTasksProvider);
  final allTasksAsync = ref.watch(tasksProvider);

  final completedToday = todayTasks.where((t) => t.isCompleted).length;
  final totalToday = todayTasks.length;
  final activeCount = todayTasks.where((t) => !t.isCompleted).length;
  final completionRate = totalToday > 0 ? (completedToday / totalToday) : 0.0;

  double sevenDayAvg = 0.0;
  allTasksAsync.whenData((tasks) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final completedLast7Days = tasks.where((t) {
      if (!t.isCompleted || t.completedAt == null) return false;
      return t.completedAt!.isAfter(sevenDaysAgo);
    }).length;
    sevenDayAvg = double.parse((completedLast7Days / 7.0).toStringAsFixed(1));
  });

  String label;
  if (totalToday == 0) {
    label = 'Clean Slate';
  } else if (completedToday == totalToday && completedToday > 0) {
    label = '⚡ 100% Velocity • Target Achieved';
  } else if (completionRate >= 0.66) {
    label = '🔥 High Velocity • Finishing Strong';
  } else if (completionRate > 0) {
    label = '🌱 In Motion • Step by Step';
  } else {
    label = '⚡ Ready for Sprint • Let’s Focus';
  }

  return TaskVelocityStats(
    completedToday: completedToday,
    activeCount: activeCount,
    totalToday: totalToday,
    completionRate: completionRate,
    sevenDayAvg: sevenDayAvg,
    velocityLabel: label,
  );
});

