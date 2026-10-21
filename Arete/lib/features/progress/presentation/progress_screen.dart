import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_progress_bar.dart';
import '../../focus/data/focus_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../../habits/data/habit_repository.dart';
import '../../habits/presentation/widgets/habit_heatmap.dart';
import '../../tasks/data/task_repository.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasksState = ref.watch(tasksProvider);
    final goalsState = ref.watch(goalsProvider);
    final habitsState = ref.watch(habitsProvider);
    final heatmapDataAsync = ref.watch(heatmapDataProvider);
    final focusRepo = ref.watch(focusRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress & Consistency'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tasksProvider);
          ref.invalidate(goalsProvider);
          ref.invalidate(habitsProvider);
          ref.invalidate(heatmapDataProvider);
          ref.invalidate(todayFocusSecondsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Philosophical quote card
            AreteCard(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“We are what we repeatedly do. Excellence, then, is not an act, but a habit.”',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '— Will Durant (on Aristotle’s Areté)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // High-Level Metrics Row
            tasksState.maybeWhen(
              data: (tasks) {
                final completedTasks = tasks.where((t) => t.isCompleted).length;
                final totalTasks = tasks.length;
                final taskRate = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

                return Row(
                  children: [
                    Expanded(
                      child: AreteCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Task Completion',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              Formatters.formatPercent(taskRate),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completedTasks of $totalTasks total',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: focusRepo.getTotalFocusSeconds(),
                        builder: (context, snapshot) {
                          final totalSec = snapshot.data ?? 0;
                          return AreteCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Deep Work Logged',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  Formatters.formatDurationHuman(totalSec),
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All-time focus blocks',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Habit Heatmap
            Text('Habit Consistency Matrix', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            heatmapDataAsync.maybeWhen(
              data: (data) => AreteCard(
                padding: const EdgeInsets.all(16),
                child: HabitHeatmap(data: data, daysCount: 28),
              ),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Habits Streaks Overview
            habitsState.maybeWhen(
              data: (habits) {
                if (habits.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Habit Streaks', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    ...habits.map((h) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: AreteCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  h.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${h.currentStreak} day streak',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    'Best: ${h.bestStreak}d',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // Goals Progress
            goalsState.maybeWhen(
              data: (goals) {
                if (goals.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Goal Completion', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    ...goals.map((goal) {
                      Color goalColor = theme.colorScheme.primary;
                      if (goal.color != null) {
                        goalColor = Color(int.parse(goal.color!.replaceFirst('#', '0xFF')));
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: AreteCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      goal.title,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    Formatters.formatPercent(goal.progressRatio),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: goalColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              AreteProgressBar(
                                progress: goal.progressRatio,
                                color: goalColor,
                                height: 5,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${goal.completedTasks} of ${goal.totalTasks} tasks completed',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
