import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arete/core/database/database_service.dart';
import 'package:arete/core/providers/app_settings_provider.dart';
import 'package:arete/core/utils/date_utils.dart';
import 'package:arete/features/habits/data/habit_repository.dart';
import 'package:arete/features/habits/domain/habit_model.dart';
import 'package:arete/features/progress/domain/daily_consistency_model.dart';
import 'package:arete/features/settings/data/backup_service.dart';
import 'package:arete/features/tasks/data/task_repository.dart';
import 'package:arete/features/tasks/domain/task_model.dart';
import 'package:arete/features/focus/data/focus_repository.dart';
import 'package:arete/features/focus/presentation/focus_timer_controller.dart';
import 'package:arete/features/focus/presentation/focus_shield_controller.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Today Dashboard & Dual-Way Task Sync Tests', () {
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

    test('1. todayTasksProvider automatically renders active tasks & today targets', () async {

      final now = DateTime.now();
      final todayIso = AppDateUtils.todayIso;

      // Create an active task without a due date
      await taskRepo.createTask(
        Task(
          id: 'task-active-1',
          title: 'Active Task 1',
          isCompleted: false,
          isDailyTarget: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Create a task scheduled for today
      await taskRepo.createTask(
        Task(
          id: 'task-today-2',
          title: 'Today Task 2',
          dueDate: todayIso,
          isCompleted: false,
          isDailyTarget: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Create a daily target task
      await taskRepo.createTask(
        Task(
          id: 'task-target-3',
          title: 'Daily Target 3',
          isCompleted: false,
          isDailyTarget: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final element = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taskRepositoryProvider.overrideWithValue(taskRepo),
        ],
      );

      // Trigger initial load
      await element.read(tasksProvider.notifier).loadTasks();
      final todayTasks = element.read(todayTasksProvider);

      expect(todayTasks.length, equals(3));
      // Daily target should be prioritized first
      expect(todayTasks.first.isDailyTarget, isTrue);

      element.dispose();
    });

    test('2. Checking off task updates task completion velocity stats immediately', () async {
      final element = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taskRepositoryProvider.overrideWithValue(taskRepo),
        ],
      );

      final now = DateTime.now();
      for (int i = 1; i <= 4; i++) {
        await taskRepo.createTask(
          Task(
            id: 'task-vel-$i',
            title: 'Velocity Task $i',
            isCompleted: false,
            isDailyTarget: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      await element.read(tasksProvider.notifier).loadTasks();
      var velocity = element.read(taskVelocityStatsProvider);

      expect(velocity.totalToday, equals(4));
      expect(velocity.completedToday, equals(0));
      expect(velocity.completionRate, equals(0.0));

      // Toggle first 2 tasks complete
      await element.read(tasksProvider.notifier).toggleTask('task-vel-1');
      await element.read(tasksProvider.notifier).toggleTask('task-vel-2');

      velocity = element.read(taskVelocityStatsProvider);
      expect(velocity.completedToday, equals(2));
      expect(velocity.completionRate, equals(0.5));
      expect(velocity.activeCount, equals(2));

      // Toggle 3rd and 4th tasks complete -> 100% velocity
      await element.read(tasksProvider.notifier).toggleTask('task-vel-3');
      await element.read(tasksProvider.notifier).toggleTask('task-vel-4');

      velocity = element.read(taskVelocityStatsProvider);
      expect(velocity.completedToday, equals(4));
      expect(velocity.completionRate, equals(1.0));
      expect(velocity.velocityLabel, contains('100% Velocity'));

      element.dispose();
    });

    test('3. DailyConsistency intensity levels follow Material 3 pastel thresholds', () {
      // 0 mins = level 0 (light ceramic)
      final day0 = DailyConsistency(date: DateTime(2026, 10, 20), dateIso: '2026-10-20', focusMinutes: 0);
      expect(day0.intensityLevel, equals(0));

      // 15 mins = level 1 (soft sage)
      final day1 = DailyConsistency(date: DateTime(2026, 10, 20), dateIso: '2026-10-20', focusMinutes: 15);
      expect(day1.intensityLevel, equals(1));

      // 30m+ = level 2 (light sage)
      final day2 = DailyConsistency(date: DateTime(2026, 10, 20), dateIso: '2026-10-20', focusMinutes: 30);
      expect(day2.intensityLevel, equals(2));

      // 60m+ = level 3 (medium forest)
      final day3 = DailyConsistency(date: DateTime(2026, 10, 20), dateIso: '2026-10-20', focusMinutes: 75);
      expect(day3.intensityLevel, equals(3));

      // 120m+ = level 4 (deep olive)
      final day4 = DailyConsistency(date: DateTime(2026, 10, 20), dateIso: '2026-10-20', focusMinutes: 150);
      expect(day4.intensityLevel, equals(4));
      expect(day4.dayStatusBadge, contains('Deep Work Master'));
    });

    test('4. HabitsNotifier reorderHabits mutates habit ordering in memory', () async {
      final element = ProviderContainer(
        overrides: [
          habitRepositoryProvider.overrideWithValue(habitRepo),
        ],
      );

      final now = DateTime.now();
      await habitRepo.createHabit(Habit(id: 'h1', title: 'Habit 1', createdAt: now));
      await habitRepo.createHabit(Habit(id: 'h2', title: 'Habit 2', createdAt: now.add(const Duration(seconds: 1))));
      await habitRepo.createHabit(Habit(id: 'h3', title: 'Habit 3', createdAt: now.add(const Duration(seconds: 2))));

      await element.read(habitsProvider.notifier).loadHabits();
      var habits = element.read(habitsProvider).valueOrNull ?? [];
      expect(habits.map((h) => h.id).toList(), equals(['h1', 'h2', 'h3']));

      // Reorder h3 to the first position
      element.read(habitsProvider.notifier).reorderHabits(2, 0);

      habits = element.read(habitsProvider).valueOrNull ?? [];
      expect(habits.map((h) => h.id).toList(), equals(['h3', 'h1', 'h2']));

      element.dispose();
    });

    test('5. AppSettings persists custom focus duration presets', () async {
      final notifier = AppSettingsNotifier(prefs);
      expect(notifier.state.focusDurationPresets, equals([15, 25, 45, 60]));

      await notifier.setFocusDurationPresets([15, 25, 50, 90]);
      expect(notifier.state.focusDurationPresets, equals([15, 25, 50, 90]));

      // Verify new notifier loads persisted presets
      final newNotifier = AppSettingsNotifier(prefs);
      expect(newNotifier.state.focusDurationPresets, equals([15, 25, 50, 90]));
    });

    test('6. BackupService exports valid JSON and template is parsable', () async {
      final templateJson = BackupService.getStarterTemplateJson();
      expect(templateJson, contains('"app": "Areté"'));
      expect(templateJson, contains('goal_systems_design'));
      expect(templateJson, contains('habit_deep_work'));

      final exported = await dbService.exportToJson();
      expect(exported, contains('"app": "Areté"'));
      expect(exported, contains('"tables"'));
    });

    test('7. liveTodayFocusSecondsProvider syncs live focus session seconds in real time', () async {
      final focusRepo = FocusRepository(dbService);
      final element = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          focusRepositoryProvider.overrideWithValue(focusRepo),
        ],
      );

      // Await shield controller init to ensure DB query completes cleanly
      await element.read(focusShieldProvider.notifier).init();

      // Initially 0 seconds logged today
      expect(element.read(liveTodayFocusSecondsProvider), equals(0));

      final timerNotifier = element.read(focusTimerProvider.notifier);
      // Start 25m focus timer
      await timerNotifier.start();

      // Simulate 120 seconds (2 minutes) having passed in the session
      element.read(focusTimerProvider.notifier).state = element.read(focusTimerProvider).copyWith(
        remainingSeconds: (25 * 60) - 120,
      );

      // liveTodayFocusSecondsProvider immediately reflects the 120 elapsed focus seconds
      expect(element.read(liveTodayFocusSecondsProvider), equals(120));
      // In minutes, 2 minutes
      expect(element.read(liveTodayFocusSecondsProvider) ~/ 60, equals(2));

      element.dispose();
    });

    test('8. Resetting focus session preserves every minute spent into database', () async {
      final focusRepo = FocusRepository(dbService);
      final element = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          focusRepositoryProvider.overrideWithValue(focusRepo),
        ],
      );

      await element.read(focusShieldProvider.notifier).init();

      final timerNotifier = element.read(focusTimerProvider.notifier);
      await timerNotifier.start();

      // Simulate 15 minutes (900 seconds) of focus elapsed
      element.read(focusTimerProvider.notifier).state = element.read(focusTimerProvider).copyWith(
        remainingSeconds: (25 * 60) - 900,
      );

      // User pauses or resets
      timerNotifier.pause();
      await timerNotifier.reset();

      // Verify the 15 minutes were saved to database and counted
      final dbSeconds = await focusRepo.getTodayFocusSeconds();
      expect(dbSeconds, equals(900));

      // Recent sessions shows the partial session
      final recent = await focusRepo.getRecentSessions();
      expect(recent.length, equals(1));
      expect(recent.first.completedSeconds, equals(900));
      expect(recent.first.isCompleted, isFalse);

      // liveTodayFocusSecondsProvider still reflects the 15 minutes (900 seconds) from DB
      final liveSec = element.read(liveTodayFocusSecondsProvider);
      expect(liveSec, equals(900));
      expect(liveSec ~/ 60, equals(15));

      element.dispose();
    });
  });
}
