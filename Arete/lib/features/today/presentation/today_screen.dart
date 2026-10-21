import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/arete_check_circle.dart';
import '../../../core/widgets/arete_confetti.dart';
import '../../../core/widgets/arete_empty_state.dart';
import '../../focus/data/focus_repository.dart';
import '../../focus/presentation/focus_timer_controller.dart';
import '../../habits/data/habit_repository.dart';
import '../../habits/domain/habit_model.dart';
import '../../habits/presentation/habit_form_sheet.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task_model.dart';
import '../../tasks/presentation/task_form_sheet.dart';
import '../../settings/presentation/data_backup_sheet.dart';
import '../../settings/presentation/notification_preference_sheet.dart';
import '../../settings/presentation/prompt_generator_sheet.dart';
import '../../notifications/data/notification_providers.dart';
import '../../screentime/data/screen_time_providers.dart';
import '../../screentime/domain/screen_time_status_model.dart';
import '../../screentime/domain/app_category_model.dart';
import '../../progress/data/consistency_matrix_provider.dart';
import '../../progress/domain/daily_consistency_model.dart';
import 'widgets/consistency_matrix_card.dart';
import 'widgets/daily_focus_goal_sheet.dart';
import 'widgets/interactive_tour_sheet.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> with WidgetsBindingObserver {
  final AreteConfettiController _confettiController = AreteConfettiController();
  final Set<String> _expandedTaskIds = {};
  late final PageController _carouselController;
  int _carouselIndex = 0;
  bool _notificationBannerDismissed = false;
  bool _hasNotificationPermission = true;

  @override
  void initState() {
    super.initState();
    _carouselController = PageController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialNotificationAction();
      ref.read(notificationPreferencesProvider.notifier).processPendingShadeActions();
      _checkNotificationPermission();

      // Check if user has completed interactive onboarding tour
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          final hasTour = ref.read(appSettingsProvider).hasCompletedTour;
          if (!hasTour) {
            InteractiveTourSheet.show(context);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationPreferencesProvider.notifier).processPendingShadeActions();
      ref.read(screenTimeStatusProvider.notifier).refresh();
      _checkInitialNotificationAction();
      _refreshNotificationPermission();
    }
  }

  Future<void> _checkNotificationPermission() async {
    final notifService = ref.read(notificationServiceProvider);
    final granted = await notifService.isNotificationPermissionGranted();
    if (mounted) {
      setState(() {
        _hasNotificationPermission = granted;
      });
      if (!granted) {
        // Automatically request notification permission on first launch
        await notifService.requestNotificationPermission();
        if (mounted) {
          final afterCheck = await notifService.isNotificationPermissionGranted();
          setState(() {
            _hasNotificationPermission = afterCheck;
          });
        }
      }
    }
  }

  Future<void> _refreshNotificationPermission() async {
    final granted = await ref.read(notificationServiceProvider).isNotificationPermissionGranted();
    if (mounted && _hasNotificationPermission != granted) {
      setState(() {
        _hasNotificationPermission = granted;
      });
    }
  }

  Future<void> _checkInitialNotificationAction() async {
    final action = await ref.read(notificationServiceProvider).getInitialAction();
    if (action != null) {
      if (action['action'] == 'start_focus_session') {
        final duration = (action['durationMinutes'] as num?)?.toInt() ?? 25;
        if (mounted) {
          ref.read(focusTimerProvider.notifier).setCustomMinutes(duration);
          ref.read(focusTimerProvider.notifier).start();
          ref.read(focusTimerProvider.notifier).openZenMode();
          context.go('/focus');
        }
      } else if (action['action'] == 'open_focus_view') {
        if (mounted) {
          context.go('/focus');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final headerDate = AppDateUtils.formatHeaderDate(now);

    final settings = ref.watch(appSettingsProvider);
    final todayTasks = ref.watch(todayTasksProvider);
    final todayHabits = ref.watch(todayHabitsProvider);
    final liveFocusSeconds = ref.watch(liveTodayFocusSecondsProvider);
    final completedSessionsAsync = ref.watch(todayCompletedFocusSessionsProvider);
    final timerState = ref.watch(focusTimerProvider);
    final velocityStats = ref.watch(taskVelocityStatsProvider);
    final screenTimeStatus = ref.watch(screenTimeStatusProvider);
    final consistencySummaryAsync = ref.watch(consistencyMatrixProvider);

    const targetSessionsGoal = 3;
    final completedSessions = (completedSessionsAsync.valueOrNull ?? 0).clamp(0, targetSessionsGoal);
    final isTargetAchieved = completedSessions >= targetSessionsGoal;
    final totalFocusMinutes = liveFocusSeconds ~/ 60;

    final sessionStatusText = completedSessions == 0
        ? (totalFocusMinutes > 0
            ? 'Ready for session 1 • $totalFocusMinutes min focused today.'
            : 'Ready for session 1 • Keep your word, one step at a time.')
        : (completedSessions == 1
            ? '1 deep work block crushed ($totalFocusMinutes min) • Ready for session 2.'
            : (completedSessions == 2
                ? 'Great momentum ($totalFocusMinutes min)! 1 block left to hit daily target.'
                : 'Target achieved ($totalFocusMinutes min focused)! Outstanding consistency.'));

    return AreteConfettiOverlay(
      controller: _confettiController,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keep your word. One step at a time.',
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
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded, size: 20, color: Color(0xFFFF7A59)),
              tooltip: 'AI Setup & Prompt Generator',
              onPressed: () => PromptGeneratorSheet.show(context),
            ),
            IconButton(
              icon: const Icon(Icons.backup_outlined, size: 20),
              tooltip: 'Data Backup & Sync',
              onPressed: () => DataBackupSheet.show(context),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add, size: 22),
              tooltip: 'Add Task',
              onPressed: () => TaskFormSheet.show(context, initialDailyTarget: true),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tasksProvider);
            ref.invalidate(habitsProvider);
            ref.invalidate(todayFocusSecondsProvider);
            ref.invalidate(todayCompletedFocusSessionsProvider);
            ref.invalidate(consistencyMatrixProvider);
            ref.read(screenTimeStatusProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // Notification permission warning banner (if notifications are disabled)
              if (!_hasNotificationPermission && !_notificationBannerDismissed) ...[
                _buildNotificationPermissionBanner(context, isDark),
                const SizedBox(height: 14),
              ],

              // 0. Live Screen Time Status Banner (if monitoring is active)
              if (screenTimeStatus.isMonitoring) ...[
                _buildScreenTimeLiveBanner(context, screenTimeStatus),
                const SizedBox(height: 16),
              ],

              // 1. Top Hero Section: Horizontal Carousel of Slidable Feature Cards
              _buildHeroSnapCarousel(
                context: context,
                isDark: isDark,
                completedSessions: completedSessions,
                targetSessionsGoal: targetSessionsGoal,
                isTargetAchieved: isTargetAchieved,
                sessionStatusText: sessionStatusText,
                timerState: timerState,
                settings: settings,
                todayHabits: todayHabits,
                consistencySummary: consistencySummaryAsync.valueOrNull,
                velocityStats: velocityStats,
                totalFocusMinutes: totalFocusMinutes,
                liveFocusSeconds: liveFocusSeconds,
              ),

              const SizedBox(height: 22),

              // 2. Primary Middle Section: Today's Action Items (Placed Above Graph)
              _buildTodayActionItemsSection(
                context: context,
                isDark: isDark,
                todayTasks: todayTasks,
                velocityStats: velocityStats,
              ),

              const SizedBox(height: 22),

              // 3. Bottom Section: Compact & Concise Consistency Matrix
              const ConsistencyMatrixCard(),

              const SizedBox(height: 18),

              // 4. Daily Inquiry Reflection Card
              _buildDailyInquiryCard(context, isDark),

              // Bottom padding for the floating pill nav bar
              const SizedBox(height: 140),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationPermissionBanner(BuildContext context, bool isDark) {
    final notifService = ref.read(notificationServiceProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2317) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.4) : const Color(0xFFFDBA74),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFEDD5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enable Notifications',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get habit ritual alarms, task alerts, and live focus timer countdowns.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : const Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () async {
              await notifService.requestNotificationPermission();
              await Future.delayed(const Duration(milliseconds: 300));
              final granted = await notifService.isNotificationPermissionGranted();
              if (!granted) {
                await notifService.openNotificationSettings();
              }
              _refreshNotificationPermission();
            },
            child: const Text('Enable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: isDark ? Colors.white54 : Colors.grey,
            onPressed: () {
              setState(() {
                _notificationBannerDismissed = true;
              });
            },
          ),
        ],
      ),
    );
  }

  // --- 1. Top Hero Section: Horizontal Carousel of Slidable Feature Cards ---
  Widget _buildHeroSnapCarousel({
    required BuildContext context,
    required bool isDark,
    required int completedSessions,
    required int targetSessionsGoal,
    required bool isTargetAchieved,
    required String sessionStatusText,
    required FocusTimerState timerState,
    required AppSettings settings,
    required List<Habit> todayHabits,
    required ConsistencyMatrixSummary? consistencySummary,
    required TaskVelocityStats velocityStats,
    required int totalFocusMinutes,
    required int liveFocusSeconds,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 234,
          child: PageView(
            controller: _carouselController,
            physics: const PageScrollPhysics(),
            onPageChanged: (idx) {
              setState(() {
                _carouselIndex = idx;
              });
            },
            children: [
              // Card 1: Daily Focus Target (Simplified Single Continuous Circular Ring)
              _buildDailyFocusTargetCard(
                context: context,
                isDark: isDark,
                totalFocusMinutes: totalFocusMinutes,
                liveFocusSeconds: liveFocusSeconds,
                timerState: timerState,
                settings: settings,
              ),

              // Card 2: Quick Daily Habits Overview
              _buildQuickDailyHabitsCard(
                context: context,
                isDark: isDark,
                todayHabits: todayHabits,
              ),

              // Card 3: Focus Streak & Quick Stats
              _buildFocusStreakStatsCard(
                context: context,
                isDark: isDark,
                consistencySummary: consistencySummary,
                velocityStats: velocityStats,
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Subtle Carousel Page Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final isActive = _carouselIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3.5),
              width: isActive ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35))
                    : (isDark ? Colors.white24 : const Color(0xFFDDD7CC)),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // --- Card 1: Daily Focus Target (Simplified Single Continuous Circular Ring) ---
  Widget _buildDailyFocusTargetCard({
    required BuildContext context,
    required bool isDark,
    required int totalFocusMinutes,
    required int liveFocusSeconds,
    required FocusTimerState timerState,
    required AppSettings settings,
  }) {
    final theme = Theme.of(context);
    final activeMinutes = (timerState.totalSeconds / 60).round();
    final presets = settings.focusDurationPresets.isNotEmpty
        ? settings.focusDurationPresets
        : const [15, 25, 45, 60];

    // Dynamic cumulative focus time vs daily goal from settings (defaults to 120m / 2.0 hrs)
    final dailyGoalMinutes = settings.dailyFocusGoalMinutes > 0
        ? settings.dailyFocusGoalMinutes
        : 120;
    final progress = dailyGoalMinutes > 0
        ? (liveFocusSeconds / (dailyGoalMinutes * 60)).clamp(0.0, 1.0)
        : 0.0;

    final goalDisplay = dailyGoalMinutes < 60
        ? '$dailyGoalMinutes min'
        : (dailyGoalMinutes % 60 == 0
            ? '${dailyGoalMinutes ~/ 60} ${dailyGoalMinutes == 60 ? 'hr' : 'hrs'}'
            : '${(dailyGoalMinutes / 60).toStringAsFixed(1)} hrs');

    // Large bold center time formatting (e.g., "45m" or "1.5h")
    final timeDisplay = totalFocusMinutes >= 60
        ? (totalFocusMinutes % 60 == 0
            ? '${totalFocusMinutes ~/ 60}h'
            : '${(totalFocusMinutes / 60).toStringAsFixed(1)}h')
        : '${totalFocusMinutes}m';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E231F) : const Color(0xFFF4F1EA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2DDD3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Row: Title & Duration Preset Selector Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => DailyFocusGoalSheet.show(context, currentGoalMinutes: dailyGoalMinutes),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF283B2F)
                              : const Color(0xFFD2E8D4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          size: 18,
                          color: isDark
                              ? const Color(0xFFD2E8D4)
                              : const Color(0xFF1B3623),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Daily Focus Target',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Set Daily Focus Goal',
                        child: Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF9CD4A6).withValues(alpha: 0.8)
                              : const Color(0xFF2A4E35).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Preset duration chip (tappable to cycle presets)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  if (timerState.state == TimerState.running) return;
                  final idx = presets.indexOf(activeMinutes);
                  final nextIndex = idx >= 0 ? (idx + 1) % presets.length : 0;
                  ref.read(focusTimerProvider.notifier).setCustomMinutes(presets[nextIndex]);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF283B2F) : const Color(0xFFE2F1E4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF86D99B).withValues(alpha: 0.5)
                          : const Color(0xFF2A4E35).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activeMinutes == 25 ? '25m Pomodoro' : '${activeMinutes}m Focus',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Main Visual Anchor: Big Single Continuous Circular Progress Ring (Thick Stroke with Rounded Ends)
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(focusTimerProvider.notifier).openZenMode();
                context.go('/focus');
              },
              child: SizedBox(
                width: 122,
                height: 122,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(122, 122),
                      painter: _CircularFocusRingPainter(
                        progress: progress,
                        trackColor: isDark
                            ? const Color(0xFF283B2F)
                            : const Color(0xFFE2F1E4),
                        progressColor: isDark
                            ? const Color(0xFF9CD4A6)
                            : const Color(0xFF2A4E35),
                        strokeWidth: 15.0,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeDisplay,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: isDark ? const Color(0xFFE2E4DE) : const Color(0xFF191C19),
                          ),
                        ),
                        const SizedBox(height: 1),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => DailyFocusGoalSheet.show(context, currentGoalMinutes: dailyGoalMinutes),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Goal: $goalDisplay',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : const Color(0xFF3B5643),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Clean Minimal Actions: High-contrast Pause/Resume & Reset buttons
          if (timerState.state == TimerState.running) ...[
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.pause_rounded, size: 16),
                      label: Text(
                        'Pause (${Formatters.formatSeconds(timerState.remainingSeconds)})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35),
                        foregroundColor: isDark ? const Color(0xFF101C14) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => ref.read(focusTimerProvider.notifier).pause(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: () => ref.read(focusTimerProvider.notifier).reset(),
                      child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (timerState.state == TimerState.paused) ...[
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text(
                        'Resume (${Formatters.formatSeconds(timerState.remainingSeconds)})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35),
                        foregroundColor: isDark ? const Color(0xFF101C14) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => ref.read(focusTimerProvider.notifier).resume(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: () => ref.read(focusTimerProvider.notifier).reset(),
                      child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Center(
              child: SizedBox(
                height: 36,
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text(
                    'Start Focus Session',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF2A4E35),
                    foregroundColor: isDark ? const Color(0xFF101C14) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final timerController = ref.read(focusTimerProvider.notifier);
                    timerController.start();
                    timerController.openZenMode();
                    context.go('/focus');
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Card 2: Quick Daily Habits Overview ---
  Widget _buildQuickDailyHabitsCard({
    required BuildContext context,
    required bool isDark,
    required List<Habit> todayHabits,
  }) {
    final theme = Theme.of(context);
    final completedCount = todayHabits.where((h) => h.isCompletedToday).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E231F) : const Color(0xFFF4F1EA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2DDD3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF382A4C)
                            : const Color(0xFFE8DEF8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.repeat_rounded,
                        size: 18,
                        color: isDark
                            ? const Color(0xFFE8DEF8)
                            : const Color(0xFF382A4C),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Daily Habits',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF283B2F) : const Color(0xFFD2E8D4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$completedCount/${todayHabits.length} Done',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/more/habits'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Habits List (Top 2 items)
          if (todayHabits.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No daily rituals configured yet.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Habit', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => HabitFormSheet.show(context),
                  ),
                ],
              ),
            )
          else
            Column(
              children: todayHabits.take(2).map((habit) {
                final isDone = habit.isCompletedToday;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252C27) : const Color(0xFFFAF8F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2DDD3),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        AreteCheckCircle(
                          isChecked: isDone,
                          onTap: () {
                            final willComplete = !habit.isCompletedToday;
                            ref.read(habitsProvider.notifier).toggleHabitCompletion(habit.id);
                            if (willComplete) {
                              _confettiController.trigger();
                            }
                          },
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            habit.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (habit.currentStreak > 0)
                          Text(
                            '🔥 ${habit.currentStreak}d',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        else
                          Text(
                            'Ready',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          // Footer row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                todayHabits.length > 2
                    ? '+${todayHabits.length - 2} more habits • Tap View All'
                    : 'Tap circle to complete ritual',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              InkWell(
                onTap: () => HabitFormSheet.show(context),
                child: Text(
                  '+ Add Habit',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Card 3: Focus Streak & Quick Stats ---
  Widget _buildFocusStreakStatsCard({
    required BuildContext context,
    required bool isDark,
    required ConsistencyMatrixSummary? consistencySummary,
    required TaskVelocityStats velocityStats,
  }) {
    final theme = Theme.of(context);
    final currentStreak = consistencySummary?.currentStreak ?? 0;
    final weeklyHours = consistencySummary?.weeklyFocusHours ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E231F) : const Color(0xFFF4F1EA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2DDD3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF5A2D00)
                            : const Color(0xFFFFDDB3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        size: 18,
                        color: Color(0xFFFF7A59),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Focus Streak & Stats',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF252C27)
                      : const Color(0xFFE6E0D5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '🔥 Active Pace',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF7A59),
                  ),
                ),
              ),
            ],
          ),

          // Stat Badges Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF283B2F) : const Color(0xFFD2E8D4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF86D99B).withValues(alpha: 0.3) : const Color(0xFF2A4E35).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔥 $currentStreak Days',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Current Streak',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF33271E) : const Color(0xFFFDE8E1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFF7A59).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚡ ${weeklyHours}h Focused',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF7A59),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Past 7 Days',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFFFB77D) : const Color(0xFF5A2D00),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Mini Velocity Bar & Motto
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 14, color: isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35)),
              const SizedBox(width: 6),
              Text(
                '${(velocityStats.completionRate * 100).toInt()}% Task Velocity',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35),
                ),
              ),
              Flexible(
                child: Text(
                  ' • ${velocityStats.completedToday}/${velocityStats.totalToday} Tasks Cleared Today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. Primary Middle Section: Today's Synced Action Items Section ---
  Widget _buildTodayActionItemsSection({
    required BuildContext context,
    required bool isDark,
    required List<Task> todayTasks,
    required TaskVelocityStats velocityStats,
  }) {
    final theme = Theme.of(context);
    final completedCount = todayTasks.where((t) => t.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Today’s Action Items',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF283B2F)
                          : const Color(0xFFD2E8D4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedCount/${todayTasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFD2E8D4) : const Color(0xFF1B3623),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Add Task',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => TaskFormSheet.show(context, initialDailyTarget: true),
            ),
          ],
        ),

        // Clean Subtask & Velocity Progress Bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: velocityStats.totalToday > 0 ? velocityStats.completionRate : 0.0,
                  minHeight: 5,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2DDD3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${(velocityStats.completionRate * 100).toInt()}% Velocity • ${velocityStats.velocityLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF86D99B) : const Color(0xFF2A4E35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${velocityStats.completedToday}/${velocityStats.totalToday} Cleared',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        if (todayTasks.isEmpty)
          AreteEmptyState(
            icon: Icons.spa_outlined,
            title: 'A Clean Slate',
            description: 'No pending tasks for today. Take a mindful breath or add what matters.',
            actionLabel: 'Add Daily Task',
            onAction: () => TaskFormSheet.show(context, initialDailyTarget: true),
          )
        else
          ...todayTasks.map((task) {
            final isExpanded = _expandedTaskIds.contains(task.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.8),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedTaskIds.remove(task.id);
                          } else {
                            _expandedTaskIds.add(task.id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Task Checkbox with Confetti on complete (Live dual-way sync!)
                            AreteCheckCircle(
                              isChecked: task.isCompleted,
                              onTap: () {
                                final willComplete = !task.isCompleted;
                                ref.read(tasksProvider.notifier).toggleTask(task.id);
                                if (willComplete) {
                                  _confettiController.trigger();
                                }
                              },
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      fontWeight: FontWeight.w600,
                                      decoration:
                                          task.isCompleted ? TextDecoration.lineThrough : null,
                                      color: task.isCompleted
                                          ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                                          : theme.colorScheme.onSurface,
                                    ),
                                    child: Text(
                                      task.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      // Category chip
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: task.goalColor != null
                                                ? Color(int.tryParse('0xFF${task.goalColor!.replaceAll("#", "")}') ?? 0xFF2A4E35).withValues(alpha: 0.15)
                                                : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            task.goalTitle ?? 'Action',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: task.goalColor != null
                                                ? Color(int.tryParse('0xFF${task.goalColor!.replaceAll("#", "")}') ?? 0xFF2A4E35)
                                                : theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (task.dueDate != null) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.calendar_today, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                        const SizedBox(width: 4),
                                        Text(
                                          task.dueDate!,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 20,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expanded Details Drawer
                    if (isExpanded)
                      Container(
                        padding: const EdgeInsets.only(left: 48, right: 14, bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (task.description != null && task.description!.isNotEmpty) ...[
                              Text(
                                task.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.timer_outlined, size: 14),
                                  label: const Text('Focus'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    ref.read(focusTimerProvider.notifier).linkTask(
                                          taskId: task.id,
                                          goalId: task.goalId,
                                        );
                                    ref.read(focusTimerProvider.notifier).start();
                                    context.go('/focus');
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.edit_outlined, size: 14),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => TaskFormSheet.show(context, task: task),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => ref.read(tasksProvider.notifier).deleteTask(task.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // --- 5. Daily Inquiry Reflection Card ---
  Widget _buildDailyInquiryCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Daily Inquiry',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('• What matters to me?', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('• What should I do today?', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('• Am I becoming more consistent?', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildScreenTimeLiveBanner(BuildContext context, ScreenTimeStatus status) {
    final theme = Theme.of(context);
    final isDistraction = status.category == AppCategory.distraction;
    final isProductive = status.category == AppCategory.productive;

    final bannerBg = isDistraction
        ? const Color(0xFFFFDDB3).withValues(alpha: 0.6)
        : (isProductive
            ? AppColors.sagePrimaryContainer.withValues(alpha: 0.7)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));
    final borderColor = isDistraction
        ? const Color(0xFFFF7A59).withValues(alpha: 0.5)
        : (isProductive ? AppColors.sageOnPrimaryContainer.withValues(alpha: 0.3) : Colors.transparent);
    final iconColor = isDistraction
        ? const Color(0xFFC04E00)
        : (isProductive ? AppColors.sageOnPrimaryContainer : theme.colorScheme.primary);

    return InkWell(
      onTap: () => NotificationPreferenceSheet.show(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(
              isDistraction
                  ? Icons.warning_amber_rounded
                  : (isProductive ? Icons.track_changes_rounded : Icons.screen_lock_portrait_rounded),
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Screen Time: ${status.formattedTotalScreenTime}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      if (status.currentAppName.isNotEmpty) ...[
                        const Text(' • ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Flexible(
                          child: Text(
                            'Active: ${status.currentAppName} (${status.formattedCurrentAppTime})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isDistraction ? FontWeight.w800 : FontWeight.w600,
                              color: isDistraction ? const Color(0xFFC04E00) : theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    isDistraction
                        ? 'Distraction app active • Tap to configure limit alerts'
                        : (isProductive
                            ? 'Deep focus momentum • Productive tool active'
                            : 'Live digital wellness tracker active'),
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}


/// Canvas painter for a single, continuous Material 3 circular progress ring
/// with thick stroke (12px–16px) and rounded cap ends.
class _CircularFocusRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _CircularFocusRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 1. Draw smooth pastel background track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw continuous active progress arc with rounded cap ends
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (progress >= 1.0) {
        canvas.drawCircle(center, radius, progressPaint);
      } else {
        // Start from 12 o'clock (-pi / 2) and sweep clockwise
        final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          sweepAngle,
          false,
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CircularFocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

