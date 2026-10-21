import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';

class BlockedAppsRepository {
  final DatabaseService _dbService;

  BlockedAppsRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  /// Retrieves list of package names marked as blocked
  Future<List<String>> getBlockedPackageNames() async {
    final db = await _dbService.database;
    final results = await db.query(
      AppTables.blockedApps,
      columns: ['package_name'],
      where: 'is_blocked = 1',
    );
    return results.map((row) => row['package_name'] as String).toList();
  }

  /// Saves the full set of blocked packages, updating existing and inserting new
  Future<void> syncBlockedPackages(Set<String> blockedPackages, Map<String, String> packageNames) async {
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Mark unselected as unblocked
      await txn.update(
        AppTables.blockedApps,
        {'is_blocked': 0},
      );

      // 2. Insert or update selected
      for (final pkg in blockedPackages) {
        final name = packageNames[pkg] ?? pkg;
        await txn.insert(
          AppTables.blockedApps,
          {
            'package_name': pkg,
            'app_name': name,
            'is_blocked': 1,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Toggles an individual app's blocked status
  Future<void> setAppBlocked(String packageName, String appName, bool isBlocked) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.blockedApps,
      {
        'package_name': packageName,
        'app_name': appName,
        'is_blocked': isBlocked ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Logs a distraction interruption event
  Future<void> logInterruption({
    required String? sessionId,
    required String packageName,
    String? appName,
  }) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.focusShieldInterruptions,
      {
        'id': const Uuid().v4(),
        'session_id': sessionId,
        'package_name': packageName,
        'app_name': appName,
        'timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Total distraction interruptions prevented across all sessions
  Future<int> getTotalInterruptionCount() async {
    final db = await _dbService.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.focusShieldInterruptions}'),
    );
    return count ?? 0;
  }
}

final blockedAppsRepositoryProvider = Provider<BlockedAppsRepository>((ref) {
  return BlockedAppsRepository();
});
