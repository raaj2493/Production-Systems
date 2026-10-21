import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/date_utils.dart';

class HabitHeatmap extends StatelessWidget {
  final Map<String, int> data; // ISO date -> completed count
  final int daysCount;

  const HabitHeatmap({
    super.key,
    required this.data,
    this.daysCount = 28, // 4 weeks
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = AppDateUtils.getDaysRange(daysCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Consistency Matrix',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            Text(
              'Past $daysCount Days',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: days.map((day) {
            final iso = AppDateUtils.toIsoDate(day);
            final count = data[iso] ?? 0;
            final isToday = AppDateUtils.isSameDay(day, DateTime.now());

            Color cellBg;
            if (count >= 3) {
              cellBg = theme.colorScheme.primary;
            } else if (count == 2) {
              cellBg = theme.colorScheme.primary.withValues(alpha: 0.7);
            } else if (count == 1) {
              cellBg = theme.colorScheme.primary.withValues(alpha: 0.4);
            } else {
              cellBg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
            }

            return Tooltip(
              message: '${DateFormat('MMM d').format(day)}: $count habit(s) completed',
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: cellBg,
                  borderRadius: BorderRadius.circular(4),
                  border: isToday
                      ? Border.all(color: theme.colorScheme.onSurface, width: 1.5)
                      : Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
