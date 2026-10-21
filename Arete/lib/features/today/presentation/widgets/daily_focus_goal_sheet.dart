import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_settings_provider.dart';

/// Material 3 Modal Bottom Sheet to configure the Daily Focus Target Goal
class DailyFocusGoalSheet extends ConsumerStatefulWidget {
  final int initialMinutes;

  const DailyFocusGoalSheet({super.key, required this.initialMinutes});

  static Future<void> show(BuildContext context, {required int currentGoalMinutes}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DailyFocusGoalSheet(initialMinutes: currentGoalMinutes),
    );
  }

  @override
  ConsumerState<DailyFocusGoalSheet> createState() => _DailyFocusGoalSheetState();
}

class _DailyFocusGoalSheetState extends ConsumerState<DailyFocusGoalSheet> {
  late int _selectedMinutes;

  static const List<int> _quickPresets = [30, 45, 60, 90, 120, 150, 180, 240];

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialMinutes;
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes / 60.0;
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours ${hours == 1 ? 'hr' : 'hrs'}';
    }
    return '${h.toStringAsFixed(1)} hrs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: bottomInset + bottomSafe + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E231F) : const Color(0xFFFBFBF6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFDDD7CC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF283B2F) : const Color(0xFFD2E8D4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  size: 20,
                  color: isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Daily Focus Goal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Target deep work time per day',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Big Live Value Display Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252C27) : const Color(0xFFFAF8F5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2DDD3),
                width: 1.0,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _formatMinutes(_selectedMinutes),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_selectedMinutes minutes of focused deep work',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Quick Presets
          Text(
            'Quick Presets',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickPresets.map((preset) {
              final isSelected = _selectedMinutes == preset;
              return ChoiceChip(
                label: Text(_formatMinutes(preset)),
                selected: isSelected,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isSelected
                      ? (isDark ? const Color(0xFF101C14) : Colors.white)
                      : theme.colorScheme.onSurface,
                ),
                selectedColor: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35),
                backgroundColor: isDark ? const Color(0xFF252C27) : const Color(0xFFFAF8F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? Colors.white12 : const Color(0xFFE2DDD3)),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedMinutes = preset;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Custom Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom Target',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$_selectedMinutes m',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35),
              thumbColor: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35),
              inactiveTrackColor: isDark ? Colors.white12 : const Color(0xFFDDD7CC),
              trackHeight: 6,
            ),
            child: Slider(
              value: _selectedMinutes.toDouble().clamp(15.0, 360.0),
              min: 15.0,
              max: 360.0,
              divisions: 23, // 15m increments from 15m to 360m
              onChanged: (val) {
                setState(() {
                  _selectedMinutes = val.round();
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35),
                foregroundColor: isDark ? const Color(0xFF101C14) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: () {
                ref.read(appSettingsProvider.notifier).setDailyFocusGoalMinutes(_selectedMinutes);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Daily focus goal set to ${_formatMinutes(_selectedMinutes)}'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Save Focus Goal',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
