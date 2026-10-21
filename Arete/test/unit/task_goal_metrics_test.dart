import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arete/core/database/database_service.dart';
import 'package:arete/features/goals/data/goal_repository.dart';
import 'package:arete/features/goals/domain/goal_model.dart';
import 'package:arete/features/tasks/data/task_repository.dart';
import 'package:arete/features/tasks/domain/task_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Task and Goal Metrics Tests', () {
    late DatabaseService dbService;
    late GoalRepository goalRepo;
    late TaskRepository taskRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initDatabase(inMemory: true);
      goalRepo = GoalRepository(dbService);
      taskRepo = TaskRepository(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('Goal progress ratio updates as linked tasks are completed', () async {
      final now = DateTime.now();
      const goalId = 'goal-metrics-1';

      await goalRepo.createGoal(
        Goal(
          id: goalId,
          title: 'Learn Flutter',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Create 4 tasks for this goal
      for (int i = 1; i <= 4; i++) {
        await taskRepo.createTask(
          Task(
            id: 'task-$i',
            goalId: goalId,
            title: 'Subtask $i',
            isCompleted: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      var goal = await goalRepo.getGoalById(goalId);
      expect(goal, isNotNull);
      expect(goal!.totalTasks, equals(4));
      expect(goal.completedTasks, equals(0));
      expect(goal.progressRatio, equals(0.0));
      expect(goal.isCompleted, isFalse);

      // Complete 2 tasks
      await taskRepo.toggleTaskCompletion('task-1');
      await taskRepo.toggleTaskCompletion('task-2');

      goal = await goalRepo.getGoalById(goalId);
      expect(goal!.completedTasks, equals(2));
      expect(goal.progressRatio, equals(0.5));
      expect(goal.isCompleted, isFalse);

      // Complete remaining 2 tasks
      await taskRepo.toggleTaskCompletion('task-3');
      await taskRepo.toggleTaskCompletion('task-4');

      goal = await goalRepo.getGoalById(goalId);
      expect(goal!.completedTasks, equals(4));
      expect(goal.progressRatio, equals(1.0));
      expect(goal.isCompleted, isTrue);
    });
  });
}
