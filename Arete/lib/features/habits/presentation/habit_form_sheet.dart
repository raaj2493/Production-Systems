import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../../notifications/data/notification_providers.dart';
import '../../reminders/data/reminder_providers.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/presentation/reminder_config_section.dart';
import '../data/habit_repository.dart';
import '../domain/habit_model.dart';

class HabitFormSheet extends ConsumerStatefulWidget {
  final Habit? habit;

  const HabitFormSheet({super.key, this.habit});

  static Future<void> show(BuildContext context, {Habit? habit}) {
    return AreteBottomSheet.show(
      context: context,
      title: habit == null ? 'New Habit' : 'Edit Habit',
      child: HabitFormSheet(habit: habit),
    );
  }

  @override
  ConsumerState<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<HabitFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late String _frequencyType;
  late List<int> _customDays;
  late Color _selectedColor;

  // Reminder configuration state
  bool _reminderEnabled = false;
  ReminderTriggerType _reminderTriggerType = ReminderTriggerType.fixedTime;
  int _reminderIntervalMinutes = 60;
  TimeOfDay _windowStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _windowEndTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _fixedTime = const TimeOfDay(hour: 8, minute: 30);
  List<int> _reminderDaysOfWeek = const [1, 2, 3, 4, 5, 6, 7];
  ReminderPriority _reminderPriority = ReminderPriority.medium;
  bool _reminderIsSticky = false;
  ReminderSound _reminderSoundMode = ReminderSound.gentleChime;
  String? _existingReminderId;

  static const List<Map<String, dynamic>> _weekdays = [
    {'day': 1, 'label': 'M'},
    {'day': 2, 'label': 'T'},
    {'day': 3, 'label': 'W'},
    {'day': 4, 'label': 'T'},
    {'day': 5, 'label': 'F'},
    {'day': 6, 'label': 'S'},
    {'day': 7, 'label': 'S'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.habit?.title ?? '');
    _descController = TextEditingController(text: widget.habit?.description ?? '');
    _frequencyType = widget.habit?.frequencyType ?? 'daily';
    _customDays = widget.habit != null ? List<int>.from(widget.habit!.customDays) : [1, 2, 3, 4, 5];
    if (widget.habit?.color != null) {
      _selectedColor = Color(int.parse(widget.habit!.color!.replaceFirst('#', '0xFF')));
    } else {
      _selectedColor = AppColors.categoryPalette[0]; // Sage
    }

    if (widget.habit != null) {
      _loadLinkedReminder(widget.habit!.id);
    }
  }

  Future<void> _loadLinkedReminder(String habitId) async {
    final r = await ref.read(reminderRepositoryProvider).getReminderForTarget('habit', habitId);
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

    final hexColor = '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    final now = DateTime.now();

    final habit = widget.habit != null
        ? widget.habit!.copyWith(
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            frequencyType: _frequencyType,
            customDays: _frequencyType == 'daily' ? [1, 2, 3, 4, 5, 6, 7] : _customDays,
            color: hexColor,
          )
        : Habit(
            id: const Uuid().v4(),
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            frequencyType: _frequencyType,
            customDays: _frequencyType == 'daily' ? [1, 2, 3, 4, 5, 6, 7] : _customDays,
            color: hexColor,
            createdAt: now,
          );

    if (widget.habit != null) {
      ref.read(habitsProvider.notifier).updateHabit(habit);
    } else {
      ref.read(habitsProvider.notifier).addHabit(habit);
    }

    // Save or delete linked reminder
    final reminderRepo = ref.read(reminderRepositoryProvider);
    if (_reminderEnabled) {
      final remId = _existingReminderId ?? const Uuid().v4();
      final reminder = ReminderConfig(
        id: remId,
        targetType: 'habit',
        targetId: habit.id,
        title: '⏰ Habit Ritual: ${habit.title}',
        description: habit.description ?? 'Time to keep your streak going with ${habit.title}!',
        triggerType: _reminderTriggerType,
        intervalMinutes: _reminderIntervalMinutes,
        windowStartHour: _windowStartTime.hour,
        windowStartMinute: _windowStartTime.minute,
        windowEndHour: _windowEndTime.hour,
        windowEndMinute: _windowEndTime.minute,
        fixedHour: _fixedTime.hour,
        fixedMinute: _fixedTime.minute,
        daysOfWeek: _reminderTriggerType == ReminderTriggerType.fixedTime
            ? (_frequencyType == 'daily' ? const [1, 2, 3, 4, 5, 6, 7] : _customDays)
            : _reminderDaysOfWeek,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AreteTextField(
          label: 'Habit Title',
          hint: 'e.g. 15-Minute Daily Reflection, Read Documentation',
          controller: _titleController,
          autofocus: widget.habit == null,
        ),
        const SizedBox(height: 14),
        AreteTextField(
          label: 'Description / Cue (optional)',
          hint: 'After morning coffee, or before starting computer work...',
          controller: _descController,
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        Text('Schedule Frequency', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'daily', label: Text('Every Day')),
            ButtonSegment(value: 'weekdays', label: Text('Custom Days')),
          ],
          selected: {_frequencyType},
          onSelectionChanged: (set) => setState(() => _frequencyType = set.first),
        ),
        const SizedBox(height: 14),

        if (_frequencyType == 'weekdays') ...[
          Text('Active Weekdays', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weekdays.map((item) {
              final int day = item['day'];
              final String label = item['label'];
              final isSelected = _customDays.contains(day);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (!isSelected) {
                      _customDays.add(day);
                      _customDays.sort();
                    } else if (_customDays.length > 1) {
                      _customDays.remove(day);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : (theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: isSelected ? 1.6 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],

        Text('Color Accent', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: AppColors.categoryPalette.map((color) {
            final isSelected = color.toARGB32() == _selectedColor.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
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
            final title = _titleController.text.trim().isEmpty ? 'Habit Ritual' : _titleController.text.trim();
            final dummy = ReminderConfig(
              id: 'test_habit_preview',
              targetType: 'habit',
              title: '⏰ Habit Ritual: $title',
              description: _descController.text.trim().isEmpty ? 'Time for your ritual. Keep your streak alive!' : _descController.text.trim(),
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
          label: widget.habit == null ? 'Create Habit' : 'Save Changes',
          onPressed: _save,
          fullWidth: true,
        ),
      ],
    );
  }
}
