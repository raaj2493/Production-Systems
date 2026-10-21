import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_check_circle.dart';
import '../../../core/widgets/arete_empty_state.dart';
import '../../../core/widgets/arete_progress_bar.dart';
import '../../focus/presentation/focus_timer_controller.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/domain/goal_model.dart';
import '../../goals/presentation/goal_form_sheet.dart';
import '../data/task_repository.dart';
import '../domain/task_model.dart';
import 'task_form_sheet.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  int _selectedSegment = 0; // 0 = Tasks, 1 = Goals
  String? _filterGoalId;
  String _taskFilter = 'active'; // 'active', 'completed', 'all'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tasksState = ref.watch(tasksProvider);
    final goalsState = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks & Goals'),
        actions: [
          IconButton.filledTonal(
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: _selectedSegment == 0 ? 'Create Task' : 'New Goal',
            onPressed: () {
              if (_selectedSegment == 0) {
                TaskFormSheet.show(context);
              } else {
                GoalFormSheet.show(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      label: 'Tasks',
                      icon: Icons.check_circle_outline,
                      index: 0,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      label: 'Goals',
                      icon: Icons.flag_outlined,
                      index: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 96 + MediaQuery.of(context).padding.bottom,
        ), // clearance over floating pill
        child: FloatingActionButton.extended(
          onPressed: () {
            if (_selectedSegment == 0) {
              TaskFormSheet.show(context);
            } else {
              GoalFormSheet.show(context);
            }
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(
            _selectedSegment == 0 ? 'Create Task' : 'New Goal',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _selectedSegment == 0
            ? _buildTasksTab(tasksState, goalsState)
            : _buildGoalsTab(goalsState),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedSegment == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedSegment = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? theme.colorScheme.surface : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab(
    AsyncValue<List<Task>> tasksState,
    AsyncValue<List<Goal>> goalsState,
  ) {
    final theme = Theme.of(context);

    return tasksState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allTasks) {
        var filtered = allTasks;
        if (_filterGoalId != null) {
          filtered = filtered.where((t) => t.goalId == _filterGoalId).toList();
        }
        if (_taskFilter == 'active') {
          filtered = filtered.where((t) => !t.isCompleted).toList();
        } else if (_taskFilter == 'completed') {
          filtered = filtered.where((t) => t.isCompleted).toList();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tasksProvider);
            ref.invalidate(goalsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Filter Chips with Filled Background States
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Active', 'active', Icons.pending_actions_outlined),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', 'completed', Icons.task_alt),
                    const SizedBox(width: 8),
                    _buildFilterChip('All', 'all', Icons.format_list_bulleted),
                    if (_filterGoalId != null) ...[
                      const SizedBox(width: 8),
                      InputChip(
                        label: const Text('Goal Filter Active'),
                        onDeleted: () => setState(() => _filterGoalId = null),
                        deleteIconColor: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: AreteEmptyState(
                    icon: Icons.checklist_outlined,
                    title: _taskFilter == 'completed'
                        ? 'No Completed Tasks Yet'
                        : 'No Active Tasks Found',
                    description: _taskFilter == 'completed'
                        ? 'Finish a task to see your achievements stacked here.'
                        : 'Capture your next action item to maintain consistent momentum.',
                    actionLabel: 'Create Task',
                    onAction: () => TaskFormSheet.show(context),
                  ),
                )
              else
                ...filtered.map((task) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: AreteCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => TaskFormSheet.show(context, task: task),
                      child: Row(
                        children: [
                          AreteCheckCircle(
                            isChecked: task.isCompleted,
                            onTap: () {
                              ref.read(tasksProvider.notifier).toggleTask(task.id);
                            },
                            size: 22,
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
                                    decoration:
                                        task.isCompleted ? TextDecoration.lineThrough : null,
                                    color: task.isCompleted
                                        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                                        : theme.colorScheme.onSurface,
                                  ),
                                  child: Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (task.description != null &&
                                    task.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    task.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                                if (task.goalTitle != null || task.isDailyTarget) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (task.goalTitle != null)
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              task.goalTitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (task.isDailyTarget) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Daily Target',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                                size: 18,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              if (val == 'focus') {
                                ref.read(focusTimerProvider.notifier).linkTask(
                                      taskId: task.id,
                                      goalId: task.goalId,
                                    );
                                ref.read(focusTimerProvider.notifier).start();
                                context.go('/focus');
                              } else if (val == 'edit') {
                                TaskFormSheet.show(context, task: task);
                              } else if (val == 'delete') {
                                ref.read(tasksProvider.notifier).deleteTask(task.id);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'focus',
                                child: Text('Focus on Task'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit Task'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete Task', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              // Floating pill clearance
              const SizedBox(height: 140),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _taskFilter == value;

    return FilterChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      backgroundColor: theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.7),
        ),
      ),
      onSelected: (_) => setState(() => _taskFilter = value),
    );
  }

  Widget _buildGoalsTab(AsyncValue<List<Goal>> goalsState) {
    final theme = Theme.of(context);

    return goalsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (goals) {
        if (goals.isEmpty) {
          return AreteEmptyState(
            icon: Icons.flag_outlined,
            title: 'No Long-Term Goals Yet',
            description: 'Define meaningful long-term objectives to anchor daily habits and tasks.',
            actionLabel: 'Create Goal',
            onAction: () => GoalFormSheet.show(context),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(goalsProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: goals.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == goals.length) {
                return const SizedBox(height: 140); // bottom nav clearance
              }
              final goal = goals[index];
              final progress = goal.progressRatio;

              return AreteCard(
                padding: const EdgeInsets.all(16),
                onTap: () => GoalFormSheet.show(context, goal: goal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: goal.color != null
                                ? Color(int.parse(goal.color!.replaceFirst('#', '0xFF')))
                                : theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            goal.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.formatPercent(progress),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (goal.description != null && goal.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        goal.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    AreteProgressBar(progress: progress, height: 6),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${goal.completedTasks}/${goal.totalTasks} tasks completed',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.bolt_rounded, size: 14),
                              label: const Text('Focus', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                ref.read(focusTimerProvider.notifier).linkTask(
                                  taskId: null,
                                  goalId: goal.id,
                                );
                                context.go('/focus');
                              },
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedSegment = 0;
                                  _filterGoalId = goal.id;
                                });
                              },
                              child: const Text('Filter Tasks'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
