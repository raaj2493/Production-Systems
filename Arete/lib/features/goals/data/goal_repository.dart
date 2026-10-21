import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../domain/goal_model.dart';

class GoalRepository {
  final DatabaseService _dbService;

  GoalRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<List<Goal>> getAllGoals() async {
    final db = await _dbService.database;

    // Query goals along with total and completed task counts
    final results = await db.rawQuery('''
      SELECT 
        g.*,
        COUNT(t.id) AS total_tasks,
        SUM(CASE WHEN t.is_completed = 1 THEN 1 ELSE 0 END) AS completed_tasks
      FROM ${AppTables.goals} g
      LEFT JOIN ${AppTables.tasks} t ON t.goal_id = g.id
      GROUP BY g.id
      ORDER BY g.created_at DESC
    ''');

    return results.map((row) {
      final total = (row['total_tasks'] as num?)?.toInt() ?? 0;
      final completed = (row['completed_tasks'] as num?)?.toInt() ?? 0;
      return Goal.fromMap(row, totalTasks: total, completedTasks: completed);
    }).toList();
  }

  Future<Goal?> getGoalById(String id) async {
    final db = await _dbService.database;
    final results = await db.rawQuery('''
      SELECT 
        g.*,
        COUNT(t.id) AS total_tasks,
        SUM(CASE WHEN t.is_completed = 1 THEN 1 ELSE 0 END) AS completed_tasks
      FROM ${AppTables.goals} g
      LEFT JOIN ${AppTables.tasks} t ON t.goal_id = g.id
      WHERE g.id = ?
      GROUP BY g.id
    ''', [id]);

    if (results.isEmpty) return null;
    final row = results.first;
    final total = (row['total_tasks'] as num?)?.toInt() ?? 0;
    final completed = (row['completed_tasks'] as num?)?.toInt() ?? 0;
    return Goal.fromMap(row, totalTasks: total, completedTasks: completed);
  }

  Future<void> createGoal(Goal goal) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.goals,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateGoal(Goal goal) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.goals,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<void> deleteGoal(String id) async {
    final db = await _dbService.database;
    await db.delete(
      AppTables.goals,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository();
});

class GoalsNotifier extends StateNotifier<AsyncValue<List<Goal>>> {
  final GoalRepository _repository;

  GoalsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadGoals();
  }

  Future<void> loadGoals() async {
    try {
      final goals = await _repository.getAllGoals();
      if (mounted) state = AsyncValue.data(goals);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> addGoal(Goal goal) async {
    await _repository.createGoal(goal);
    await loadGoals();
  }

  Future<void> updateGoal(Goal goal) async {
    await _repository.updateGoal(goal);
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    await _repository.deleteGoal(id);
    await loadGoals();
  }
}

final goalsProvider =
    StateNotifierProvider<GoalsNotifier, AsyncValue<List<Goal>>>((ref) {
  final repo = ref.watch(goalRepositoryProvider);
  return GoalsNotifier(repo);
});
