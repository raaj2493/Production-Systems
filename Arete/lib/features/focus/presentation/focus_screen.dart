import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_progress_bar.dart';
import '../../goals/data/goal_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../today/presentation/widgets/daily_focus_goal_sheet.dart';
import '../data/focus_repository.dart';
import '../data/pip_service.dart';
import '../domain/focus_session_model.dart';
import 'focus_shield_controller.dart';
import 'focus_timer_controller.dart';
import 'ambient_soundscape_controller.dart';

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final timerState = ref.watch(focusTimerProvider);
    final timerController = ref.read(focusTimerProvider.notifier);
    final recentSessionsAsync = ref.watch(recentFocusSessionsProvider);
    final liveFocusSeconds = ref.watch(liveTodayFocusSecondsProvider);
    final tasks = ref.watch(todayTasksProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final goals = goalsAsync.valueOrNull ?? const [];

    final isRunning = timerState.state == TimerState.running;
    final isPaused = timerState.state == TimerState.paused;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_rounded),
            tooltip: 'Float Focus Clock (PiP)',
            onPressed: () {
              ref.read(pipServiceProvider).enterPip();
            },
          ),
          IconButton(
            icon: const Icon(Icons.track_changes_rounded),
            tooltip: 'Set Daily Focus Goal',
            onPressed: () {
              DailyFocusGoalSheet.show(
                context,
                currentGoalMinutes: settings.dailyFocusGoalMinutes,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. Pomodoro Cycle Progression Indicator
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CYCLE ${(timerState.completedCycles % 4) + 1} OF 4',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ...List.generate(4, (index) {
                    final isFilled = index < timerState.completedCycles;
                    final isCurrent = index == (timerState.completedCycles % 4);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: isCurrent ? 10 : 8,
                        height: isCurrent ? 10 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? theme.colorScheme.primary
                              : (isCurrent
                                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 2. Session Mode Selector (Focus / Short Break / Long Break)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTypeChip(
                context,
                title: 'Focus',
                type: FocusSessionType.focus,
                currentType: timerState.sessionType,
                onTap: isRunning
                    ? null
                    : () => timerController.selectSessionType(FocusSessionType.focus),
              ),
              const SizedBox(width: 8),
              _buildTypeChip(
                context,
                title: 'Short Break',
                type: FocusSessionType.shortBreak,
                currentType: timerState.sessionType,
                onTap: isRunning
                    ? null
                    : () => timerController.selectSessionType(FocusSessionType.shortBreak),
              ),
              const SizedBox(width: 8),
              _buildTypeChip(
                context,
                title: 'Long Break',
                type: FocusSessionType.longBreak,
                currentType: timerState.sessionType,
                onTap: isRunning
                    ? null
                    : () => timerController.selectSessionType(FocusSessionType.longBreak),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Quick Duration Presets & Custom Duration Button
          if (!isRunning)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPresetChip(
                    context,
                    minutes: 15,
                    currentMinutes: (timerState.totalSeconds / 60).round(),
                    onTap: () => timerController.setCustomMinutes(15),
                  ),
                  const SizedBox(width: 6),
                  _buildPresetChip(
                    context,
                    minutes: 25,
                    currentMinutes: (timerState.totalSeconds / 60).round(),
                    onTap: () => timerController.setCustomMinutes(25),
                  ),
                  const SizedBox(width: 6),
                  _buildPresetChip(
                    context,
                    minutes: 45,
                    currentMinutes: (timerState.totalSeconds / 60).round(),
                    onTap: () => timerController.setCustomMinutes(45),
                  ),
                  const SizedBox(width: 6),
                  _buildPresetChip(
                    context,
                    minutes: 60,
                    currentMinutes: (timerState.totalSeconds / 60).round(),
                    onTap: () => timerController.setCustomMinutes(60),
                  ),
                  const SizedBox(width: 6),
                  _buildCustomChip(
                    context,
                    currentMinutes: (timerState.totalSeconds / 60).round(),
                    onTap: () => _showCustomDurationDialog(context, ref),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // 4. Central Radial Countdown Ring Widget
          Center(
            child: Tooltip(
              message: isRunning ? 'Tap to expand Zen Mode' : 'Tap to change duration',
              child: InkWell(
                borderRadius: BorderRadius.circular(140),
                onTap: isRunning
                    ? timerController.openZenMode
                    : () => _showCustomDurationDialog(context, ref),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _FocusRingBreathingAura(
                    isRunning: isRunning,
                    child: AreteProgressRing(
                      progress: timerState.remainingRatio, // Depletes clockwise as time counts down
                      size: 260,
                      strokeWidth: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Formatters.formatSeconds(timerState.remainingSeconds),
                          style: AppTypography.timerLarge.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontSize: 52,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            timerState.sessionType.displayName.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!isRunning) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to customize',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fullscreen_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tap for Zen Mode',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 5. Step Adjustment Buttons (-5m / +5m)
        if (!isRunning) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove, size: 14),
                  label: const Text('-5m'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => timerController.adjustMinutes(-5),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('+5m'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => timerController.adjustMinutes(5),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // 6. Primary Timer Controls (Start / Pause / Resume / Reset / Skip)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRunning) ...[
                AreteButton(
                  label: 'Pause',
                  icon: Icons.pause,
                  variant: AreteButtonVariant.secondary,
                  onPressed: () async {
                    final shield = ref.read(focusShieldProvider);
                    if (shield.isShieldEnabled && shield.strictMode) {
                      final confirmed = await _confirmStrictExit(context);
                      if (!confirmed) return;
                    }
                    timerController.pause();
                  },
                ),
                const SizedBox(width: 12),
                AreteButton(
                  label: 'Skip',
                  icon: Icons.skip_next,
                  variant: AreteButtonVariant.ghost,
                  onPressed: () async {
                    final shield = ref.read(focusShieldProvider);
                    if (shield.isShieldEnabled && shield.strictMode) {
                      final confirmed = await _confirmStrictExit(context);
                      if (!confirmed) return;
                    }
                    timerController.skip();
                  },
                ),
              ] else if (isPaused) ...[
                AreteButton(
                  label: 'Resume',
                  icon: Icons.play_arrow,
                  variant: AreteButtonVariant.primary,
                  onPressed: timerController.resume,
                ),
                const SizedBox(width: 12),
                AreteButton(
                  label: 'Reset',
                  icon: Icons.refresh,
                  variant: AreteButtonVariant.secondary,
                  onPressed: () async {
                    final shield = ref.read(focusShieldProvider);
                    if (shield.isShieldEnabled && shield.strictMode) {
                      final confirmed = await _confirmStrictExit(context);
                      if (!confirmed) return;
                    }
                    timerController.reset();
                  },
                ),
              ] else ...[
                AreteButton(
                  label: 'Start Session',
                  icon: Icons.play_arrow,
                  variant: AreteButtonVariant.primary,
                  onPressed: () => _handleStartSession(context, ref),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // 7. Full-Screen Zen Mode Pill Button
          Center(
            child: TextButton.icon(
              onPressed: timerController.openZenMode,
              icon: const Icon(Icons.fullscreen_rounded, size: 20),
              label: const Text('Expand Zen Mode'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 6. Linked Task / Goal Selector
          Builder(
            builder: (context) {
              final uniqueTasks = {for (final t in tasks) t.id: t}.values.toList();

              String? dropdownValue;
              if (timerState.linkedTaskId != null &&
                  uniqueTasks.any((t) => t.id == timerState.linkedTaskId)) {
                dropdownValue = 'task:${timerState.linkedTaskId}';
              } else if (timerState.linkedGoalId != null &&
                  goals.any((g) => g.id == timerState.linkedGoalId)) {
                dropdownValue = 'goal:${timerState.linkedGoalId}';
              }

              return AreteCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      timerState.linkedGoalId != null
                          ? Icons.track_changes_rounded
                          : (timerState.linkedTaskId != null
                              ? Icons.check_circle_outline
                              : Icons.link),
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Focus Goal / Subject (Optional)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isDense: true,
                              isExpanded: true,
                              value: dropdownValue,
                              borderRadius: BorderRadius.circular(16),
                              dropdownColor: theme.brightness == Brightness.dark
                                  ? const Color(0xFF252B27)
                                  : const Color(0xFFFAF7F2),
                              elevation: 6,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              hint: const Text('Set focus goal or link a task...'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('General Focus (Unlinked)'),
                                ),
                                ...goals.map(
                                  (g) => DropdownMenuItem<String?>(
                                    value: 'goal:${g.id}',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.track_changes_rounded,
                                          size: 15,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Goal: ${g.title}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                ...uniqueTasks.map(
                                  (t) => DropdownMenuItem<String?>(
                                    value: 'task:${t.id}',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, size: 15),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Task: ${t.title}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: isRunning
                                  ? null
                                  : (val) {
                                      if (val == null) {
                                        timerController.linkTask(taskId: null, goalId: null);
                                      } else if (val.startsWith('goal:')) {
                                        timerController.linkTask(
                                          taskId: null,
                                          goalId: val.substring(5),
                                        );
                                      } else if (val.startsWith('task:')) {
                                        final tId = val.substring(5);
                                        final selectedTask =
                                            uniqueTasks.where((t) => t.id == tId).firstOrNull;
                                        timerController.linkTask(
                                          taskId: tId,
                                          goalId: selectedTask?.goalId,
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // 7. Focus Shield (App Blocker) Card
          Builder(
            builder: (context) {
              final shieldState = ref.watch(focusShieldProvider);
              final shieldController = ref.read(focusShieldProvider.notifier);

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
                              Icon(
                                Icons.shield_outlined,
                                size: 22,
                                color: shieldState.isShieldEnabled
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Focus Shield',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      shieldState.isShieldEnabled
                                          ? (shieldState.isAccessibilityGranted
                                              ? '${shieldState.selectedCount} apps protected'
                                              : 'Accessibility setup needed')
                                          : 'App distraction blocker is off',
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
                        Switch.adaptive(
                          value: shieldState.isShieldEnabled,
                          activeColor: theme.colorScheme.primary,
                          onChanged: isRunning && shieldState.strictMode
                              ? null // Locked in Strict Mode during session
                              : (val) => shieldController.toggleShieldEnabled(val),
                        ),
                      ],
                    ),

                    if (shieldState.isShieldEnabled) ...[
                      const SizedBox(height: 12),
                      Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 10),

                      // App Configuration Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              shieldState.selectedCount == 0
                                  ? 'No apps selected yet'
                                  : '${shieldState.selectedCount} distracting apps blocked',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.tune, size: 16),
                            label: const Text('Manage Apps'),
                            onPressed: isRunning && shieldState.strictMode
                                ? null
                                : () => context.push('/focus/apps'),
                          ),
                        ],
                      ),

                      // Permission Warning Banner if missing
                      if (!shieldState.isAccessibilityGranted) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Accessibility permission required for blocking.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => shieldController.openAccessibilitySettings(),
                                child: const Text('Enable'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Strict Mode Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock_clock_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Strict Mode',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: shieldState.strictMode,
                            activeColor: theme.colorScheme.primary,
                            onChanged: isRunning
                                ? null
                                : (val) => shieldController.toggleStrictMode(val),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // 8. Procedural Ambient Focus Soundscapes
          _buildAmbientSoundscapesCard(context, ref),

          const SizedBox(height: 28),

          // 9. Today's Focus Overview with Daily Focus Goal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today’s Focus', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        DailyFocusGoalSheet.show(
                          context,
                          currentGoalMinutes: settings.dailyFocusGoalMinutes,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.track_changes_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Daily Goal: ${settings.dailyFocusGoalMinutes < 60 ? '${settings.dailyFocusGoalMinutes} min' : (settings.dailyFocusGoalMinutes % 60 == 0 ? '${settings.dailyFocusGoalMinutes ~/ 60} ${settings.dailyFocusGoalMinutes == 60 ? 'hr' : 'hrs'}' : '${(settings.dailyFocusGoalMinutes / 60).toStringAsFixed(1)} hrs')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.edit_outlined,
                              size: 11,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.formatDurationHuman(liveFocusSeconds),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 8. Recent Session Log
          recentSessionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading history: $e'),
            data: (sessions) {
              if (sessions.isEmpty) {
                return AreteCard(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No focus blocks logged yet today. Complete a session to start your record.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: sessions.take(5).map((session) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: AreteCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            session.sessionType == FocusSessionType.focus
                                ? Icons.timer
                                : Icons.coffee,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.taskTitle ??
                                      session.goalTitle ??
                                      session.sessionType.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppDateUtils.formatDateTime(session.startedAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    Formatters.formatDurationHuman(session.completedSeconds),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!session.isCompleted) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Partial',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (session.shieldEnabled) ...[
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield, size: 12, color: theme.colorScheme.primary),
                                    const SizedBox(width: 3),
                                    Text(
                                      session.interruptionsCount > 0
                                          ? '${session.interruptionsCount} blocked'
                                          : 'Shielded',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 10,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTypeChip(
    BuildContext context, {
    required String title,
    required FocusSessionType type,
    required FocusSessionType currentType,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isSelected = type == currentType;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    BuildContext context, {
    required int minutes,
    required int currentMinutes,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isSelected = minutes == currentMinutes;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${minutes}m',
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomChip(
    BuildContext context, {
    required int currentMinutes,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isPreset = [15, 25, 45, 60].contains(currentMinutes);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: !isPreset
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 14,
              color: !isPreset ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              !isPreset ? 'Custom (${currentMinutes}m)' : 'Custom...',
              style: theme.textTheme.labelMedium?.copyWith(
                color: !isPreset ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                fontWeight: !isPreset ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientSoundscapesCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final soundState = ref.watch(ambientSoundscapeProvider);
    final soundController = ref.read(ambientSoundscapeProvider.notifier);

    const soundOptions = [
      {'type': 'rain', 'label': 'Rain', 'icon': '🌧️'},
      {'type': 'forest', 'label': 'Forest', 'icon': '🌲'},
      {'type': 'white_noise', 'label': 'White Noise', 'icon': '🎧'},
      {'type': 'cafe', 'label': 'Café', 'icon': '☕'},
    ];

    return AreteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: soundState.isPlaying
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      soundState.isPlaying ? Icons.graphic_eq : Icons.headphones_outlined,
                      size: 20,
                      color: soundState.isPlaying
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Soundscapes',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        soundState.isPlaying ? 'Active background audio' : 'Synthetic procedural ambient audio',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton.filledTonal(
                onPressed: () => soundController.togglePlay(),
                icon: Icon(
                  soundState.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: soundState.isPlaying ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: soundState.isPlaying
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                      : theme.colorScheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: soundOptions.map((opt) {
              final isSelected = soundState.activeSound == opt['type'];
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => soundController.selectSoundscape(opt['type'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(opt['icon'] as String, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        opt['label'] as String,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (soundState.isPlaying) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.volume_down_rounded, size: 18, color: theme.colorScheme.outline),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: soundState.volume,
                      min: 0.0,
                      max: 1.0,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) => soundController.setVolume(val),
                    ),
                  ),
                ),
                Icon(Icons.volume_up_rounded, size: 18, color: theme.colorScheme.outline),
              ],
            ),
          ],
        ],
      ),
    );
  }


  void _showCustomDurationDialog(BuildContext context, WidgetRef ref) {
    final timerController = ref.read(focusTimerProvider.notifier);
    final currentTotalSec = ref.read(focusTimerProvider).totalSeconds;
    int selectedMinutes = (currentTotalSec / 60).round();
    final textController = TextEditingController(text: selectedMinutes.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('Set Focus Duration'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // Counter with - / + buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove),
                          onPressed: selectedMinutes > 1
                              ? () {
                                  setState(() {
                                    selectedMinutes = (selectedMinutes - 5).clamp(1, 240);
                                    textController.text = selectedMinutes.toString();
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: textController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              suffixText: 'm',
                              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed >= 1 && parsed <= 240) {
                                setState(() {
                                  selectedMinutes = parsed;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          onPressed: selectedMinutes < 240
                              ? () {
                                  setState(() {
                                    selectedMinutes = (selectedMinutes + 5).clamp(1, 240);
                                    textController.text = selectedMinutes.toString();
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Quick Presets',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [10, 15, 20, 25, 30, 45, 50, 60, 90, 120].map((mins) {
                        final isSelected = selectedMinutes == mins;
                        return ChoiceChip(
                          label: Text('${mins}m'),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                selectedMinutes = mins;
                                textController.text = mins.toString();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = int.tryParse(textController.text) ?? selectedMinutes;
                    timerController.setCustomMinutes(parsed.clamp(1, 240));
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Set Timer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleStartSession(BuildContext context, WidgetRef ref) async {
    final shieldState = ref.read(focusShieldProvider);
    final shieldController = ref.read(focusShieldProvider.notifier);
    final timerController = ref.read(focusTimerProvider.notifier);
    final timerState = ref.read(focusTimerProvider);

    // If Focus Shield is enabled with apps selected, and we are in focus session, verify accessibility permission
    if (shieldState.isShieldEnabled &&
        shieldState.selectedPackages.isNotEmpty &&
        timerState.sessionType == FocusSessionType.focus &&
        !shieldState.isAccessibilityGranted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                const Text('Enable Focus Shield'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To block distracting apps during your focus session, Areté requires Android Accessibility access.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '• Areté never reads screen content, keystrokes, personal messages, or passwords.\n• All checks happen strictly on your device.\n• App blocking automatically ends when your session finishes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Start Without Shield'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  shieldController.openAccessibilitySettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );

      if (proceed == true) {
        timerController.start();
      }
      return;
    }

    timerController.start();
  }

  Future<bool> _confirmStrictExit(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Strict Mode Active'),
        content: const Text(
          'You committed to a deep focus session in Strict Mode. Are you sure you want to end or pause it early?',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay Focused'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit Early'),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

class _FocusRingBreathingAura extends StatefulWidget {
  final bool isRunning;
  final Widget child;

  const _FocusRingBreathingAura({
    required this.isRunning,
    required this.child,
  });

  @override
  State<_FocusRingBreathingAura> createState() => _FocusRingBreathingAuraState();
}

class _FocusRingBreathingAuraState extends State<_FocusRingBreathingAura>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _opacityAnimation = Tween<double>(begin: 0.12, end: 0.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.isRunning) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _FocusRingBreathingAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRunning && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.isRunning) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(
                  alpha: _opacityAnimation.value,
                ),
                blurRadius: 28 * _scaleAnimation.value,
                spreadRadius: 4 * (_scaleAnimation.value - 1.0) * 10,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
