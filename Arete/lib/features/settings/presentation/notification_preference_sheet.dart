import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_card.dart';
import '../../notifications/data/notification_providers.dart';
import '../../reminders/data/reminder_providers.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/presentation/reminders_management_sheet.dart';
import '../../screentime/data/screen_time_providers.dart';
import '../../screentime/domain/app_category_model.dart';
import '../../screentime/presentation/app_categorization_sheet.dart';

class NotificationPreferenceSheet extends ConsumerStatefulWidget {
  const NotificationPreferenceSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AreteBottomSheet.show(
      context: context,
      title: 'Notifications & Digital Wellness',
      child: const NotificationPreferenceSheet(),
    );
  }

  @override
  ConsumerState<NotificationPreferenceSheet> createState() => _NotificationPreferenceSheetState();
}

class _NotificationPreferenceSheetState extends ConsumerState<NotificationPreferenceSheet>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check of usage permission
    ref.read(screenTimeStatusProvider.notifier).checkUsagePermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(screenTimeStatusProvider.notifier).checkUsagePermission();
      ref.read(screenTimeStatusProvider.notifier).refresh();
      ref.read(notificationPreferencesProvider.notifier).processPendingShadeActions();
      ref.invalidate(notificationPermissionGrantedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notifPrefs = ref.watch(notificationPreferencesProvider);
    final notifNotifier = ref.read(notificationPreferencesProvider.notifier);
    final screenTimeStatus = ref.watch(screenTimeStatusProvider);
    final appsAsync = ref.watch(monitoredAppsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intro subtitle
        Text(
          'Configure native device notifications, habit ritual alarms, scheduled task alerts, and real-time screen time monitoring.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // System Notification Permission Warning Banner (if disabled)
        ref.watch(notificationPermissionGrantedProvider).when(
          data: (isGranted) {
            if (isGranted) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF331B1B) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'System Notifications Disabled',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Android is currently blocking notifications for Areté. Ritual alarms, task alerts, and focus session timers will not appear until notifications are enabled.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white70 : const Color(0xFF7F1D1D),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 16),
                      label: const Text('Enable in App Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () async {
                        await ref.read(notificationServiceProvider).openNotificationSettings();
                        ref.invalidate(notificationPermissionGrantedProvider);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // ----------------------------------------------------
        // SECTION 1: FLEXIBLE RECURRING REMINDERS & INTERVAL TIMERS
        // ----------------------------------------------------
        _buildSectionTitle(context, '⏰ Flexible Recurring Reminders & Interval Timers'),
        AreteCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD2E8D4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_rounded, color: Color(0xFF4D7C5D), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Interval Timers & Priority Reminders',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(
                          'Hydration & stretch intervals, priority notifications & sticky actions',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Consumer(
                builder: (context, ref, _) {
                  final reminders = ref.watch(remindersProvider).valueOrNull ?? [];
                  final activeCount = reminders.where((r) => r.isEnabled).length;
                  final stickyCount = reminders.where((r) => r.isEnabled && r.isSticky).length;
                  final intervalCount = reminders.where((r) => r.isEnabled && r.triggerType == ReminderTriggerType.interval).length;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$activeCount Active',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(height: 2),
                            const Text('Reminders', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        Container(height: 24, width: 1, color: theme.colorScheme.outlineVariant),
                        Column(
                          children: [
                            Text(
                              '$intervalCount Timers',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF4D7C5D)),
                            ),
                            const SizedBox(height: 2),
                            const Text('Intervals', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        Container(height: 24, width: 1, color: theme.colorScheme.outlineVariant),
                        Column(
                          children: [
                            Text(
                              '$stickyCount Sticky',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFE6A23C)),
                            ),
                            const SizedBox(height: 2),
                            const Text('Must Mark Done', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              AreteButton(
                label: 'Manage All Reminders & Intervals',
                variant: AreteButtonVariant.secondary,
                icon: Icons.tune_rounded,
                fullWidth: true,
                onPressed: () => RemindersManagementSheet.show(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ----------------------------------------------------
        // SECTION 2: HABIT REMINDERS
        // ----------------------------------------------------
        _buildSectionTitle(context, '🔔 Daily Habit Ritual Alarms'),
        AreteCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.sagePrimaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alarm_on_rounded, color: AppColors.sageOnPrimaryContainer, size: 20),
                ),
                title: const Text('Habit Ritual Reminders', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Scheduled push notifications to maintain your daily rituals'),
                value: notifPrefs.habitRemindersEnabled,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) => notifNotifier.setHabitRemindersEnabled(val),
              ),
              if (notifPrefs.habitRemindersEnabled) ...[
                const Divider(height: 24),
                // Morning time row
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: notifPrefs.morningTime,
                    );
                    if (picked != null) {
                      notifNotifier.setMorningReminderTime(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_outlined, size: 18, color: Color(0xFFE6A23C)),
                            const SizedBox(width: 10),
                            const Text('Morning Ritual Alert', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            notifPrefs.morningFormatted,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 16),
                // Evening time row
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: notifPrefs.eveningTime,
                    );
                    if (picked != null) {
                      notifNotifier.setEveningReminderTime(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.nightlight_round_outlined, size: 18, color: Color(0xFF6750A4)),
                            const SizedBox(width: 10),
                            const Text('Evening Reflection Alert', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            notifPrefs.eveningFormatted,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '💡 Interactive Action: Notifications include "Done" and "Snooze (10m)" buttons directly in the notification shade.',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ----------------------------------------------------
        // SECTION 2: TASK DUE DATE ALERTS
        // ----------------------------------------------------
        _buildSectionTitle(context, '🎯 Task Deadlines & Reminders'),
        AreteCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8DEF8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_available_rounded, color: Color(0xFF4A4458), size: 20),
                ),
                title: const Text('Task Due Date Alerts', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Notifications when scheduled tasks are due today'),
                value: notifPrefs.taskAlertsEnabled,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) => notifNotifier.setTaskAlertsEnabled(val),
              ),
              if (notifPrefs.taskAlertsEnabled) ...[
                const Divider(height: 20),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('15-Minute Advance Warning', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Get a heads-up warning 15 minutes before the exact due time'),
                  value: notifPrefs.taskFifteenMinWarning,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => notifNotifier.setTaskFifteenMinWarning(val),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ----------------------------------------------------
        // SECTION 3: REAL-TIME SCREEN TIME & USAGE MONITOR
        // ----------------------------------------------------
        _buildSectionTitle(context, '📊 Real-Time Screen Time & Status Bar Monitor'),
        AreteCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDDB3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.screen_lock_portrait_rounded, color: Color(0xFFC04E00), size: 20),
                ),
                title: const Text('Screen Time Tracker Notification', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Persistent status bar notification showing total screen time and active app duration'),
                value: notifPrefs.screenTimeMonitoringEnabled,
                activeColor: theme.colorScheme.primary,
                onChanged: (val) async {
                  await notifNotifier.setScreenTimeMonitoringEnabled(val);
                  if (val) {
                    await ref.read(screenTimeStatusProvider.notifier).startMonitoring();
                  } else {
                    await ref.read(screenTimeStatusProvider.notifier).stopMonitoring();
                  }
                },
              ),

              // Usage Permission Banner if required
              if (notifPrefs.screenTimeMonitoringEnabled && !screenTimeStatus.hasUsagePermission) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDDB3).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFF7A59).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security_update_warning_rounded, color: Color(0xFFC04E00), size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Android Usage Access Required',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF752B00)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Areté needs Android "Usage Access" permission to read screen time and detect foreground distraction apps.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      AreteButton(
                        label: 'Grant Usage Access in Settings',
                        icon: Icons.open_in_new_rounded,
                        variant: AreteButtonVariant.primary,
                        onPressed: () => ref.read(screenTimeStatusProvider.notifier).openSettings(),
                      ),
                    ],
                  ),
                ),
              ],

              // Active Screen Time Preview Card
              if (notifPrefs.screenTimeMonitoringEnabled) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            screenTimeStatus.formattedTotalScreenTime,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const Text('Total Today', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                      Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
                      Column(
                        children: [
                          Text(
                            screenTimeStatus.currentAppName.isNotEmpty ? screenTimeStatus.currentAppName : 'System',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Active (${screenTimeStatus.formattedCurrentAppTime})',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Distraction Limit Threshold
                Text(
                  'Daily Distraction Warning Limit',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'Warns you and triggers Focus Shield when you spend too much continuous time in a distraction app.',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [15, 30, 45, 60, 90].map((mins) {
                    final isSelected = notifPrefs.distractionLimitMinutes == mins;
                    return ChoiceChip(
                      label: Text('$mins mins'),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : null,
                      ),
                      onSelected: (_) {
                        notifNotifier.setDistractionLimitMinutes(mins);
                        ref.read(screenTimeRepositoryProvider).setDistractionPreferences(
                              limitMinutes: mins,
                              autoShield: notifPrefs.autoShieldOnLimit,
                            );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Focus Shield on Limit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Automatically shield distracting apps for 25 mins when the daily limit is hit'),
                  value: notifPrefs.autoShieldOnLimit,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    notifNotifier.setAutoShieldOnLimit(val);
                    ref.read(screenTimeRepositoryProvider).setDistractionPreferences(
                          limitMinutes: notifPrefs.distractionLimitMinutes,
                          autoShield: val,
                        );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ----------------------------------------------------
        // SECTION 4: APP CATEGORIZATION EDITOR
        // ----------------------------------------------------
        _buildSectionTitle(context, '🏷️ App Productivity Categorization'),
        AreteCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.sagePrimaryContainer,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Icon(Icons.category_rounded, color: AppColors.sageOnPrimaryContainer, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Classification Engine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        appsAsync.when(
                          loading: () => const Text('Loading installed apps...', style: TextStyle(fontSize: 12)),
                          error: (_, __) => const Text('App list available', style: TextStyle(fontSize: 12)),
                          data: (apps) {
                            final productive = apps.where((a) => a.category == AppCategory.productive).length;
                            final distraction = apps.where((a) => a.category == AppCategory.distraction).length;
                            final neutral = apps.where((a) => a.category == AppCategory.neutral).length;
                            return Text(
                              '🎯 $productive Productive • ⚠️ $distraction Distraction • ⚪ $neutral Neutral',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AreteButton(
                label: 'Edit App Categories & Distraction Rules',
                icon: Icons.tune_rounded,
                variant: AreteButtonVariant.secondary,
                fullWidth: true,
                onPressed: () => AppCategorizationSheet.show(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
