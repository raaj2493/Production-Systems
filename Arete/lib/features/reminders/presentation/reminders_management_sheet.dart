import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../../notifications/data/notification_providers.dart';
import '../data/reminder_providers.dart';
import '../domain/reminder_model.dart';
import 'reminder_config_section.dart';

class RemindersManagementSheet extends ConsumerStatefulWidget {
  const RemindersManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AreteBottomSheet.show(
      context: context,
      title: 'Reminders & Interval Timers',
      child: const RemindersManagementSheet(),
    );
  }

  @override
  ConsumerState<RemindersManagementSheet> createState() => _RemindersManagementSheetState();
}

class _RemindersManagementSheetState extends ConsumerState<RemindersManagementSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remindersAsync = ref.watch(remindersProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Manage recurring hydration and stretch interval timers, habit triggers, priority alerts, and un-dismissible sticky notifications.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Quick Presets Carousel / Cards
        Text(
          'RECOMMENDED INTERVAL & RITUAL PRESETS',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetCard(
                icon: Icons.water_drop_rounded,
                title: 'Drink Water',
                subtitle: 'Every 1h • 9 AM–9 PM',
                badge: 'Sticky • High',
                color: const Color(0xFFD2E8D4),
                accentColor: const Color(0xFF4D7C5D),
                onTap: () => _applyPreset(
                  title: 'Drink Water',
                  description: 'Hydration time! Drink a glass of water to keep energy high.',
                  triggerType: ReminderTriggerType.interval,
                  intervalMinutes: 60,
                  startHour: 9,
                  endHour: 21,
                  priority: ReminderPriority.high,
                  isSticky: true,
                ),
              ),
              const SizedBox(width: 10),
              _buildPresetCard(
                icon: Icons.accessibility_new_rounded,
                title: 'Desk Stretch & Rest',
                subtitle: 'Every 45m • 10 AM–6 PM',
                badge: 'Medium Priority',
                color: const Color(0xFFE8DEF8),
                accentColor: const Color(0xFF6750A4),
                onTap: () => _applyPreset(
                  title: 'Desk Stretch & Eye Rest',
                  description: 'Look 20 feet away for 20 seconds and stretch your neck and shoulders.',
                  triggerType: ReminderTriggerType.interval,
                  intervalMinutes: 45,
                  startHour: 10,
                  endHour: 18,
                  priority: ReminderPriority.medium,
                  isSticky: false,
                ),
              ),
              const SizedBox(width: 10),
              _buildPresetCard(
                icon: Icons.menu_book_rounded,
                title: 'Evening Reading',
                subtitle: 'Daily at 10:00 PM',
                badge: 'Standard Drawer',
                color: const Color(0xFFFFDDB3),
                accentColor: const Color(0xFFB8741A),
                onTap: () => _applyPreset(
                  title: 'Evening Book Reading',
                  description: 'Unwind and read 10 pages before sleep.',
                  triggerType: ReminderTriggerType.fixedTime,
                  intervalMinutes: 60,
                  fixedHour: 22,
                  fixedMinute: 0,
                  priority: ReminderPriority.medium,
                  isSticky: false,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE REMINDERS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: theme.colorScheme.primary,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Custom'),
              onPressed: () => _openCustomReminderEditor(context),
            ),
          ],
        ),
        const SizedBox(height: 8),

        remindersAsync.when(
          data: (reminders) {
            if (reminders.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF232826) : const Color(0xFFF4F1EA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.alarm_off_rounded,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No reminders configured yet',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap any recommended preset above or create a custom interval reminder.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: reminders.map((r) => _buildReminderCard(context, r)).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading reminders: $e'),
          ),
        ),

        const SizedBox(height: 20),
        AreteButton(
          label: 'Close',
          variant: AreteButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildPresetCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accentColor, size: 22),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+ Add',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, ReminderConfig reminder) {
    final theme = Theme.of(context);
    final notifier = ref.read(remindersProvider.notifier);
    final notifService = ref.read(notificationServiceProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reminder.isSticky
              ? const Color(0xFFE6A23C)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: reminder.isSticky ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: reminder.priority.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  reminder.triggerType == ReminderTriggerType.interval
                      ? Icons.timer_outlined
                      : Icons.alarm_rounded,
                  color: reminder.priority.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reminder.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              decoration: reminder.isEnabled ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: reminder.isEnabled,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (val) => notifier.toggleReminder(reminder.id, val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reminder.formattedSchedule,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (reminder.description != null && reminder.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reminder.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Chips row
          Row(
            children: [
              // Priority chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: reminder.priority.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: reminder.priority.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      reminder.priority.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: reminder.priority.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (reminder.isSticky) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDDB3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin_rounded, size: 11, color: Color(0xFFB8741A)),
                      SizedBox(width: 4),
                      Text(
                        'Sticky',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB8741A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Test notification in shade
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Test Notification Shade',
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                onPressed: () {
                  notifService.showFlexibleReminderNow(reminder);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Triggered "${reminder.title}" notification in shade!'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              // Edit button
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit Reminder',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _openCustomReminderEditor(context, reminder: reminder),
              ),
              // Delete button
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete Reminder',
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                onPressed: () => notifier.deleteReminder(reminder.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _applyPreset({
    required String title,
    required String description,
    required ReminderTriggerType triggerType,
    required int intervalMinutes,
    int startHour = 9,
    int endHour = 21,
    int fixedHour = 10,
    int fixedMinute = 0,
    required ReminderPriority priority,
    required bool isSticky,
  }) async {
    final now = DateTime.now();
    final reminder = ReminderConfig(
      id: const Uuid().v4(),
      targetType: 'standalone',
      title: title,
      description: description,
      triggerType: triggerType,
      intervalMinutes: intervalMinutes,
      windowStartHour: startHour,
      windowStartMinute: 0,
      windowEndHour: endHour,
      windowEndMinute: 0,
      fixedHour: fixedHour,
      fixedMinute: fixedMinute,
      priority: priority,
      isSticky: isSticky,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(remindersProvider.notifier).saveReminder(reminder);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added preset "$title" and scheduled!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openCustomReminderEditor(BuildContext context, {ReminderConfig? reminder}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderEditorSheet(reminder: reminder),
    );
  }
}

class _ReminderEditorSheet extends ConsumerStatefulWidget {
  final ReminderConfig? reminder;

  const _ReminderEditorSheet({this.reminder});

  @override
  ConsumerState<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends ConsumerState<_ReminderEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late bool _isEnabled;
  late ReminderTriggerType _triggerType;
  late int _intervalMinutes;
  late TimeOfDay _windowStartTime;
  late TimeOfDay _windowEndTime;
  late TimeOfDay _fixedTime;
  late List<int> _daysOfWeek;
  late ReminderPriority _priority;
  late bool _isSticky;
  late ReminderSound _soundMode;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _titleController = TextEditingController(text: r?.title ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    _isEnabled = r?.isEnabled ?? true;
    _triggerType = r?.triggerType ?? ReminderTriggerType.interval;
    _intervalMinutes = r?.intervalMinutes ?? 60;
    _windowStartTime = TimeOfDay(hour: r?.windowStartHour ?? 9, minute: r?.windowStartMinute ?? 0);
    _windowEndTime = TimeOfDay(hour: r?.windowEndHour ?? 21, minute: r?.windowEndMinute ?? 0);
    _fixedTime = TimeOfDay(hour: r?.fixedHour ?? 10, minute: r?.fixedMinute ?? 0);
    _daysOfWeek = r != null ? List<int>.from(r.daysOfWeek) : [1, 2, 3, 4, 5, 6, 7];
    _priority = r?.priority ?? ReminderPriority.medium;
    _isSticky = r?.isSticky ?? false;
    _soundMode = r?.soundMode ?? ReminderSound.gentleChime;
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
    final reminder = widget.reminder != null
        ? widget.reminder!.copyWith(
            title: title,
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            isEnabled: _isEnabled,
            triggerType: _triggerType,
            intervalMinutes: _intervalMinutes,
            windowStartHour: _windowStartTime.hour,
            windowStartMinute: _windowStartTime.minute,
            windowEndHour: _windowEndTime.hour,
            windowEndMinute: _windowEndTime.minute,
            fixedHour: _fixedTime.hour,
            fixedMinute: _fixedTime.minute,
            daysOfWeek: _daysOfWeek,
            priority: _priority,
            isSticky: _isSticky,
            soundMode: _soundMode,
            updatedAt: now,
          )
        : ReminderConfig(
            id: const Uuid().v4(),
            targetType: 'standalone',
            title: title,
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            isEnabled: _isEnabled,
            triggerType: _triggerType,
            intervalMinutes: _intervalMinutes,
            windowStartHour: _windowStartTime.hour,
            windowStartMinute: _windowStartTime.minute,
            windowEndHour: _windowEndTime.hour,
            windowEndMinute: _windowEndTime.minute,
            fixedHour: _fixedTime.hour,
            fixedMinute: _fixedTime.minute,
            daysOfWeek: _daysOfWeek,
            priority: _priority,
            isSticky: _isSticky,
            soundMode: _soundMode,
            createdAt: now,
            updatedAt: now,
          );

    ref.read(remindersProvider.notifier).saveReminder(reminder);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AreteBottomSheet(
      title: widget.reminder == null ? 'New Reminder' : 'Edit Reminder',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AreteTextField(
              label: 'Reminder Title',
              hint: 'e.g. Drink Water, Eye Rest, Stretch',
              controller: _titleController,
              autofocus: widget.reminder == null,
            ),
            const SizedBox(height: 12),
            AreteTextField(
              label: 'Description / Cue (optional)',
              hint: 'Stay hydrated, stretch your body...',
              controller: _descController,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ReminderConfigSection(
              isEnabled: _isEnabled,
              onEnabledChanged: (val) => setState(() => _isEnabled = val),
              triggerType: _triggerType,
              onTriggerTypeChanged: (val) => setState(() => _triggerType = val),
              intervalMinutes: _intervalMinutes,
              onIntervalMinutesChanged: (val) => setState(() => _intervalMinutes = val),
              windowStartTime: _windowStartTime,
              onWindowStartTimeChanged: (val) => setState(() => _windowStartTime = val),
              windowEndTime: _windowEndTime,
              onWindowEndTimeChanged: (val) => setState(() => _windowEndTime = val),
              fixedTime: _fixedTime,
              onFixedTimeChanged: (val) => setState(() => _fixedTime = val),
              daysOfWeek: _daysOfWeek,
              onDaysOfWeekChanged: (val) => setState(() => _daysOfWeek = val),
              priority: _priority,
              onPriorityChanged: (val) => setState(() => _priority = val),
              isSticky: _isSticky,
              onStickyChanged: (val) => setState(() => _isSticky = val),
              soundMode: _soundMode,
              onSoundModeChanged: (val) => setState(() => _soundMode = val),
              onTestNotification: () {
                final dummy = ReminderConfig(
                  id: 'test_preview',
                  targetType: 'standalone',
                  title: _titleController.text.trim().isEmpty ? 'Test Reminder' : _titleController.text.trim(),
                  description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                  triggerType: _triggerType,
                  intervalMinutes: _intervalMinutes,
                  priority: _priority,
                  isSticky: _isSticky,
                  soundMode: _soundMode,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                ref.read(notificationServiceProvider).showFlexibleReminderNow(dummy);
              },
            ),
            const SizedBox(height: 24),
            AreteButton(
              label: widget.reminder == null ? 'Create Reminder' : 'Save Changes',
              onPressed: _save,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
