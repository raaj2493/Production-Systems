import 'package:flutter/material.dart';
import '../domain/reminder_model.dart';

class ReminderConfigSection extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onEnabledChanged;
  final ReminderTriggerType triggerType;
  final ValueChanged<ReminderTriggerType> onTriggerTypeChanged;
  final int intervalMinutes;
  final ValueChanged<int> onIntervalMinutesChanged;
  final TimeOfDay windowStartTime;
  final ValueChanged<TimeOfDay> onWindowStartTimeChanged;
  final TimeOfDay windowEndTime;
  final ValueChanged<TimeOfDay> onWindowEndTimeChanged;
  final TimeOfDay fixedTime;
  final ValueChanged<TimeOfDay> onFixedTimeChanged;
  final List<int> daysOfWeek;
  final ValueChanged<List<int>> onDaysOfWeekChanged;
  final ReminderPriority priority;
  final ValueChanged<ReminderPriority> onPriorityChanged;
  final bool isSticky;
  final ValueChanged<bool> onStickyChanged;
  final ReminderSound soundMode;
  final ValueChanged<ReminderSound> onSoundModeChanged;
  final VoidCallback? onTestNotification;

  const ReminderConfigSection({
    super.key,
    required this.isEnabled,
    required this.onEnabledChanged,
    required this.triggerType,
    required this.onTriggerTypeChanged,
    required this.intervalMinutes,
    required this.onIntervalMinutesChanged,
    required this.windowStartTime,
    required this.onWindowStartTimeChanged,
    required this.windowEndTime,
    required this.onWindowEndTimeChanged,
    required this.fixedTime,
    required this.onFixedTimeChanged,
    required this.daysOfWeek,
    required this.onDaysOfWeekChanged,
    required this.priority,
    required this.onPriorityChanged,
    required this.isSticky,
    required this.onStickyChanged,
    required this.soundMode,
    required this.onSoundModeChanged,
    this.onTestNotification,
  });

  static const List<int> _intervalPresets = [15, 30, 45, 60, 90, 120];

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // M3 Tonal Container Colors
    final containerBg = isDark ? const Color(0xFF232826) : const Color(0xFFF4F1EA);
    final highlightSage = isDark ? const Color(0xFF2D3C32) : const Color(0xFFD2E8D4);
    final lavenderTonal = isDark ? const Color(0xFF32283D) : const Color(0xFFE8DEF8);
    final amberTonal = isDark ? const Color(0xFF3D3220) : const Color(0xFFFFDDB3);

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: highlightSage,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification & Schedule',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Interval timer, fixed alarm & sticky actions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isEnabled,
                activeColor: theme.colorScheme.primary,
                onChanged: onEnabledChanged,
              ),
            ],
          ),

          if (isEnabled) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 1. TRIGGER TYPE SELECTOR
            Text(
              'TRIGGER TYPE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ReminderTriggerType>(
              segments: const [
                ButtonSegment(
                  value: ReminderTriggerType.interval,
                  label: Text('⏱ Interval Timer'),
                ),
                ButtonSegment(
                  value: ReminderTriggerType.fixedTime,
                  label: Text('⏰ Fixed Time'),
                ),
              ],
              selected: {triggerType},
              onSelectionChanged: (set) => onTriggerTypeChanged(set.first),
            ),
            const SizedBox(height: 16),

            // 2. CONFIGURATION DEPENDING ON TRIGGER TYPE
            if (triggerType == ReminderTriggerType.interval) ...[
              // Interval chip presets
              Text(
                'Repeat Interval',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _intervalPresets.map((mins) {
                  final isSelected = intervalMinutes == mins;
                  final label = mins >= 60
                      ? (mins == 60 ? '1 hour' : '${mins ~/ 60}h ${mins % 60}m')
                      : '$mins mins';
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: highlightSage,
                    onSelected: (val) {
                      if (val) onIntervalMinutesChanged(mins);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Active Window Pickers
              Text(
                'Active Daily Window',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Reminders repeat only within this window. Pauses silently at night.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                      label: Text(
                        'From ${_formatTime(windowStartTime)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: windowStartTime,
                        );
                        if (picked != null) onWindowStartTimeChanged(picked);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.nightlight_outlined, size: 18),
                      label: Text(
                        'Until ${_formatTime(windowEndTime)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: windowEndTime,
                        );
                        if (picked != null) onWindowEndTimeChanged(picked);
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Fixed Time picker
              Text(
                'Trigger Time',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.access_time_rounded, size: 20),
                label: Text(
                  'At ${_formatTime(fixedTime)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: fixedTime,
                  );
                  if (picked != null) onFixedTimeChanged(picked);
                },
              ),
              const SizedBox(height: 14),

              // Recurrence Days
              Text(
                'Recurrence Days',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _weekdays.map((item) {
                  final int day = item['day'];
                  final String label = item['label'];
                  final isSelected = daysOfWeek.contains(day);

                  return GestureDetector(
                    onTap: () {
                      final updated = List<int>.from(daysOfWeek);
                      if (!isSelected) {
                        updated.add(day);
                        updated.sort();
                      } else if (updated.length > 1) {
                        updated.remove(day);
                      }
                      onDaysOfWeekChanged(updated);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? highlightSage
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
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
                                ? (isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623))
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 3. PRIORITY TIERS
            Text(
              'PRIORITY TIER',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: ReminderPriority.values.map((p) {
                final isSelected = priority == p;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (p == ReminderPriority.high
                            ? amberTonal
                            : (p == ReminderPriority.medium ? highlightSage : lavenderTonal))
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? p.color : theme.colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onPriorityChanged(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected ? theme.colorScheme.onSurface : null,
                                  ),
                                ),
                                Text(
                                  p.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: p.color, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // 4. STICKY NOTIFICATION MODE
            Container(
              decoration: BoxDecoration(
                color: isSticky ? amberTonal : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSticky ? const Color(0xFFE6A23C) : theme.colorScheme.outlineVariant,
                  width: isSticky ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSticky ? const Color(0xFFE6A23C).withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.push_pin_rounded,
                    color: isSticky ? const Color(0xFFB8741A) : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Sticky Notification (Must Mark Done)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Cannot be cleared with "Clear All". Remains persistent in status bar until user explicitly taps "Mark Done".',
                  style: TextStyle(fontSize: 11.5, height: 1.3),
                ),
                value: isSticky,
                activeColor: const Color(0xFFE6A23C),
                onChanged: onStickyChanged,
              ),
            ),

            const SizedBox(height: 14),

            // 5. SOUND / HAPTIC MODE
            Text(
              'Sound & Haptics',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ReminderSound.values.map((s) {
                final isSelected = soundMode == s;
                return ChoiceChip(
                  label: Text(s.label),
                  selected: isSelected,
                  selectedColor: highlightSage,
                  onSelected: (val) {
                    if (val) onSoundModeChanged(s);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // 6. LIVE SUMMARY BANNER & TEST TRIGGER
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _buildSummaryText(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onTestNotification != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                        label: const Text('Test Notification in Shade Now'),
                        onPressed: onTestNotification,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildSummaryText() {
    final sched = triggerType == ReminderTriggerType.interval
        ? 'Repeats every ${_formatInterval(intervalMinutes)} between ${_formatTime(windowStartTime)} and ${_formatTime(windowEndTime)}'
        : 'Triggers at ${_formatTime(fixedTime)} on ${_formatDays(daysOfWeek)}';
    final stickyStr = isSticky ? ' • Sticky' : '';
    return '$sched ($priorityLabel$stickyStr)';
  }

  String get priorityLabel {
    switch (priority) {
      case ReminderPriority.high:
        return 'High Priority';
      case ReminderPriority.medium:
        return 'Medium Priority';
      case ReminderPriority.low:
        return 'Low Priority';
    }
  }

  static String _formatInterval(int minutes) {
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    } else if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    } else {
      return '$minutes mins';
    }
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  static String _formatDays(List<int> days) {
    if (days.length == 7) return 'Daily';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Mon-Fri';
    }
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return 'Weekends';
    }
    const dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return days.map((d) => dayLabels[d] ?? '').where((s) => s.isNotEmpty).join(', ');
  }
}
