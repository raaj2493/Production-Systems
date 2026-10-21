import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/arete_bottom_sheet.dart';
import '../../../progress/data/consistency_matrix_provider.dart';
import '../../../progress/domain/daily_consistency_model.dart';

class ConsistencyMatrixCard extends ConsumerWidget {
  const ConsistencyMatrixCard({super.key});

  Color _getCellColor(int level, bool isDark) {
    switch (level) {
      case 4: // 120m+
        return isDark ? const Color(0xFF86D99B) : const Color(0xFF1B3623);
      case 3: // 60m+
        return isDark ? const Color(0xFF457A56) : const Color(0xFF4D7C5D);
      case 2: // 30m+
        return isDark ? const Color(0xFF2E4D38) : const Color(0xFFD2E8D4);
      case 1: // 1-29m or habit/task
        return isDark ? const Color(0xFF23362A) : const Color(0xFFE2F1E4);
      case 0: // 0m
      default:
        return isDark ? const Color(0xFF252C27) : const Color(0xFFE6E1D6);
    }
  }

  void _showDayDetails(BuildContext context, DailyConsistency day) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormatted = DateFormat('EEEE, MMM d, y').format(day.date);

    AreteBottomSheet.show(
      context: context,
      title: 'Daily Momentum',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFormatted,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF283B2F) : const Color(0xFFD2E8D4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  day.dayStatusBadge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3 Detailed Metric Tiles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B201D) : const Color(0xFFF4F1EA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2DDD3),
              ),
            ),
            child: Column(
              children: [
                _buildMetricRow(
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFFF7A59),
                  label: 'Deep Work Focused',
                  value: day.formattedFocusTime,
                  context: context,
                ),
                const Divider(height: 20),
                _buildMetricRow(
                  icon: Icons.repeat_rounded,
                  iconColor: isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35),
                  label: 'Habits Completed',
                  value: '${day.habitsCompleted} completed',
                  context: context,
                ),
                const Divider(height: 20),
                _buildMetricRow(
                  icon: Icons.check_circle_rounded,
                  iconColor: isDark ? const Color(0xFFFFB77D) : const Color(0xFF5A2D00),
                  label: 'Action Items Cleared',
                  value: '${day.tasksCompleted} tasks done',
                  context: context,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              day.hasActivity
                  ? 'Consistent progress builds unstoppable momentum.'
                  : 'Rest and recovery fuel your next deep work sprint.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final summaryAsync = ref.watch(consistencyMatrixProvider);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        final streakLabel = summary.currentStreak > 0
            ? '🔥 ${summary.currentStreak}d Streak • ${summary.weeklyFocusHours}h This Week'
            : '⚡ ${summary.weeklyFocusHours}h This Week';

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E231F) : const Color(0xFFF4F1EA),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2DDD3),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Single-Line Micro-Stats Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF283B2F)
                                : const Color(0xFFD2E8D4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 15,
                            color: isDark
                                ? const Color(0xFFD2E8D4)
                                : const Color(0xFF1B3623),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Consistency Matrix',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF252C27)
                            : const Color(0xFFEAE5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        streakLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF7A59),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 2. Compact 2-Row x 14-Day Momentum Bar (28 Days Total)
              Column(
                children: List.generate(2, (rowIndex) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: rowIndex == 0 ? 4 : 0),
                    child: Row(
                      children: List.generate(14, (colIndex) {
                        final itemIndex = (rowIndex * 14) + colIndex;
                        if (itemIndex >= summary.days.length) {
                          return const Expanded(child: SizedBox());
                        }

                        final day = summary.days[itemIndex];
                        final cellColor = _getCellColor(day.intensityLevel, isDark);
                        final isToday = day.isToday;

                        return Expanded(
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () => _showDayDetails(context, day),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(4),
                                    border: isToday
                                        ? Border.all(
                                            color: isDark
                                                ? Colors.white
                                                : theme.colorScheme.primary,
                                            width: 1.8,
                                          )
                                        : Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.05)
                                                : Colors.black.withValues(alpha: 0.04),
                                            width: 0.5,
                                          ),
                                    boxShadow: isToday
                                        ? [
                                            BoxShadow(
                                              color: (isDark
                                                      ? Colors.white
                                                      : theme.colorScheme.primary)
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 10),

              // 3. Low-Visual-Noise Micro Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '28-day momentum • Tap day for details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '0m',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildLegendBox(_getCellColor(0, isDark), isDark),
                      const SizedBox(width: 3),
                      _buildLegendBox(_getCellColor(2, isDark), isDark),
                      const SizedBox(width: 3),
                      _buildLegendBox(_getCellColor(3, isDark), isDark),
                      const SizedBox(width: 3),
                      _buildLegendBox(_getCellColor(4, isDark), isDark),
                      const SizedBox(width: 4),
                      Text(
                        '120m+',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendBox(Color color, bool isDark) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.5),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.5,
        ),
      ),
    );
  }
}
