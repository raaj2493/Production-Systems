import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../domain/focus_session_model.dart';

class FocusRepository {
  final DatabaseService _dbService;

  FocusRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<void> logSession(FocusSession session) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.focusSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FocusSession>> getRecentSessions({int limit = 20}) async {
    final db = await _dbService.database;
    final results = await db.rawQuery('''
      SELECT 
        s.*,
        t.title AS task_title,
        g.title AS goal_title
      FROM ${AppTables.focusSessions} s
      LEFT JOIN ${AppTables.tasks} t ON t.id = s.task_id
      LEFT JOIN ${AppTables.goals} g ON g.id = s.goal_id
      ORDER BY s.started_at DESC
      LIMIT ?
    ''', [limit]);

    return results.map((r) => FocusSession.fromMap(r)).toList();
  }

  Future<int> getTodayFocusSeconds() async {
    final db = await _dbService.database;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();

    final result = await db.rawQuery('''
      SELECT SUM(completed_seconds) as total 
      FROM ${AppTables.focusSessions}
      WHERE session_type = 'focus' AND started_at >= ?
    ''', [startOfToday]);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalFocusSeconds() async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT SUM(completed_seconds) as total 
      FROM ${AppTables.focusSessions}
      WHERE session_type = 'focus'
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getFocusSecondsBetween(DateTime start, DateTime end) async {
    final db = await _dbService.database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final result = await db.rawQuery('''
      SELECT SUM(completed_seconds) as total 
      FROM ${AppTables.focusSessions}
      WHERE session_type = 'focus' AND started_at >= ? AND started_at <= ?
    ''', [startStr, endStr]);

    return Sqflite.firstIntValue(result) ?? 0;
  }
}

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  return FocusRepository();
});

final recentFocusSessionsProvider =
    FutureProvider<List<FocusSession>>((ref) async {
  final repo = ref.watch(focusRepositoryProvider);
  return repo.getRecentSessions();
});

final todayFocusSecondsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(focusRepositoryProvider);
  return repo.getTodayFocusSeconds();
});

final todayCompletedFocusSessionsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(focusRepositoryProvider);
  final sessions = await repo.getRecentSessions(limit: 50);
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  return sessions.where((s) => s.sessionType == FocusSessionType.focus && s.isCompleted && s.startedAt.isAfter(startOfToday)).length;
});

