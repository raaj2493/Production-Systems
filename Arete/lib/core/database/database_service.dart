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

class ImportResult {
  final bool success;
  final String? error;
  final int totalCount;
  final Map<String, int> tableCounts;

  const ImportResult({
    required this.success,
    this.error,
    this.totalCount = 0,
    this.tableCounts = const {},
  });

  String get summary {
    if (!success) return error ?? 'Import failed';
    if (totalCount == 0) return 'No items found to import';
    final parts = <String>[];
    tableCounts.forEach((table, count) {
      if (count > 0) {
        final readable = table.replaceAll('_', ' ');
        parts.add('$count $readable');
      }
    });
    return 'Successfully imported: ${parts.join(', ')}';
  }
}

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

  /// Ordered table dependency list respecting foreign key hierarchies
  static const List<String> _tableOrder = [
    AppTables.goals,
    AppTables.learningCategories,
    AppTables.learningCollections,
    AppTables.learningResources,
    AppTables.tasks,
    AppTables.habits,
    AppTables.habitCompletions,
    AppTables.focusSessions,
    AppTables.notes,
    AppTables.tags,
    AppTables.learningRoadmaps,
    AppTables.learningRoadmapPhases,
    AppTables.learningRoadmapTopics,
    AppTables.dsaProblems,
    AppTables.learningProjects,
    AppTables.learningProfile,
  ];

  /// Recognized aliases from AI model outputs (singulars, abbreviations, colloquial names)
  static const Map<String, String> _tableAliases = {
    'goals': AppTables.goals,
    'goal': AppTables.goals,
    'tasks': AppTables.tasks,
    'task': AppTables.tasks,
    'todos': AppTables.tasks,
    'todo': AppTables.tasks,
    'habits': AppTables.habits,
    'habit': AppTables.habits,
    'habit_completions': AppTables.habitCompletions,
    'habit_completion': AppTables.habitCompletions,
    'focus_sessions': AppTables.focusSessions,
    'focus_session': AppTables.focusSessions,
    'focus': AppTables.focusSessions,
    'sessions': AppTables.focusSessions,
    'learning_collections': AppTables.learningCollections,
    'learning_collection': AppTables.learningCollections,
    'collections': AppTables.learningCollections,
    'collection': AppTables.learningCollections,
    'learning_resources': AppTables.learningResources,
    'learning_resource': AppTables.learningResources,
    'resources': AppTables.learningResources,
    'resource': AppTables.learningResources,
    'notes': AppTables.notes,
    'note': AppTables.notes,
    'tags': AppTables.tags,
    'tag': AppTables.tags,
    'learning_categories': AppTables.learningCategories,
    'learning_category': AppTables.learningCategories,
    'categories': AppTables.learningCategories,
    'category': AppTables.learningCategories,
    'learning_roadmaps': AppTables.learningRoadmaps,
    'learning_roadmap': AppTables.learningRoadmaps,
    'roadmaps': AppTables.learningRoadmaps,
    'roadmap': AppTables.learningRoadmaps,
    'learning_roadmap_phases': AppTables.learningRoadmapPhases,
    'phases': AppTables.learningRoadmapPhases,
    'learning_roadmap_topics': AppTables.learningRoadmapTopics,
    'topics': AppTables.learningRoadmapTopics,
    'dsa_problems': AppTables.dsaProblems,
    'dsa': AppTables.dsaProblems,
    'problems': AppTables.dsaProblems,
    'learning_projects': AppTables.learningProjects,
    'projects': AppTables.learningProjects,
    'learning_profile': AppTables.learningProfile,
  };

  /// Robust JSON payload extractor that cleans conversational preambles, markdown backticks,
  /// and trailing text generated by ChatGPT / Gemini.
  static String extractJsonPayload(String raw) {
    String text = raw.trim();
    if (text.isEmpty) return text;

    // 1. Markdown code block ```json ... ``` or ``` ... ```
    final codeBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
    final matches = codeBlockRegex.allMatches(text);
    if (matches.isNotEmpty) {
      for (final match in matches) {
        final candidate = match.group(1)?.trim();
        if (candidate != null && (candidate.startsWith('{') || candidate.startsWith('['))) {
          text = candidate;
          break;
        }
      }
    }

    // 2. Slice outermost curly braces { ... } if conversational text surrounds it
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      text = text.substring(firstBrace, lastBrace + 1).trim();
    }

    return text;
  }

  /// Decodes JSON with automatic trailing comma repair commonly output by LLMs
  static dynamic decodeJsonWithFallbacks(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      // Remove trailing commas before closing braces/brackets (loop handles nested trailing commas)
      String sanitized = text;
      for (int i = 0; i < 3; i++) {
        final next = sanitized.replaceAllMapped(
          RegExp(r',\s*([\]}])'),
          (match) => match.group(1) ?? '',
        );
        if (next == sanitized) break;
        sanitized = next;
      }
      return jsonDecode(sanitized);
    }
  }

  /// Validates and imports data atomically from JSON with rich error feedback and alias resolution
  Future<ImportResult> importFromJsonDetailed(String jsonString, {bool replaceExisting = false}) async {
    try {
      final cleanJson = extractJsonPayload(jsonString);
      if (cleanJson.isEmpty) {
        return const ImportResult(
          success: false,
          error: 'Empty JSON content provided. Please paste the configuration text.',
        );
      }

      dynamic decoded;
      try {
        decoded = decodeJsonWithFallbacks(cleanJson);
      } catch (e) {
        return ImportResult(
          success: false,
          error: 'Could not parse JSON format. Please ensure the copied block is valid JSON: $e',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        return const ImportResult(
          success: false,
          error: 'Expected a JSON object containing workspace tables or data.',
        );
      }

      // Check app identifier if explicitly provided
      if (decoded.containsKey('app')) {
        final appName = decoded['app'].toString().toLowerCase().trim();
        if (!appName.contains('arete') && !appName.contains('areté')) {
          return ImportResult(
            success: false,
            error: 'JSON belongs to an unrecognized application ("$appName").',
          );
        }
      }

      Map<String, dynamic> rawTables;
      if (decoded.containsKey('tables') && decoded['tables'] is Map<String, dynamic>) {
        rawTables = decoded['tables'] as Map<String, dynamic>;
      } else {
        rawTables = decoded;
      }

      // Normalize table names and collect rows
      final Map<String, List<Map<String, dynamic>>> normalizedTables = {};

      rawTables.forEach((key, value) {
        final lowerKey = key.toLowerCase().trim();
        final canonicalTable = _tableAliases[lowerKey] ?? lowerKey;

        if (_tableOrder.contains(canonicalTable)) {
          final List<Map<String, dynamic>> rows = [];
          if (value is List) {
            for (final item in value) {
              if (item is Map) {
                rows.add(Map<String, dynamic>.from(item));
              }
            }
          } else if (value is Map) {
            rows.add(Map<String, dynamic>.from(value));
          }

          if (rows.isNotEmpty) {
            normalizedTables.putIfAbsent(canonicalTable, () => []).addAll(rows);
          }
        }
      });

      if (normalizedTables.isEmpty) {
        return const ImportResult(
          success: false,
          error: 'No recognized workspace items found. Ensure JSON contains goals, tasks, habits, or collections.',
        );
      }

      final db = await database;
      final Map<String, int> tableCounts = {};
      int totalInserted = 0;

      // Temporarily disable foreign keys during bulk import so circular or dangling references don't abort
      await db.execute('PRAGMA foreign_keys = OFF;');

      try {
        await db.transaction((txn) async {
          if (replaceExisting) {
            for (final table in _tableOrder.reversed) {
              await txn.delete(table);
            }
          }

          final now = DateTime.now();
          final nowIso = now.toIso8601String();
          final todayDateIso = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

          for (final table in _tableOrder) {
            if (!normalizedTables.containsKey(table)) continue;

            final tableInfo = await txn.rawQuery('PRAGMA table_info($table)');
            final validColumns = tableInfo.map((col) => col['name'] as String).toSet();
            final notNullColumns = tableInfo
                .where((col) => (col['notnull'] as int?) == 1 && col['dflt_value'] == null)
                .map((col) => col['name'] as String)
                .toSet();

            final List<Map<String, dynamic>> rows = normalizedTables[table]!;
            int countForTable = 0;

            for (int i = 0; i < rows.length; i++) {
              final Map<String, dynamic> row = Map.from(rows[i]);

              // 1. Auto-generate primary key ID if missing or blank
              if (validColumns.contains('id')) {
                if (!row.containsKey('id') || row['id'] == null || row['id'].toString().trim().isEmpty) {
                  row['id'] = '${table}_${now.microsecondsSinceEpoch}_$i';
                } else {
                  row['id'] = row['id'].toString();
                }
              }

              // 2. Perform table-specific alias and format normalizations
              _normalizeRowForTable(table, row, nowIso, todayDateIso);

              // 3. Auto-fill required timestamps if table supports them
              if (validColumns.contains('created_at') && (!row.containsKey('created_at') || row['created_at'] == null)) {
                row['created_at'] = nowIso;
              }
              if (validColumns.contains('updated_at') && (!row.containsKey('updated_at') || row['updated_at'] == null)) {
                row['updated_at'] = nowIso;
              }

              // 4. Strip any columns that do not exist in this SQLite table
              row.removeWhere((key, _) => !validColumns.contains(key));

              // 5. Normalize booleans to SQLite integers (1 / 0)
              row.forEach((key, val) {
                if (val is bool) {
                  row[key] = val ? 1 : 0;
                }
              });

              // 6. Guarantee NOT NULL columns have valid fallbacks
              _ensureNotNullFields(table, row, notNullColumns, nowIso, todayDateIso);

              await txn.insert(
                table,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              countForTable++;
            }

            if (countForTable > 0) {
              tableCounts[table] = countForTable;
              totalInserted += countForTable;
            }
          }
        });

        return ImportResult(
          success: true,
          totalCount: totalInserted,
          tableCounts: tableCounts,
        );
      } catch (e, stack) {
        debugPrint('Error importing JSON into SQLite: $e\n$stack');
        return ImportResult(
          success: false,
          error: 'Database transaction error: $e',
        );
      } finally {
        await db.execute('PRAGMA foreign_keys = ON;');
      }
    } catch (e) {
      debugPrint('Unexpected error importing JSON: $e');
      return ImportResult(
        success: false,
        error: 'Failed to import JSON: $e',
      );
    }
  }

  /// Normalizes row fields, converting LLM property names and data structures
  static void _normalizeRowForTable(
    String table,
    Map<String, dynamic> row,
    String nowIso,
    String todayDateIso,
  ) {
    switch (table) {
      case AppTables.habits:
        if (row.containsKey('frequency') && !row.containsKey('frequency_type')) {
          row['frequency_type'] = row['frequency'];
        }
        if (!row.containsKey('frequency_type') || row['frequency_type'] == null) {
          row['frequency_type'] = 'daily';
        }
        // custom_days: if List, serialize to JSON string for SQLite storage
        if (row['custom_days'] != null) {
          if (row['custom_days'] is List) {
            row['custom_days'] = jsonEncode(row['custom_days']);
          } else if (row['custom_days'] is! String) {
            row['custom_days'] = row['custom_days'].toString();
          }
        }
        if (row.containsKey('color_hex') && !row.containsKey('color')) {
          row['color'] = row['color_hex'];
        }
        break;

      case AppTables.tasks:
        if (row.containsKey('completed') && !row.containsKey('is_completed')) {
          row['is_completed'] = row['completed'];
        } else if (row.containsKey('done') && !row.containsKey('is_completed')) {
          row['is_completed'] = row['done'];
        }
        if (row.containsKey('daily_target') && !row.containsKey('is_daily_target')) {
          row['is_daily_target'] = row['daily_target'];
        } else if (row.containsKey('is_daily') && !row.containsKey('is_daily_target')) {
          row['is_daily_target'] = row['is_daily'];
        }
        if (row.containsKey('goal') && !row.containsKey('goal_id')) {
          row['goal_id'] = row['goal'];
        }
        if (row['due_date'] != null && row['due_date'].toString().toLowerCase() == 'today') {
          row['due_date'] = todayDateIso;
        }
        break;

      case AppTables.goals:
        if (row.containsKey('color_hex') && !row.containsKey('color')) {
          row['color'] = row['color_hex'];
        }
        if (row.containsKey('target') && !row.containsKey('target_date')) {
          row['target_date'] = row['target'];
        }
        break;

      case AppTables.learningCollections:
        if (row.containsKey('color_hex') && !row.containsKey('color')) {
          row['color'] = row['color_hex'];
        }
        if (row.containsKey('icon_name') && !row.containsKey('icon')) {
          row['icon'] = row['icon_name'];
        }
        if (row.containsKey('name') && !row.containsKey('title')) {
          row['title'] = row['name'];
        }
        break;

      case AppTables.learningResources:
        if (row.containsKey('type') && !row.containsKey('resource_type')) {
          row['resource_type'] = row['type'];
        }
        if (row.containsKey('collection') && !row.containsKey('collection_id')) {
          row['collection_id'] = row['collection'];
        }
        if (!row.containsKey('url') || row['url'] == null || row['url'].toString().isEmpty) {
          row['url'] = 'https://arete.app';
        }
        if (!row.containsKey('resource_type') || row['resource_type'] == null) {
          row['resource_type'] = 'article';
        }
        if (!row.containsKey('status') || row['status'] == null) {
          row['status'] = 'not_started';
        }
        if (!row.containsKey('progress_percentage') || row['progress_percentage'] == null) {
          row['progress_percentage'] = 0;
        }
        break;

      case AppTables.notes:
        if (row.containsKey('content') && !row.containsKey('body')) {
          row['body'] = row['content'];
        }
        if (row['tags'] != null && row['tags'] is List) {
          row['tags'] = (row['tags'] as List).join(',');
        }
        if (!row.containsKey('body') || row['body'] == null) {
          row['body'] = '';
        }
        break;

      case AppTables.learningRoadmaps:
        if (row.containsKey('category') && !row.containsKey('category_id')) {
          row['category_id'] = row['category'];
        }
        break;

      case AppTables.dsaProblems:
        if (row.containsKey('difficulty_level') && !row.containsKey('difficulty')) {
          row['difficulty'] = row['difficulty_level'];
        }
        break;
    }
  }

  /// Guarantees that NOT NULL SQLite columns without default values receive safe defaults
  static void _ensureNotNullFields(
    String table,
    Map<String, dynamic> row,
    Set<String> notNullColumns,
    String nowIso,
    String todayDateIso,
  ) {
    for (final col in notNullColumns) {
      if (!row.containsKey(col) || row[col] == null) {
        if (col == 'title') {
          row[col] = 'Untitled';
        } else if (col == 'url') {
          row[col] = 'https://arete.app';
        } else if (col == 'body') {
          row[col] = '';
        } else if (col == 'name') {
          row[col] = 'Unnamed';
        } else if (col == 'created_at' || col == 'updated_at' || col == 'completed_at' || col == 'started_at' || col == 'ended_at') {
          row[col] = nowIso;
        } else if (col == 'completion_date') {
          row[col] = todayDateIso;
        } else if (col == 'duration_seconds' || col == 'completed_seconds') {
          row[col] = 1500;
        } else if (col == 'session_type') {
          row[col] = 'deep_work';
        } else if (col == 'is_completed' || col == 'is_daily_target' || col == 'is_pinned') {
          row[col] = 0;
        } else if (col == 'status') {
          row[col] = 'not_started';
        } else if (col == 'resource_type') {
          row[col] = 'article';
        } else if (col == 'frequency_type') {
          row[col] = 'daily';
        } else {
          row[col] = '';
        }
      }
    }
  }

  /// Backwards-compatible boolean import method
  Future<bool> importFromJson(String jsonString, {bool replaceExisting = false}) async {
    final result = await importFromJsonDetailed(jsonString, replaceExisting: replaceExisting);
    return result.success;
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
