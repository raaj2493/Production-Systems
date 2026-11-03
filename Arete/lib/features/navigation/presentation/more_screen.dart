import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/arete_card.dart';
import '../../focus/data/focus_repository.dart';
import '../../habits/data/habit_repository.dart';
import '../../habits/presentation/widgets/habit_heatmap.dart';
import '../../tasks/data/task_repository.dart';
import '../../settings/presentation/data_backup_sheet.dart';
import '../../settings/presentation/notification_preference_sheet.dart';
import '../../today/presentation/widgets/interactive_tour_sheet.dart';

final _allTimeFocusSecondsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(focusRepositoryProvider);
  return repo.getTotalFocusSeconds();
});

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final heatmapDataAsync = ref.watch(heatmapDataProvider);
    final habitsState = ref.watch(habitsProvider);
    final tasksState = ref.watch(tasksProvider);
    final totalFocusAsync = ref.watch(_allTimeFocusSecondsProvider);

    // Calculate Quick Stats
    final maxStreak = habitsState.maybeWhen(
      data: (habits) => habits.isEmpty
          ? 0
          : habits.map((h) => h.currentStreak).fold(0, (max, s) => s > max ? s : max),
      orElse: () => 0,
    );

    final totalFocusSec = totalFocusAsync.maybeWhen(
      data: (sec) => sec,
      orElse: () => 0,
    );
    final focusHoursStr = totalFocusSec > 0
        ? '${(totalFocusSec / 3600).toStringAsFixed(1)}h'
        : '0h';

    final taskRateStr = tasksState.maybeWhen(
      data: (tasks) {
        if (tasks.isEmpty) return '0%';
        final completed = tasks.where((t) => t.isCompleted).length;
        return Formatters.formatPercent(completed / tasks.length);
      },
      orElse: () => '0%',
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Hub & Overview'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Hero Habit Consistency Matrix (28 Days)
          AreteCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.grid_view_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Consistency Matrix',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => context.push('/more/progress'),
                      child: const Text('Analytics'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                heatmapDataAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) => HabitHeatmap(data: data, daysCount: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Quick Stats Row (Streak 🔥, Total Focus ⚡, Task Velocity ✅)
          Row(
            children: [
              Expanded(
                child: _buildStatBadge(
                  context,
                  icon: '🔥',
                  label: 'Streak',
                  value: '$maxStreak d',
                  bgColor: const Color(0xFFFDE8E1),
                  textColor: const Color(0xFF6E2E1D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBadge(
                  context,
                  icon: '⚡',
                  label: 'Deep Work',
                  value: focusHoursStr,
                  bgColor: const Color(0xFFFFDDB3),
                  textColor: const Color(0xFF5A2D00),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBadge(
                  context,
                  icon: '✅',
                  label: 'Velocity',
                  value: taskRateStr,
                  bgColor: theme.colorScheme.primaryContainer,
                  textColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. App Theme & Personalization Hub Card
          _buildPersonalizationCard(context, settings, settingsNotifier),

          const SizedBox(height: 14),

          // 4. Hub Feature Cards
          _buildHubCard(
            context,
            icon: Icons.repeat_rounded,
            title: 'Habits & Rituals',
            subtitle: 'Daily routines, consistency matrix, and scheduled rituals',
            badge: habitsState.maybeWhen(
              data: (h) => '${h.length} active',
              orElse: () => null,
            ),
            onTap: () => context.push('/more/habits'),
          ),
          const SizedBox(height: 10),
          _buildHubCard(
            context,
            icon: Icons.note_alt_outlined,
            title: 'Notes & Reflections',
            subtitle: 'Autosaved insights, tagged thoughts, and quick captures',
            onTap: () => context.push('/more/notes'),
          ),
          const SizedBox(height: 10),
          _buildHubCard(
            context,
            icon: Icons.insights_rounded,
            title: 'Progress & Deep Analytics',
            subtitle: 'Task trends, focus time distribution, and completion curves',
            onTap: () => context.push('/more/progress'),
          ),
          _buildHubCard(
            context,
            icon: Icons.auto_awesome_rounded,
            title: 'AI Workspace & JSON Backup',
            subtitle: 'AI prompt generator, import/export for friends, local SQLite',
            badge: 'SYNC',
            onTap: () => DataBackupSheet.show(context),
          ),
          _buildHubCard(
            context,
            icon: Icons.explore_rounded,
            title: 'Guided Feature Tour',
            subtitle: '5-step interactive walkthrough of all core Areté features',
            badge: 'TOUR',
            onTap: () => InteractiveTourSheet.show(context, force: true),
          ),
          _buildHubCard(
            context,
            icon: Icons.pie_chart_outline_rounded,
            title: 'Digital Wellbeing & Screen Time',
            subtitle: 'Phone screen time, unlocks, distraction stats & Shorts/Reels loop blocker',
            badge: 'SYNC',
            onTap: () => context.push('/more/wellbeing'),
          ),
          const SizedBox(height: 10),
          _buildHubCard(
            context,
            icon: Icons.notifications_active_rounded,
            title: 'Notifications & Digital Wellness',
            subtitle: 'Habit alarms, task alerts, screen time & test notifications',
            badge: 'TEST',
            onTap: () => NotificationPreferenceSheet.show(context),
          ),
          const SizedBox(height: 10),
          _buildHubCard(
            context,
            icon: Icons.tune_rounded,
            title: 'Settings & Focus Preferences',
            subtitle: 'Daily targets, timer defaults, and preferences',
            onTap: () => context.push('/more/settings'),
          ),

          const SizedBox(height: 32),

          // 5. Philosophical Footer & Version Tag
          Center(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Areté • Keep Your Word',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.2.0 • Material You 3.0',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100), // Clearance for floating pill nav bar
        ],
      ),
    );
  }

  Widget _buildStatBadge(
    BuildContext context, {
    required String icon,
    required String label,
    required String value,
    required Color bgColor,
    required Color textColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? theme.colorScheme.onSurfaceVariant : textColor.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? theme.colorScheme.onSurface : textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationCard(
    BuildContext context,
    AppSettings settings,
    AppSettingsNotifier settingsNotifier,
  ) {
    final theme = Theme.of(context);

    final palettes = [
      {
        'id': 'sage_coral',
        'name': 'Sage & Coral 🌿',
        'color1': const Color(0xFF2A4E35),
        'color2': const Color(0xFFD2E8D4),
      },
      {
        'id': 'sunset_terracotta',
        'name': 'Terracotta & Oat ☕',
        'color1': const Color(0xFF874B38),
        'color2': const Color(0xFFF5E1D5),
      },
      {
        'id': 'sakura_blossom',
        'name': 'Sakura & Matcha 🌸',
        'color1': const Color(0xFF8A4456),
        'color2': const Color(0xFFF6DAE2),
      },
      {
        'id': 'candy_pop',
        'name': 'Rose & Sand 🪨',
        'color1': const Color(0xFF7D4954),
        'color2': const Color(0xFFF3DADF),
      },
      {
        'id': 'retro_synthwave',
        'name': 'Dusk & Lavender 🪻',
        'color1': const Color(0xFF534C75),
        'color2': const Color(0xFFE2DEF2),
      },
      {
        'id': 'nordic_frost',
        'name': 'Nordic Mist ❄️',
        'color1': const Color(0xFF345468),
        'color2': const Color(0xFFCFE0E8),
      },
      {
        'id': 'cyberpunk_neon',
        'name': 'Matcha & Cream 🍵',
        'color1': const Color(0xFF3D5737),
        'color2': const Color(0xFFDDE8D6),
      },
      {
        'id': 'obsidian_minimal',
        'name': 'Obsidian OLED 🖤',
        'color1': const Color(0xFF27272A),
        'color2': const Color(0xFFD4D4D8),
      },
    ];

    final isDark = settings.themeMode == ThemeMode.dark;

    return AreteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.palette_outlined, color: theme.colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Material You Theme',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dynamic tonal color palettes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () {
                  settingsNotifier.setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Palette Swatches
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: palettes.map((pal) {
              final palId = pal['id'] as String;
              final isSelected = settings.colorPalette == palId ||
                  (palId == 'cyberpunk_neon' && settings.colorPalette == 'cyber_lime') ||
                  (palId == 'nordic_frost' && settings.colorPalette == 'ocean_sunrise');
              final color1 = pal['color1'] as Color;
              final color2 = pal['color2'] as Color;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => settingsNotifier.setColorPalette(pal['id'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dual Color Dot
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: color1,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color2,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pal['name'] as String,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return AreteCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            size: 20,
          ),
        ],
      ),
    );
  }
}
