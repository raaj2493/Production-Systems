import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arete/core/database/database_service.dart';
import 'package:arete/core/providers/app_settings_provider.dart';
import 'package:arete/core/theme/app_theme.dart';
import 'package:arete/features/focus/presentation/focus_screen.dart';
import 'package:arete/features/habits/presentation/habits_screen.dart';
import 'package:arete/features/learn/presentation/learn_screen.dart';
import 'package:arete/features/notes/presentation/notes_screen.dart';
import 'package:arete/features/settings/presentation/settings_screen.dart';
import 'package:arete/features/splash/presentation/splash_screen.dart';
import 'package:arete/features/tasks/presentation/tasks_screen.dart';
import 'package:arete/features/today/presentation/today_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Arete UI Screens Smoke Tests', () {
    late SharedPreferences prefs;
    late DatabaseService dbService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      dbService = DatabaseService.instance;
      await dbService.initDatabase(inMemory: true);
      await dbService.seedStarterData();
    });

    tearDown(() async {
      await dbService.close();
    });

    testWidgets('TodayScreen renders daily targets, habits, and actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const TodayScreen(),
          ),
        ),
      );

      // Advance frames past async DB load and sqflite lock timer
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Daily Focus Target'), findsOneWidget);
      expect(find.textContaining('Start Focus Session'), findsOneWidget);
      expect(find.text('Goal: 2 hrs'), findsOneWidget);
      expect(find.text('Keep your word. One step at a time.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('TasksScreen renders Tasks and Goals tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TasksScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Tasks & Goals'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('FocusScreen renders timer and controls',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FocusScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Focus Timer'), findsOneWidget);
      expect(find.text('Start Session'), findsOneWidget);
      expect(find.text('Short Break'), findsOneWidget);
      expect(find.text('Long Break'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('LearnScreen renders resources and learning paths',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LearnScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Learning Hub'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Roadmaps'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('HabitsScreen renders habits header and list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HabitsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Habits & Streaks'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('NotesScreen renders notes screen and title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const NotesScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Notes & Reflections'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('SettingsScreen renders themes and preferences',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));

      expect(find.text('Settings & Backup'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Daily Task Target'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('SplashScreen renders logo and brand motto',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SplashScreen(),
        ),
      );

      await tester.pump();

      expect(find.text('A R E T É'), findsOneWidget);
      expect(find.text('Excellence through consistency'), findsOneWidget);
      expect(find.text('Virtue • Focus • Mastery'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
