import 'package:flutter_test/flutter_test.dart';
import 'package:arete/core/utils/date_utils.dart';
import 'package:arete/features/habits/data/habit_repository.dart';
import 'package:arete/features/habits/domain/habit_model.dart';

void main() {
  group('Habit Streak Calculation Tests', () {
    test('Calculates current streak for consecutive daily completions', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final habit = Habit(
        id: 'h1',
        title: 'Daily Meditation',
        frequencyType: 'daily',
        createdAt: today.subtract(const Duration(days: 10)),
      );

      // Completed today, yesterday, and day before yesterday
      final completions = {
        AppDateUtils.toIsoDate(today),
        AppDateUtils.toIsoDate(today.subtract(const Duration(days: 1))),
        AppDateUtils.toIsoDate(today.subtract(const Duration(days: 2))),
      };

      final streak = HabitRepository.calculateCurrentStreak(habit, completions);
      expect(streak, equals(3));
    });

    test('Does not break streak if today is not completed yet', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final habit = Habit(
        id: 'h2',
        title: 'Daily Reading',
        frequencyType: 'daily',
        createdAt: today.subtract(const Duration(days: 10)),
      );

      // Completed yesterday and 2 days ago (not today yet)
      final completions = {
        AppDateUtils.toIsoDate(today.subtract(const Duration(days: 1))),
        AppDateUtils.toIsoDate(today.subtract(const Duration(days: 2))),
      };

      final streak = HabitRepository.calculateCurrentStreak(habit, completions);
      expect(streak, equals(2));
    });

    test('Respects non-scheduled days without breaking streaks artificially', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Find a Monday 2 weeks in the past so Mon/Wed/Fri are all completed historical days
      final monday = today.subtract(Duration(days: 14 + (today.weekday - 1)));

      // Habit scheduled Mon, Wed, Fri (1, 3, 5)
      final habit = Habit(
        id: 'h3',
        title: 'Workout',
        frequencyType: 'weekdays',
        customDays: const [DateTime.monday, DateTime.wednesday, DateTime.friday],
        createdAt: monday.subtract(const Duration(days: 14)),
      );

      final wednesday = monday.add(const Duration(days: 2));
      final friday = monday.add(const Duration(days: 4));

      // Completed Mon, Wed, Fri
      final completions = {
        AppDateUtils.toIsoDate(monday),
        AppDateUtils.toIsoDate(wednesday),
        AppDateUtils.toIsoDate(friday),
      };

      final bestStreak = HabitRepository.calculateBestStreak(habit, completions);
      // Tuesday and Thursday were non-scheduled, so streak should be 3!
      expect(bestStreak, equals(3));
    });
  });
}
