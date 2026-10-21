import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arete/core/database/database_service.dart';
import 'package:arete/core/database/tables.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initDatabase(inMemory: true);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('Initializes in-memory database with all tables', () async {
      final db = await dbService.database;
      expect(db.isOpen, isTrue);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames, containsAll([
        AppTables.goals,
        AppTables.tasks,
        AppTables.habits,
        AppTables.habitCompletions,
        AppTables.focusSessions,
        AppTables.learningCollections,
        AppTables.learningResources,
        AppTables.notes,
        AppTables.tags,
        AppTables.blockedApps,
        AppTables.focusShieldInterruptions,
        AppTables.learningCategories,
        AppTables.learningRoadmaps,
        AppTables.learningRoadmapPhases,
        AppTables.learningRoadmapTopics,
        AppTables.dsaProblems,
        AppTables.learningProjects,
        AppTables.learningProfile,
      ]));
    });

    test('Seeds starter data and exports valid JSON', () async {
      await dbService.seedStarterData();

      final db = await dbService.database;
      final taskCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.tasks}'),
      );
      expect(taskCount, greaterThan(0));

      final exportJson = await dbService.exportToJson();
      expect(exportJson, contains('"app": "Areté"'));
      expect(exportJson, contains('"tasks"'));
      expect(exportJson, contains('Master Mobile Architecture'));
    });

    test('Atomically wipes all tables via clearAllData', () async {
      await dbService.seedStarterData();
      await dbService.clearAllData();

      final db = await dbService.database;
      final taskCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.tasks}'),
      );
      final habitCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.habits}'),
      );

      expect(taskCount, equals(0));
      expect(habitCount, equals(0));
    });

    test('Validates and imports backup JSON', () async {
      await dbService.seedStarterData();
      final backup = await dbService.exportToJson();

      await dbService.clearAllData();
      final imported = await dbService.importFromJson(backup, replaceExisting: true);
      expect(imported, isTrue);

      final db = await dbService.database;
      final taskCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.tasks}'),
      );
      expect(taskCount, greaterThan(0));
    });

    test('Rejects invalid backup JSON', () async {
      const invalidJson = '{"app": "OtherApp", "data": 123}';
      final imported = await dbService.importFromJson(invalidJson);
      expect(imported, isFalse);
    });

    test('Imports JSON wrapped in ChatGPT conversational text and markdown backticks', () async {
      const chatGptOutput = '''
Sure thing! Here is your personalized workspace JSON for Areté:

```json
{
  "app": "Areté",
  "tables": {
    "goals": [
      {
        "id": "goal_ai",
        "title": "Master Agentic AI",
        "color": "#D2E8D4"
      }
    ],
    "tasks": [
      {
        "title": "Build Multi-Turn ReAct Agent",
        "is_daily_target": 1
      }
    ]
  }
}
```

Hope this helps you achieve your goals!
''';

      final result = await dbService.importFromJsonDetailed(chatGptOutput, replaceExisting: true);
      expect(result.success, isTrue);
      expect(result.totalCount, equals(2));
      expect(result.tableCounts[AppTables.goals], equals(1));
      expect(result.tableCounts[AppTables.tasks], equals(1));

      final db = await dbService.database;
      final tasks = await db.query(AppTables.tasks);
      expect(tasks.length, equals(1));
      expect(tasks.first['title'], equals('Build Multi-Turn ReAct Agent'));
      expect(tasks.first['id'], isNotNull);
      expect(tasks.first['is_daily_target'], equals(1));
    });

    test('Imports JSON with raw custom_days list and frequency alias', () async {
      const jsonWithList = '''
{
  "habits": [
    {
      "title": "Morning Cardio",
      "frequency": "custom",
      "custom_days": [1, 2, 3, 4, 5],
      "color_hex": "#FFDDB3"
    }
  ]
}
''';

      final result = await dbService.importFromJsonDetailed(jsonWithList);
      expect(result.success, isTrue);

      final db = await dbService.database;
      final habits = await db.query(AppTables.habits, where: 'title = ?', whereArgs: ['Morning Cardio']);
      expect(habits.length, equals(1));
      expect(habits.first['frequency_type'], equals('custom'));
      expect(habits.first['custom_days'], equals('[1,2,3,4,5]'));
      expect(habits.first['color'], equals('#FFDDB3'));
    });

    test('Imports JSON with dangling goal foreign key without aborting', () async {
      const jsonWithDanglingFk = '''
{
  "tasks": [
    {
      "title": "Unlinked Task with non-existent goal",
      "goal_id": "non_existent_goal_999",
      "is_completed": 0
    }
  ]
}
''';

      final result = await dbService.importFromJsonDetailed(jsonWithDanglingFk);
      expect(result.success, isTrue);

      final db = await dbService.database;
      final tasks = await db.query(AppTables.tasks, where: 'title = ?', whereArgs: ['Unlinked Task with non-existent goal']);
      expect(tasks.length, equals(1));
    });

    test('Imports JSON with trailing commas hallucinated by LLMs', () async {
      const trailingCommaJson = '''
{
  "tables": {
    "tasks": [
      {
        "title": "Fix JSON parser",
      },
    ],
  },
}
''';

      final result = await dbService.importFromJsonDetailed(trailingCommaJson);
      expect(result.success, isTrue);
    });
  });
}
