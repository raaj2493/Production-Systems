import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arete/core/database/database_service.dart';
import 'package:arete/core/providers/app_settings_provider.dart';
import 'package:arete/features/habits/data/habit_repository.dart';
import 'package:arete/features/habits/domain/habit_model.dart';
import 'package:arete/features/notifications/data/notification_providers.dart';
import 'package:arete/features/notifications/domain/notification_preferences_model.dart';
import 'package:arete/features/screentime/data/screen_time_providers.dart';
import 'package:arete/features/screentime/data/screen_time_repository.dart';
import 'package:arete/features/screentime/domain/app_category_model.dart';
import 'package:arete/features/screentime/domain/screen_time_status_model.dart';
import 'package:arete/features/tasks/data/task_repository.dart';
import 'package:arete/features/tasks/domain/task_model.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Notifications & Screen Time Monitoring Tests', () {
    late SharedPreferences prefs;
    late DatabaseService dbService;
    late TaskRepository taskRepo;
    late HabitRepository habitRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      dbService = DatabaseService.instance;
      await dbService.initDatabase(inMemory: true);
      taskRepo = TaskRepository(dbService);
      habitRepo = HabitRepository(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('1. NotificationPreferences default values and serialization', () {
      const defaultPrefs = NotificationPreferences();
      expect(defaultPrefs.habitRemindersEnabled, isTrue);
      expect(defaultPrefs.morningReminderHour, equals(8));
      expect(defaultPrefs.morningReminderMinute, equals(30));
      expect(defaultPrefs.morningFormatted, equals('8:30 AM'));
      expect(defaultPrefs.eveningReminderHour, equals(20));
      expect(defaultPrefs.eveningReminderMinute, equals(0));
      expect(defaultPrefs.eveningFormatted, equals('8:00 PM'));
      expect(defaultPrefs.taskAlertsEnabled, isTrue);
      expect(defaultPrefs.taskFifteenMinWarning, isTrue);
      expect(defaultPrefs.screenTimeMonitoringEnabled, isFalse);
      expect(defaultPrefs.distractionLimitMinutes, equals(30));
      expect(defaultPrefs.autoShieldOnLimit, isTrue);

      final map = defaultPrefs.toMap();
      final restored = NotificationPreferences.fromMap(map);
      expect(restored.habitRemindersEnabled, equals(defaultPrefs.habitRemindersEnabled));
      expect(restored.distractionLimitMinutes, equals(defaultPrefs.distractionLimitMinutes));
      expect(restored.morningFormatted, equals('8:30 AM'));
    });

    test('2. ScreenTime heuristic auto-classification engine classifies apps accurately', () {
      // Distractions
      expect(
        ScreenTimeRepository.classifyAppAutomatically('com.instagram.android', 'Instagram'),
        equals(AppCategory.distraction),
      );
      expect(
        ScreenTimeRepository.classifyAppAutomatically('com.zhiliaoapp.musically', 'TikTok'),
        equals(AppCategory.distraction),
      );
      expect(
        ScreenTimeRepository.classifyAppAutomatically('com.google.android.youtube', 'YouTube'),
        equals(AppCategory.distraction),
      );
      expect(
        ScreenTimeRepository.classifyAppAutomatically('com.supercell.clashofclans', 'Clash of Clans'),
        equals(AppCategory.distraction),
      );

      // Productive
      expect(
        ScreenTimeRepository.classifyAppAutomatically('com.notion.id', 'Notion'),
        equals(AppCategory.productive),
      );
      expect(
        ScreenTimeRepository.classifyAppAutomatically('org.coursera.android', 'Coursera'),
        equals(AppCategory.productive),
      );
      expect(
        ScreenTimeRepository.classifyAppAutomatically('md.obsidian', 'Obsidian Notes'),
        equals(AppCategory.productive),
      );
      expect(
        ScreenTimeRepository.classifyAppAutomatically('com.arete.app.arete', 'Areté'),
        equals(AppCategory.productive),
      );

      // Neutral
      expect(
        ScreenTimeRepository.classifyAppAutomatically('com.google.android.apps.messaging', 'Messages'),
        equals(AppCategory.neutral),
      );
      expect(
        ScreenTimeRepository.classifyAppAutomatically('com.android.calculator2', 'Calculator'),
        equals(AppCategory.neutral),
      );
    });

    test('3. ScreenTimeStatus duration and alert formatting', () {
      const status1 = ScreenTimeStatus(
        totalScreenTimeMinutes: 192, // 3h 12m
        currentPackage: 'com.instagram.android',
        currentAppName: 'Instagram',
        currentAppMinutes: 42,
        category: AppCategory.distraction,
        isMonitoring: true,
      );

      expect(status1.formattedTotalScreenTime, equals('3h 12m'));
      expect(status1.formattedCurrentAppTime, equals('42m'));
      expect(status1.isDistractionAlert, isTrue);

      const status2 = ScreenTimeStatus(
        totalScreenTimeMinutes: 45,
        currentPackage: 'com.notion.id',
        currentAppName: 'Notion',
        currentAppMinutes: 35,
        category: AppCategory.productive,
        isMonitoring: true,
      );

      expect(status2.formattedTotalScreenTime, equals('45m'));
      expect(status2.formattedCurrentAppTime, equals('35m'));
      expect(status2.isDistractionAlert, isFalse);
    });

    test('4. MonitoredAppsNotifier updates and persists app categories', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // Wait for initial load
      await container.read(monitoredAppsProvider.notifier).loadApps();
      var apps = container.read(monitoredAppsProvider).valueOrNull ?? [];
      expect(apps, isNotEmpty);

      // Find Instagram and ensure default is distraction
      final insta = apps.firstWhere((a) => a.packageName == 'com.instagram.android');
      expect(insta.category, equals(AppCategory.distraction));

      // Re-classify Instagram as Productive
      await container.read(monitoredAppsProvider.notifier).setCategory('com.instagram.android', AppCategory.productive);
      apps = container.read(monitoredAppsProvider).valueOrNull ?? [];
      final updatedInsta = apps.firstWhere((a) => a.packageName == 'com.instagram.android');
      expect(updatedInsta.category, equals(AppCategory.productive));

      container.dispose();
    });

    test('5. NotificationPreferencesNotifier updates settings and schedules preferences', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final notifier = container.read(notificationPreferencesProvider.notifier);
      expect(container.read(notificationPreferencesProvider).habitRemindersEnabled, isTrue);

      await notifier.setHabitRemindersEnabled(false);
      expect(container.read(notificationPreferencesProvider).habitRemindersEnabled, isFalse);

      await notifier.setMorningReminderTime(const TimeOfDay(hour: 7, minute: 15));
      expect(container.read(notificationPreferencesProvider).morningFormatted, equals('7:15 AM'));

      await notifier.setEveningReminderTime(const TimeOfDay(hour: 21, minute: 45));
      expect(container.read(notificationPreferencesProvider).eveningFormatted, equals('9:45 PM'));

      await notifier.setDistractionLimitMinutes(45);
      expect(container.read(notificationPreferencesProvider).distractionLimitMinutes, equals(45));

      container.dispose();
    });

    test('6. Notification shade action processing completes tasks and habits directly', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taskRepositoryProvider.overrideWithValue(taskRepo),
          habitRepositoryProvider.overrideWithValue(habitRepo),
        ],
      );

      final now = DateTime.now();
      await taskRepo.createTask(
        Task(
          id: 'shade-task-1',
          title: 'Notification Shade Task',
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await habitRepo.createHabit(
        Habit(
          id: 'shade-habit-1',
          title: 'Notification Shade Habit',
          createdAt: now,
        ),
      );

      await container.read(tasksProvider.notifier).loadTasks();
      await container.read(habitsProvider.notifier).loadHabits();

      var task = (container.read(tasksProvider).valueOrNull ?? []).firstWhere((t) => t.id == 'shade-task-1');
      expect(task.isCompleted, isFalse);

      var habit = (container.read(habitsProvider).valueOrNull ?? []).firstWhere((h) => h.id == 'shade-habit-1');
      expect(habit.isCompletedToday, isFalse);

      container.dispose();
    });
  });
}
