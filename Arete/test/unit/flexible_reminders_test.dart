import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arete/core/database/database_service.dart';
import 'package:arete/features/habits/data/habit_repository.dart';
import 'package:arete/features/habits/domain/habit_model.dart';
import 'package:arete/features/notifications/data/notification_providers.dart';
import 'package:arete/features/reminders/data/reminder_providers.dart';
import 'package:arete/features/reminders/data/reminder_repository.dart';
import 'package:arete/features/reminders/domain/reminder_model.dart';
import 'package:arete/features/tasks/data/task_repository.dart';
import 'package:arete/features/tasks/domain/task_model.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Flexible Recurring Reminders & Priority Notifications Tests', () {
    late DatabaseService dbService;
    late ReminderRepository reminderRepo;
    late HabitRepository habitRepo;
    late TaskRepository taskRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initDatabase(inMemory: true);
      reminderRepo = ReminderRepository(dbService: dbService);
      habitRepo = HabitRepository(dbService);
      taskRepo = TaskRepository(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('1. ReminderConfig model defaults, priorities, and serialization', () {
      final now = DateTime(2026, 10, 20, 10, 0);
      final reminder = ReminderConfig(
        id: 'rem_1',
        targetType: 'standalone',
        title: 'Drink Water',
        description: 'Drink 250ml of water',
        triggerType: ReminderTriggerType.interval,
        intervalMinutes: 60,
        windowStartHour: 9,
        windowStartMinute: 0,
        windowEndHour: 21,
        windowEndMinute: 0,
        priority: ReminderPriority.high,
        isSticky: true,
        soundMode: ReminderSound.vibrantPing,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(reminder.id, equals('rem_1'));
      expect(reminder.priority, equals(ReminderPriority.high));
      expect(reminder.priority.label, equals('High Priority'));
      expect(reminder.isSticky, isTrue);
      expect(reminder.triggerType, equals(ReminderTriggerType.interval));
      expect(reminder.formattedSchedule, equals('Every 1 hour (9:00 AM – 9:00 PM)'));

      // SQLite serialization roundtrip
      final map = reminder.toMap();
      expect(map['is_sticky'], equals(1));
      expect(map['priority'], equals('high'));
      expect(map['trigger_type'], equals('interval'));
      expect(map['sound_mode'], equals('vibrant_ping'));

      final reconstructed = ReminderConfig.fromMap(map);
      expect(reconstructed.id, equals(reminder.id));
      expect(reconstructed.title, equals(reminder.title));
      expect(reconstructed.isSticky, isTrue);
      expect(reconstructed.priority, equals(ReminderPriority.high));
      expect(reconstructed.soundMode, equals(ReminderSound.vibrantPing));
      expect(reconstructed.intervalMinutes, equals(60));

      // MethodChannel map
      final channelMap = reminder.toMethodChannelMap();
      expect(channelMap['isSticky'], isTrue);
      expect(channelMap['priority'], equals('high'));
      expect(channelMap['intervalMinutes'], equals(60));
    });

    test('2. Fixed-time scheduled reminder with day-of-week recurrence', () {
      final now = DateTime(2026, 10, 20, 10, 0); // Tuesday
      final reminder = ReminderConfig(
        id: 'rem_reading',
        targetType: 'habit',
        targetId: 'habit_123',
        title: 'Evening Book Reading',
        description: 'Read 20 mins before bed',
        triggerType: ReminderTriggerType.fixedTime,
        fixedHour: 22,
        fixedMinute: 0,
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7], // Daily
        priority: ReminderPriority.medium,
        isSticky: false,
        soundMode: ReminderSound.gentleChime,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(reminder.formattedSchedule, equals('Daily at 10:00 PM'));
      expect(reminder.priority, equals(ReminderPriority.medium));
      expect(reminder.isSticky, isFalse);

      // Next trigger time from 10:00 AM on 2026-10-20 should be 10:00 PM on same day
      final next = reminder.nextTriggerTime(DateTime(2026, 10, 20, 10, 0));
      expect(next.year, equals(2026));
      expect(next.month, equals(10));
      expect(next.day, equals(20));
      expect(next.hour, equals(22));
      expect(next.minute, equals(0));

      // Next trigger time after 10:00 PM should be 10:00 PM next day
      final nextTomorrow = reminder.nextTriggerTime(DateTime(2026, 10, 20, 23, 0));
      expect(nextTomorrow.day, equals(21));
      expect(nextTomorrow.hour, equals(22));
    });

    test('3. Interval active daily window calculations & overnight pauses', () {
      final reminder = ReminderConfig(
        id: 'rem_hydration',
        targetType: 'standalone',
        title: 'Hydration',
        triggerType: ReminderTriggerType.interval,
        intervalMinutes: 45,
        windowStartHour: 9,
        windowStartMinute: 0,
        windowEndHour: 21,
        windowEndMinute: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // In window: 11:30 AM
      final midday = DateTime(2026, 10, 20, 11, 30);
      expect(reminder.isWithinActiveWindow(midday), isTrue);

      // In window: exactly at start 9:00 AM
      final windowStart = DateTime(2026, 10, 20, 9, 0);
      expect(reminder.isWithinActiveWindow(windowStart), isTrue);

      // In window: exactly at end 9:00 PM
      final windowEnd = DateTime(2026, 10, 20, 21, 0);
      expect(reminder.isWithinActiveWindow(windowEnd), isTrue);

      // Outside window: 7:30 AM (before start)
      final earlyMorning = DateTime(2026, 10, 20, 7, 30);
      expect(reminder.isWithinActiveWindow(earlyMorning), isFalse);

      // Outside window: 11:00 PM (after end)
      final lateNight = DateTime(2026, 10, 20, 23, 0);
      expect(reminder.isWithinActiveWindow(lateNight), isFalse);

      // When late at night (e.g. 23:00), next trigger should silently defer to tomorrow at 9:00 AM
      final nextTrigger = reminder.nextTriggerTime(lateNight);
      expect(nextTrigger.day, equals(21));
      expect(nextTrigger.hour, equals(9));
      expect(nextTrigger.minute, equals(0));
    });

    test('4. ReminderRepository SQLite CRUD and target linkage', () async {
      final now = DateTime.now();
      final reminder1 = ReminderConfig(
        id: 'rem_h1',
        targetType: 'habit',
        targetId: 'h_100',
        title: 'Morning Yoga',
        priority: ReminderPriority.medium,
        isSticky: true,
        createdAt: now,
        updatedAt: now,
      );

      final reminder2 = ReminderConfig(
        id: 'rem_t1',
        targetType: 'task',
        targetId: 't_200',
        title: 'Submit Tax Audit',
        priority: ReminderPriority.high,
        isSticky: true,
        createdAt: now,
        updatedAt: now,
      );

      // Save
      await reminderRepo.saveReminder(reminder1);
      await reminderRepo.saveReminder(reminder2);

      // Retrieve all
      final all = await reminderRepo.getAllReminders();
      expect(all.length, equals(2));

      // Retrieve by target
      final habitRem = await reminderRepo.getReminderForTarget('habit', 'h_100');
      expect(habitRem, isNotNull);
      expect(habitRem!.title, equals('Morning Yoga'));
      expect(habitRem.isSticky, isTrue);

      final taskRem = await reminderRepo.getReminderForTarget('task', 't_200');
      expect(taskRem, isNotNull);
      expect(taskRem!.priority, equals(ReminderPriority.high));

      // Toggle enabled
      await reminderRepo.toggleReminder('rem_h1', false);
      final toggled = await reminderRepo.getReminderById('rem_h1');
      expect(toggled?.isEnabled, isFalse);

      // Delete by target
      await reminderRepo.deleteRemindersForTarget('task', 't_200');
      final remaining = await reminderRepo.getAllReminders();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('rem_h1'));
    });

    test('5. Notification Shade Actions complete tasks, habits, and pop actions', () async {
      // 1. Create habit and task
      final habit = Habit(
        id: 'h_streak',
        title: 'Drink 2L Water',
        frequencyType: 'daily',
        createdAt: DateTime.now(),
      );
      await habitRepo.createHabit(habit);

      final task = Task(
        id: 't_sticky',
        title: 'Review PR #42',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await taskRepo.createTask(task);

      // 2. Set up container with mocked notification channel
      final container = ProviderContainer(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(reminderRepo),
          habitRepositoryProvider.overrideWithValue(habitRepo),
          taskRepositoryProvider.overrideWithValue(taskRepo),
        ],
      );

      // Verify initial state
      final habitsBefore = await habitRepo.getAllHabits();
      expect(habitsBefore.first.isCompletedToday, isFalse);
      final tasksBefore = await taskRepo.getAllTasks();
      expect(tasksBefore.first.isCompleted, isFalse);

      await container.read(habitsProvider.notifier).loadHabits();
      await container.read(tasksProvider.notifier).loadTasks();

      // 3. Mock native MethodChannel popping pending actions from notification shade:
      // Simulating user tapped "✅ Mark Done" on sticky reminder for both task and habit
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.arete.app/notifications_and_screentime'),
        (call) async {
          if (call.method == 'popPendingActions') {
            return [
              {'type': 'habit_done', 'id': 'h_streak'},
              {'type': 'task_done', 'id': 't_sticky'},
              {'type': 'reminder_done', 'id': 'rem_sample'},
            ];
          }
          return null;
        },
      );

      // Process shade actions
      final processed = await container.read(notificationPreferencesProvider.notifier).processPendingShadeActions();
      expect(processed, equals(3));

      // Verify habit is now marked completed
      final habitsAfter = await habitRepo.getAllHabits();
      expect(habitsAfter.first.isCompletedToday, isTrue);

      // Verify task is now marked completed
      final tasksAfter = await taskRepo.getAllTasks();
      expect(tasksAfter.first.isCompleted, isTrue);

      // Clean up mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.arete.app/notifications_and_screentime'),
        null,
      );
    });
  });
}
