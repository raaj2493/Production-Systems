import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_check_circle.dart';
import '../../../core/widgets/arete_dialog.dart';
import '../../../core/widgets/arete_empty_state.dart';
import '../data/habit_repository.dart';
import 'habit_form_sheet.dart';
import 'widgets/habit_heatmap.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitsState = ref.watch(habitsProvider);
    final heatmapDataAsync = ref.watch(heatmapDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits & Streaks'),
        actions: [
          IconButton(
            icon: Icon(
              _isReordering ? Icons.done_all_rounded : Icons.swap_vert_rounded,
              color: _isReordering ? theme.colorScheme.primary : null,
            ),
            tooltip: _isReordering ? 'Done Reordering' : 'Reorder Habits',
            onPressed: () {
              setState(() => _isReordering = !_isReordering);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Habit',
            onPressed: () => HabitFormSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => HabitFormSheet.show(context),
        child: const Icon(Icons.add),
      ),
      body: habitsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (habits) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(habitsProvider);
              ref.invalidate(heatmapDataProvider);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Heatmap card
                heatmapDataAsync.maybeWhen(
                  data: (data) => AreteCard(
                    padding: const EdgeInsets.all(16),
                    child: HabitHeatmap(data: data, daysCount: 28),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Your Daily & Scheduled Habits',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    if (_isReordering) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Drag to reorder',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                if (habits.isEmpty) ...[
                  AreteEmptyState(
                    icon: Icons.repeat_outlined,
                    title: 'No Habits Yet',
                    description: 'Consistency over intensity. Build rituals that withstand difficult days.',
                    actionLabel: 'Create Habit',
                    onAction: () => HabitFormSheet.show(context),
                  ),
                ] else if (_isReordering) ...[
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: habits.length,
                    onReorder: (oldIndex, newIndex) {
                      ref.read(habitsProvider.notifier).reorderHabits(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final habit = habits[index];
                      Color habitColor = theme.colorScheme.primary;
                      if (habit.color != null) {
                        habitColor = Color(int.parse(habit.color!.replaceFirst('#', '0xFF')));
                      }

                      return Container(
                        key: ValueKey(habit.id),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: AreteCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  habit.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: habitColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${habit.currentStreak}d streak',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: habitColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  ...habits.map((habit) {
                    final isDone = habit.isCompletedToday;
                    Color habitColor = theme.colorScheme.primary;
                    if (habit.color != null) {
                      habitColor = Color(int.parse(habit.color!.replaceFirst('#', '0xFF')));
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: AreteCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        borderColor: isDone ? habitColor.withValues(alpha: 0.5) : null,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AreteCheckCircle(
                              isChecked: isDone,
                              onTap: () {
                                ref
                                    .read(habitsProvider.notifier)
                                    .toggleHabitCompletion(habit.id);
                              },
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      fontWeight: FontWeight.w600,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                      color: isDone
                                          ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                                          : theme.colorScheme.onSurface,
                                    ),
                                    child: Text(habit.title),
                                  ),
                                  if (habit.description != null &&
                                      habit.description!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      habit.description!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: habitColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          habit.frequencyType == 'daily' ? 'Daily' : 'Custom Schedule',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: habitColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Streak: ${habit.currentStreak}d  •  Best: ${habit.bestStreak}d',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert,
                                  size: 18,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                              padding: EdgeInsets.zero,
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  HabitFormSheet.show(context, habit: habit);
                                } else if (val == 'delete') {
                                  final confirmed = await AreteDialog.showConfirmation(
                                    context: context,
                                    title: 'Delete Habit',
                                    message:
                                        'Are you sure you want to delete "${habit.title}" and its completion history?',
                                    confirmLabel: 'Delete',
                                    isDestructive: true,
                                  );
                                  if (confirmed == true) {
                                    ref.read(habitsProvider.notifier).deleteHabit(habit.id);
                                  }
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit Habit')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete Habit', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
