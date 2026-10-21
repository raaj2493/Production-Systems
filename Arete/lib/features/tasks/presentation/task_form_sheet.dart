import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_dropdown.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../../goals/data/goal_repository.dart';
import '../../notifications/data/notification_providers.dart';
import '../../reminders/data/reminder_providers.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/presentation/reminder_config_section.dart';
import '../data/task_repository.dart';
import '../domain/task_model.dart';

class TaskFormSheet extends ConsumerStatefulWidget {
  final Task? task;
  final bool initialDailyTarget;

  const TaskFormSheet({
    super.key,
    this.task,
    this.initialDailyTarget = false,
  });

  static Future<void> show(
    BuildContext context, {
    Task? task,
    bool initialDailyTarget = false,
  }) {
    return AreteBottomSheet.show(
      context: context,
      title: task == null ? 'New Task' : 'Edit Task',
      child: TaskFormSheet(
        task: task,
        initialDailyTarget: initialDailyTarget,
      ),
    );
  }

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  String? _selectedGoalId;
  String? _dueDate;
  late bool _isDailyTarget;
  String _priority = 'Medium';

  // Reminder configuration state
  bool _reminderEnabled = false;
  ReminderTriggerType _reminderTriggerType = ReminderTriggerType.fixedTime;
  int _reminderIntervalMinutes = 60;
  TimeOfDay _windowStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _windowEndTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _fixedTime = const TimeOfDay(hour: 10, minute: 0);
  List<int> _reminderDaysOfWeek = const [1, 2, 3, 4, 5, 6, 7];
  ReminderPriority _reminderPriority = ReminderPriority.medium;
  bool _reminderIsSticky = false;
  ReminderSound _reminderSoundMode = ReminderSound.gentleChime;
  String? _existingReminderId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descController = TextEditingController(text: widget.task?.description ?? '');
    _selectedGoalId = widget.task?.goalId;
    _dueDate = widget.task?.dueDate ?? (widget.initialDailyTarget ? AppDateUtils.todayIso : null);
    _isDailyTarget = widget.task?.isDailyTarget ?? widget.initialDailyTarget;

