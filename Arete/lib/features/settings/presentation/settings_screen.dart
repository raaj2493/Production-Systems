import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_dialog.dart';
import '../../../core/widgets/arete_dropdown.dart';
import '../data/backup_service.dart';
import 'notification_preference_sheet.dart';
import 'prompt_generator_sheet.dart';
import '../../notifications/data/notification_providers.dart';
import '../../reminders/presentation/reminders_management_sheet.dart';
import '../../screentime/presentation/app_categorization_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final backupService = ref.watch(backupServiceProvider);
    final notifPrefs = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Backup'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Section: Appearance
          _buildSectionHeader(theme, 'Appearance'),
          AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.brightness_4_outlined),
                  title: const Text('Theme Mode'),
                  subtitle: Text(
                    settings.themeMode == ThemeMode.system
                        ? 'Follow System'
                        : settings.themeMode == ThemeMode.dark
                            ? 'Dark Warmth'
                            : 'Light Cream',
                  ),
                  trailing: AreteDropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        settingsNotifier.setThemeMode(mode);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Daily Targets & Focus Durations
          _buildSectionHeader(theme, 'Daily Focus Preferences'),
          AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.track_changes_outlined),
                  title: const Text('Daily Task Target'),
                  subtitle: const Text('Optimal number of priority tasks per day'),
                  trailing: AreteDropdownButton<int>(
                    value: settings.dailyTaskTarget,
                    items: [1, 2, 3, 4, 5, 6, 7].map((n) {
                      return DropdownMenuItem(
                        value: n,
                        child: Text('$n tasks'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) settingsNotifier.setDailyTaskTarget(val);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.track_changes_rounded),
                  title: const Text('Daily Focus Goal'),
                  subtitle: const Text('Target deep work time per day'),
                  trailing: AreteDropdownButton<int>(
                    value: [30, 45, 60, 90, 120, 150, 180, 240, 300, 360].contains(settings.dailyFocusGoalMinutes)
                        ? settings.dailyFocusGoalMinutes
                        : 120,
                    items: [30, 45, 60, 90, 120, 150, 180, 240, 300, 360].map((m) {
                      final label = m < 60
                          ? '$m min'
                          : (m % 60 == 0
                              ? '${m ~/ 60} ${m == 60 ? 'hr' : 'hrs'}'
                              : '${(m / 60).toStringAsFixed(1)} hrs');
                      return DropdownMenuItem(value: m, child: Text(label));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) settingsNotifier.setDailyFocusGoalMinutes(val);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Default Focus Duration'),
                  trailing: AreteDropdownButton<int>(
                    value: settings.defaultFocusMinutes,
                    items: [15, 20, 25, 30, 45, 50, 60].map((m) {
                      return DropdownMenuItem(value: m, child: Text('$m min'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) settingsNotifier.setFocusMinutes(val);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.coffee_outlined),
                  title: const Text('Short Break Duration'),
                  trailing: AreteDropdownButton<int>(
                    value: settings.defaultShortBreakMinutes,
                    items: [3, 5, 10].map((m) {
                      return DropdownMenuItem(value: m, child: Text('$m min'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) settingsNotifier.setShortBreakMinutes(val);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.weekend_outlined),
                  title: const Text('Long Break Duration'),
                  trailing: AreteDropdownButton<int>(
                    value: settings.defaultLongBreakMinutes,
                    items: [10, 15, 20, 30].map((m) {
                      return DropdownMenuItem(value: m, child: Text('$m min'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) settingsNotifier.setLongBreakMinutes(val);
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Home Screen Duration Presets', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text(
                                  'Select presets to display as quick chips on your Home hero card',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [10, 15, 20, 25, 30, 45, 50, 60, 90].map((mins) {
                          final isSelected = settings.focusDurationPresets.contains(mins);
                          return FilterChip(
                            label: Text('${mins}m'),
                            selected: isSelected,
                            onSelected: (selected) {
                              final updated = List<int>.from(settings.focusDurationPresets);
                              if (selected) {
                                updated.add(mins);
                              } else {
                                if (updated.length > 1) {
                                  updated.remove(mins);
                                }
                              }
                              settingsNotifier.setFocusDurationPresets(updated);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Notifications & Screen Time Monitoring
          _buildSectionHeader(theme, 'Notifications & Screen Time Monitor'),
          AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined, color: Color(0xFF4D7C5D)),
                  title: const Text('Flexible Reminders & Interval Timers', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Hydration, stretch intervals, priority notifications & sticky actions'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => RemindersManagementSheet.show(context),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Habit & Task Reminders'),
                  subtitle: Text(
                    notifPrefs.habitRemindersEnabled
                        ? 'Active • Rituals at ${notifPrefs.morningFormatted} & ${notifPrefs.eveningFormatted}'
                        : 'Reminders disabled',
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => NotificationPreferenceSheet.show(context),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.screen_lock_portrait_outlined),
                  title: const Text('Screen Time & App Tracker'),
                  subtitle: Text(
                    notifPrefs.screenTimeMonitoringEnabled
                        ? 'Active • Status bar notification & ${notifPrefs.distractionLimitMinutes}m limit'
                        : 'Tap to configure persistent monitor & distraction alerts',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (notifPrefs.screenTimeMonitoringEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD2E8D4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'TRACKING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B3623),
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () => NotificationPreferenceSheet.show(context),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('App Classification Engine'),
                  subtitle: const Text('Categorize apps into Productive, Neutral, or Distraction'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => AppCategorizationSheet.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Data & Backup
          _buildSectionHeader(theme, 'Data & Privacy (100% Offline)'),
          AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('Export JSON Backup'),
                  subtitle: const Text('Share or save complete local database backup'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    try {
                      final path = await backupService.exportBackup();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Backup exported to $path')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Export failed: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF7A59)),
                  title: Row(
                    children: [
                      const Text('Import JSON & AI Setup'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A59).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AI SETUP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF7A59),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: const Text('Paste AI JSON from ChatGPT/Gemini, load demo, or pick file'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded, size: 18),
                        tooltip: 'How to generate setup',
                        onPressed: () => PromptGeneratorSheet.show(context),
                      ),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () => PromptGeneratorSheet.show(context),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Quick Import Backup File'),
                  subtitle: const Text('Directly choose an existing .json file from disk'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    final confirmed = await AreteDialog.showConfirmation(
                      context: context,
                      title: 'Restore Backup',
                      message:
                          'Importing a backup will merge or replace your current database records. Proceed?',
                      confirmLabel: 'Select File',
                    );
                    if (confirmed == true) {
                      final success = await backupService.importBackupFromFile(ref);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Backup successfully restored!'
                                  : 'Invalid backup file or operation cancelled.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('Load Sample Starter Data'),
                  subtitle: const Text('Seed sample goals, tasks, and habits'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    await backupService.seedStarterData(ref);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sample starter data loaded.')),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                  title: Text(
                    'Reset All Local Data',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text('Permanently wipe all local tables'),
                  onTap: () async {
                    final confirmed = await AreteDialog.showConfirmation(
                      context: context,
                      title: 'Reset All Data',
                      message:
                          'Are you sure you want to permanently erase all tasks, habits, focus logs, and notes? This cannot be undone.',
                      confirmLabel: 'Erase Everything',
                      isDestructive: true,
                    );
                    if (confirmed == true) {
                      await backupService.resetAllData(ref);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All data cleared.')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Philosophy & About
          _buildSectionHeader(theme, 'About Areté'),
          AreteCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.spa, color: theme.colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Areté',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Keep Your Word. • v1.0.0',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Areté is a calm, personal sanctuary designed around five core principles:\n\n'
                  '• Less planning, more doing.\n'
                  '• Consistency over intensity.\n'
                  '• Clarity over complexity.\n'
                  '• Progress without guilt.\n'
                  '• Intentional design over feature overload.\n\n'
                  '100% offline, zero trackers, zero cloud accounts. Your life belongs to you.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
