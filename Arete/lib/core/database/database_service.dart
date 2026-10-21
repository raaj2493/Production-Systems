import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_factory_stub.dart'
    if (dart.library.js_interop) 'db_factory_web.dart'
    if (dart.library.ffi) 'db_factory_desktop.dart';
import 'migrations.dart';
import 'tables.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await initDatabase();
    return _db!;
  }

  /// Initialize SQLite database. Supports in-memory database for testing and web database for Chrome.
  Future<Database> initDatabase({bool inMemory = false}) async {
    setupDatabaseFactory();

    String path;
    if (inMemory) {
      path = inMemoryDatabasePath;
    } else if (kIsWeb) {
      path = 'arete_web.db';
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      path = p.join(docsDir.path, 'arete.db');
    }

    final db = await openDatabase(
      path,
      version: DatabaseMigrations.currentVersion,
      onConfigure: DatabaseMigrations.onConfigure,
      onCreate: DatabaseMigrations.onCreate,
      onUpgrade: DatabaseMigrations.onUpgrade,
    );

    _db = db;
    return db;
  }

  /// Explicitly set an existing or mock database (useful for unit tests)
  void setDatabase(Database db) {
    _db = db;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Atomically wipe all tables
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(AppTables.learningRoadmapTopics);
      await txn.delete(AppTables.learningRoadmapPhases);
      await txn.delete(AppTables.learningRoadmaps);
      await txn.delete(AppTables.dsaProblems);
      await txn.delete(AppTables.learningProjects);
      await txn.delete(AppTables.learningProfile);
      await txn.delete(AppTables.learningCategories);
      await txn.delete(AppTables.habitCompletions);
      await txn.delete(AppTables.habits);
      await txn.delete(AppTables.focusSessions);
      await txn.delete(AppTables.notes);
      await txn.delete(AppTables.learningResources);
      await txn.delete(AppTables.learningCollections);
      await txn.delete(AppTables.tasks);
      await txn.delete(AppTables.goals);
      await txn.delete(AppTables.tags);
      await txn.delete(AppTables.blockedApps);
      await txn.delete(AppTables.focusShieldInterruptions);
    });
  }

  /// Exports all tables to a clean JSON string with version metadata
  Future<String> exportToJson() async {
    final db = await database;
    final Map<String, dynamic> exportData = {
      'app': 'Areté',
      'version': DatabaseMigrations.currentVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': {},
    };

    final tables = [
      AppTables.goals,
      AppTables.tasks,
      AppTables.habits,
      AppTables.habitCompletions,
      AppTables.focusSessions,
      AppTables.learningCollections,
      AppTables.learningResources,
      AppTables.notes,
      AppTables.tags,
      AppTables.learningCategories,
      AppTables.learningRoadmaps,
      AppTables.learningRoadmapPhases,
      AppTables.learningRoadmapTopics,
      AppTables.dsaProblems,
      AppTables.learningProjects,
      AppTables.learningProfile,
    ];

    final tablesMap = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      final rows = await db.query(table);
      tablesMap[table] = rows;
    }

    exportData['tables'] = tablesMap;
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Validates and imports data atomically from JSON
  Future<bool> importFromJson(String jsonString, {bool replaceExisting = false}) async {
    try {
      String cleanJson = jsonString.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final dynamic decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) return false;

      // Validate app identifier if present
      if (decoded.containsKey('app')) {
        final appName = decoded['app'].toString().toLowerCase();
        if (appName != 'areté' && appName != 'arete') {
          return false;
        }
      }

      Map<String, dynamic> tables;
      if (decoded.containsKey('tables') && decoded['tables'] is Map<String, dynamic>) {
        tables = decoded['tables'] as Map<String, dynamic>;
      } else {
        // Direct table map (friendly AI export)
        tables = decoded;
      }

      const recognizedTables = [
        AppTables.goals,
        AppTables.learningCollections,
        AppTables.learningResources,
        AppTables.tasks,
        AppTables.habits,
        AppTables.habitCompletions,
        AppTables.focusSessions,
        AppTables.notes,
        AppTables.tags,
        AppTables.learningCategories,
        AppTables.learningRoadmaps,
        AppTables.learningRoadmapPhases,
        AppTables.learningRoadmapTopics,
        AppTables.dsaProblems,
        AppTables.learningProjects,
        AppTables.learningProfile,
      ];

      final hasValidTables = recognizedTables.any((t) => tables.containsKey(t) && tables[t] is List);
      if (!hasValidTables) {
        return false;
      }

      final db = await database;
      await db.transaction((txn) async {
        if (replaceExisting) {
          await txn.delete(AppTables.habitCompletions);
          await txn.delete(AppTables.habits);
          await txn.delete(AppTables.focusSessions);
          await txn.delete(AppTables.notes);
          await txn.delete(AppTables.learningResources);
          await txn.delete(AppTables.learningCollections);
          await txn.delete(AppTables.tasks);
          await txn.delete(AppTables.goals);
          await txn.delete(AppTables.tags);
          await txn.delete(AppTables.learningProjects);
          await txn.delete(AppTables.dsaProblems);
          await txn.delete(AppTables.learningRoadmapTopics);
          await txn.delete(AppTables.learningRoadmapPhases);
          await txn.delete(AppTables.learningRoadmaps);
          await txn.delete(AppTables.learningCategories);
          await txn.delete(AppTables.learningProfile);
        }

        // Ordered insertion respecting foreign keys
        final tableOrder = [
          AppTables.goals,
          AppTables.learningCollections,
          AppTables.learningResources,
          AppTables.tasks,
          AppTables.habits,
          AppTables.habitCompletions,
          AppTables.focusSessions,
          AppTables.notes,
          AppTables.tags,
          AppTables.learningCategories,
          AppTables.learningRoadmaps,
          AppTables.learningRoadmapPhases,
          AppTables.learningRoadmapTopics,
          AppTables.dsaProblems,
          AppTables.learningProjects,
          AppTables.learningProfile,
        ];

        final nowIso = DateTime.now().toIso8601String();

        for (final table in tableOrder) {
          if (tables.containsKey(table) && tables[table] is List) {
            // Query table schema dynamically to strip any unsupported columns
            final tableInfo = await txn.rawQuery('PRAGMA table_info($table)');
            final validColumns = tableInfo.map((col) => col['name'] as String).toSet();

            final List rows = tables[table];
            for (final rawRow in rows) {
              if (rawRow is Map<String, dynamic>) {
                final Map<String, dynamic> row = Map.from(rawRow);

                // Auto-fill required timestamps if table supports them and they are missing
                if (validColumns.contains('created_at') && !row.containsKey('created_at')) {
                  row['created_at'] = nowIso;
                }
                if (validColumns.contains('updated_at') && !row.containsKey('updated_at')) {
                  row['updated_at'] = nowIso;
                }

                // Strip any columns that do not exist in this SQLite table
                row.removeWhere((key, _) => !validColumns.contains(key));

                // Normalize booleans to SQLite integers (1 / 0)
                row.forEach((key, val) {
                  if (val is bool) {
                    row[key] = val ? 1 : 0;
                  }
                });

                await txn.insert(
                  table,
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error importing JSON: $e');
      return false;
    }
  }

  /// Seeds friendly starter data for fresh installs
  Future<void> seedStarterData() async {
    try {
      final db = await database;
      final taskCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.tasks}'),
      );
      final goalCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.goals}'),
      );

      if ((taskCount != null && taskCount > 0) || (goalCount != null && goalCount > 0)) {
        return; // Data already exists
      }

      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await db.transaction((txn) async {
        // 1. Goal
        const goalId = 'goal-seed-1';
        await txn.insert(
          AppTables.goals,
          {
            'id': goalId,
            'title': 'Master Mobile Architecture',
            'description': 'Deep dive into clean architecture, local offline-first persistence, and calm UI.',
            'color': '#6E8B74',
            'target_date': now.add(const Duration(days: 30)).toIso8601String(),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 2. Tasks
        await txn.insert(
          AppTables.tasks,
          {
            'id': 'task-seed-1',
            'goal_id': goalId,
            'title': 'Explore Areté design philosophy',
            'description': 'Keep your word: less planning, more doing, calm and intentional.',
            'due_date': today,
            'is_completed': 1,
            'completed_at': now.toIso8601String(),
            'is_daily_target': 1,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        await txn.insert(
          AppTables.tasks,
          {
            'id': 'task-seed-2',
            'goal_id': goalId,
            'title': 'Complete a 25-minute deep focus block',
            'description': 'Use the Focus Timer tab to work uninterrupted.',
            'due_date': today,
            'is_completed': 0,
            'completed_at': null,
            'is_daily_target': 1,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        await txn.insert(
          AppTables.tasks,
          {
            'id': 'task-seed-3',
            'goal_id': null,
            'title': 'Review weekly learning roadmap',
            'description': 'Browse through the Learn tab collections.',
            'due_date': today,
            'is_completed': 0,
            'completed_at': null,
            'is_daily_target': 1,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 3. Habits
        const habitId1 = 'habit-seed-1';
        await txn.insert(
          AppTables.habits,
          {
            'id': habitId1,
            'title': 'Morning Deep Work (45m)',
            'description': 'Dedicate first hour of daylight to primary priority.',
            'frequency_type': 'daily',
            'custom_days': null,
            'color': '#6E8B74',
            'created_at': now.toIso8601String(),
            'archived_at': null,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        const habitId2 = 'habit-seed-2';
        await txn.insert(
          AppTables.habits,
          {
            'id': habitId2,
            'title': 'Evening Reflection & Reading',
            'description': '15 minutes of uninterrupted reading before sleep.',
            'frequency_type': 'weekdays',
            'custom_days': jsonEncode([1, 2, 3, 4, 5]),
            'color': '#D99B52',
            'created_at': now.toIso8601String(),
            'archived_at': null,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // Check-in habit 1 for today
        await txn.insert(
          AppTables.habitCompletions,
          {
            'id': 'comp-seed-1',
            'habit_id': habitId1,
            'completion_date': today,
            'completed_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 4. Focus Session history (yesterday and today)
        await txn.insert(
          AppTables.focusSessions,
          {
            'id': 'focus-seed-1',
            'task_id': 'task-seed-1',
            'goal_id': goalId,
            'session_type': 'focus',
            'duration_seconds': 1500,
            'completed_seconds': 1500,
            'is_completed': 1,
            'started_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
            'ended_at': now.subtract(const Duration(hours: 2, minutes: 35)).toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 5. Learning Collection & Resources
        const collectionId = 'col-seed-1';
        await txn.insert(
          AppTables.learningCollections,
          {
            'id': collectionId,
            'title': 'Core Systems & Foundations',
            'description': 'Essential mental models, computer science fundamentals, and architecture.',
            'color': '#6B8FB5',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        await txn.insert(
          AppTables.learningResources,
          {
            'id': 'res-seed-1',
            'collection_id': collectionId,
            'title': 'Deep Work: Rules for Focused Success',
            'url': 'https://calnewport.com/deep-work/',
            'resource_type': 'book',
            'description': 'The ability to perform deep work is becoming increasingly rare at exactly the same time it is becoming increasingly valuable.',
            'topic': 'Focus & Intentionality',
            'status': 'in_progress',
            'progress_percentage': 50,
            'notes': 'Embrace boredom, quit shallow obligations, cultivate craftsmanship.',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        await txn.insert(
          AppTables.learningResources,
          {
            'id': 'res-seed-2',
            'collection_id': collectionId,
            'title': 'Things 3 Design Philosophy',
            'url': 'https://culturedcode.com/things/',
            'resource_type': 'article',
            'description': 'The elegance of restrained interaction design and calm hierarchy.',
            'topic': 'Product Design',
            'status': 'completed',
            'progress_percentage': 100,
            'notes': 'Clarity over clutter. White space gives thoughts room to breathe.',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 6. Notes
        await txn.insert(
          AppTables.notes,
          {
            'id': 'note-seed-1',
            'title': 'Three Daily Questions',
            'body': '1. What matters to me?\n2. What should I do today?\n3. Am I becoming more consistent?\n\nAreté means moral virtue and excellence in fulfilling purpose. Small daily wins compound into life-changing results.',
            'is_pinned': 1,
            'goal_id': goalId,
            'resource_id': null,
            'tags': 'philosophy,core,arete',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      });
    } catch (e) {
      debugPrint('Failed to seed starter data: $e');
    }
  }
}