    if (widget.task != null) {
      _loadLinkedReminder(widget.task!.id);
    }
  }

  Future<void> _loadLinkedReminder(String taskId) async {
    final r = await ref.read(reminderRepositoryProvider).getReminderForTarget('task', taskId);
    if (r != null && mounted) {
      setState(() {
        _existingReminderId = r.id;
        _reminderEnabled = r.isEnabled;
        _reminderTriggerType = r.triggerType;
        _reminderIntervalMinutes = r.intervalMinutes;
        _windowStartTime = TimeOfDay(hour: r.windowStartHour, minute: r.windowStartMinute);
        _windowEndTime = TimeOfDay(hour: r.windowEndHour, minute: r.windowEndMinute);
        _fixedTime = TimeOfDay(hour: r.fixedHour, minute: r.fixedMinute);
        _reminderDaysOfWeek = List<int>.from(r.daysOfWeek);
        _reminderPriority = r.priority;
        _reminderIsSticky = r.isSticky;
        _reminderSoundMode = r.soundMode;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    final task = widget.task != null
        ? widget.task!.copyWith(
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            goalId: _selectedGoalId,
            dueDate: _dueDate,
            isDailyTarget: _isDailyTarget,
            updatedAt: now,
          )
        : Task(
            id: const Uuid().v4(),
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            goalId: _selectedGoalId,
            dueDate: _dueDate,
            isDailyTarget: _isDailyTarget,
            createdAt: now,
            updatedAt: now,
          );

    if (widget.task != null) {
      ref.read(tasksProvider.notifier).updateTask(task);
    } else {
      ref.read(tasksProvider.notifier).addTask(task);
    }

    // Save or delete linked reminder
    final reminderRepo = ref.read(reminderRepositoryProvider);
    if (_reminderEnabled) {
      final remId = _existingReminderId ?? const Uuid().v4();
      final reminder = ReminderConfig(
        id: remId,
        targetType: 'task',
        targetId: task.id,
        title: '🎯 Task Due: ${task.title}',
        description: task.description ?? 'Keep momentum going and complete ${task.title}!',
        triggerType: _reminderTriggerType,
        intervalMinutes: _reminderIntervalMinutes,
        windowStartHour: _windowStartTime.hour,
        windowStartMinute: _windowStartTime.minute,
        windowEndHour: _windowEndTime.hour,
        windowEndMinute: _windowEndTime.minute,
        fixedHour: _fixedTime.hour,
        fixedMinute: _fixedTime.minute,
        daysOfWeek: _reminderDaysOfWeek,
        priority: _reminderPriority,
        isSticky: _reminderIsSticky,
        soundMode: _reminderSoundMode,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      );
      reminderRepo.saveReminder(reminder);
      ref.read(remindersProvider.notifier).loadReminders();
    } else if (_existingReminderId != null) {
      reminderRepo.deleteReminder(_existingReminderId!);
      ref.read(remindersProvider.notifier).loadReminders();
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalsState = ref.watch(goalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AreteTextField(
          label: 'Task Title',
          hint: 'What needs to be done?',
          controller: _titleController,
          autofocus: widget.task == null,
        ),
        const SizedBox(height: 14),
        AreteTextField(
          label: 'Description (optional)',
          hint: 'Add helpful context or next physical step...',
          controller: _descController,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        // Goal selector
        goalsState.when(
          data: (goals) {
            if (goals.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AreteDropdownFormField<String?>(
                label: 'Linked Goal (optional)',
                value: _selectedGoalId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None (Standalone Task)'),
                  ),
                  ...goals.map(
                    (g) => DropdownMenuItem<String?>(
                      value: g.id,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: g.color != null
                                  ? Color(int.parse(g.color!.replaceFirst('#', '0xFF')))
                                  : theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              g.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedGoalId = val;
                  });
                },
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // Priority Tags
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Priority', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPriorityChip('High', Colors.redAccent),
                const SizedBox(width: 8),
                _buildPriorityChip('Medium', Colors.amber),
                const SizedBox(width: 8),
                _buildPriorityChip('Low', Colors.green),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),

        // Daily target toggle & Due date
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Add to Daily Focus Target'),
                value: _isDailyTarget,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) {
                  setState(() {
                    _isDailyTarget = val ?? false;
                    if (_isDailyTarget && _dueDate == null) {
                      _dueDate = AppDateUtils.todayIso;
                    }
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Dedicated Notification & Schedule Section
        ReminderConfigSection(
          isEnabled: _reminderEnabled,
          onEnabledChanged: (val) => setState(() => _reminderEnabled = val),
          triggerType: _reminderTriggerType,
          onTriggerTypeChanged: (val) => setState(() => _reminderTriggerType = val),
          intervalMinutes: _reminderIntervalMinutes,
          onIntervalMinutesChanged: (val) => setState(() => _reminderIntervalMinutes = val),
          windowStartTime: _windowStartTime,
          onWindowStartTimeChanged: (val) => setState(() => _windowStartTime = val),
          windowEndTime: _windowEndTime,
          onWindowEndTimeChanged: (val) => setState(() => _windowEndTime = val),
          fixedTime: _fixedTime,
          onFixedTimeChanged: (val) => setState(() => _fixedTime = val),
          daysOfWeek: _reminderDaysOfWeek,
          onDaysOfWeekChanged: (val) => setState(() => _reminderDaysOfWeek = val),
          priority: _reminderPriority,
          onPriorityChanged: (val) => setState(() => _reminderPriority = val),
          isSticky: _reminderIsSticky,
          onStickyChanged: (val) => setState(() => _reminderIsSticky = val),
          soundMode: _reminderSoundMode,
          onSoundModeChanged: (val) => setState(() => _reminderSoundMode = val),
          onTestNotification: () {
            final title = _titleController.text.trim().isEmpty ? 'Active Task' : _titleController.text.trim();
            final dummy = ReminderConfig(
              id: 'test_task_preview',
              targetType: 'task',
              title: '🎯 Task Due: $title',
              description: _descController.text.trim().isEmpty ? 'Wrap up and complete your task!' : _descController.text.trim(),
              triggerType: _reminderTriggerType,
              intervalMinutes: _reminderIntervalMinutes,
              priority: _reminderPriority,
              isSticky: _reminderIsSticky,
              soundMode: _reminderSoundMode,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            ref.read(notificationServiceProvider).showFlexibleReminderNow(dummy);
          },
        ),

        const SizedBox(height: 24),
        AreteButton(
          label: widget.task == null ? 'Create Task' : 'Save Changes',
          onPressed: _save,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildPriorityChip(String label, Color color) {
    final isSelected = _priority == label;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _priority = label);
      },
    );
  }
}
