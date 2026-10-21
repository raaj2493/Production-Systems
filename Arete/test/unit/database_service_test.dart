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
  });
}
