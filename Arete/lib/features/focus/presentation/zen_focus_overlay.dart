import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/arete_progress_bar.dart';
import '../../tasks/data/task_repository.dart';
import 'ambient_soundscape_controller.dart';
import 'focus_timer_controller.dart';
import '../data/pip_service.dart';
import '../domain/focus_session_model.dart';

class ZenFocusOverlay extends ConsumerStatefulWidget {
  const ZenFocusOverlay({super.key});

  @override
  ConsumerState<ZenFocusOverlay> createState() => _ZenFocusOverlayState();
}

class _ZenFocusOverlayState extends ConsumerState<ZenFocusOverlay> {
  bool _showSoundscapeSheet = false;

  ({Color bg, Color surface, Color onSurface, Color primary, Color accent}) _getPhaseColors(
    FocusSessionType type,
    bool isDark,
  ) {
    switch (type) {
      case FocusSessionType.focus:
        return (
          bg: isDark ? const Color(0xFF101C14) : const Color(0xFF1A3824),
          surface: isDark ? const Color(0xFF162B1D) : const Color(0xFF234B31),
          onSurface: const Color(0xFFF1F8F3),
          primary: const Color(0xFFD2E8D4),
          accent: const Color(0xFFFF7A59),
        );
      case FocusSessionType.shortBreak:
        return (
          bg: isDark ? const Color(0xFF132219) : const Color(0xFFE2F1E4),
          surface: isDark ? const Color(0xFF1D3527) : const Color(0xFFD0E8D4),
          onSurface: isDark ? const Color(0xFFF0FAF2) : const Color(0xFF0F2B18),
          primary: isDark ? const Color(0xFF9CD4A6) : const Color(0xFF1B4E2B),
          accent: const Color(0xFFFF7A59),
        );
      case FocusSessionType.longBreak:
        return (
          bg: isDark ? const Color(0xFF281C14) : const Color(0xFFFDF0E2),
          surface: isDark ? const Color(0xFF38271C) : const Color(0xFFFFE0C2),
          onSurface: isDark ? const Color(0xFFFFF1EB) : const Color(0xFF4A2508),
          primary: isDark ? const Color(0xFFFFB77D) : const Color(0xFF8A4305),
          accent: const Color(0xFFFF7A59),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(focusTimerProvider);
    final timerController = ref.read(focusTimerProvider.notifier);
    final liveSeconds = ref.watch(liveTodayFocusSecondsProvider);
    final settings = ref.watch(appSettingsProvider);
    final soundState = ref.watch(ambientSoundscapeProvider);
    final soundController = ref.read(ambientSoundscapeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isRunning = timerState.state == TimerState.running;
    final isPaused = timerState.state == TimerState.paused;

    final phaseColors = _getPhaseColors(timerState.sessionType, isDark);

    // Linked task title if available
    String? linkedTaskTitle;
    if (timerState.linkedTaskId != null) {
      final tasks = ref.watch(todayTasksProvider);
      final task = tasks.where((t) => t.id == timerState.linkedTaskId).firstOrNull;
      linkedTaskTitle = task?.title;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      color: phaseColors.bg,
      child: SafeArea(
        child: Stack(
          children: [
            // Ambient particle/glow backdrop
            Positioned(
              top: -80,
              left: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: phaseColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: phaseColors.accent.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Main Content Layout
            Column(
              children: [
                // Top App Bar: Minimize button + Title + Soundscapes quick button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Exit Zen Mode',
                        style: IconButton.styleFrom(
                          backgroundColor: phaseColors.surface.withValues(alpha: 0.8),
                          foregroundColor: phaseColors.onSurface,
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                        onPressed: () => timerController.closeZenMode(),
                      ),
                      Column(
                        children: [
                          Text(
                            'ZEN FOCUS MODE',
                            style: TextStyle(
                              letterSpacing: 2.0,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: phaseColors.primary.withValues(alpha: 0.9),
                            ),
                          ),
                          if (linkedTaskTitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              linkedTaskTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: phaseColors.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Float Focus Clock (PiP)',
                            style: IconButton.styleFrom(
                              backgroundColor: phaseColors.surface.withValues(alpha: 0.8),
                              foregroundColor: phaseColors.onSurface,
                            ),
                            icon: const Icon(Icons.picture_in_picture_alt_rounded, size: 20),
                            onPressed: () => ref.read(pipServiceProvider).enterPip(),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Soundscapes',
                            style: IconButton.styleFrom(
                              backgroundColor: soundState.isPlaying
                                  ? phaseColors.accent.withValues(alpha: 0.25)
                                  : phaseColors.surface.withValues(alpha: 0.8),
                              foregroundColor: soundState.isPlaying
                                  ? phaseColors.accent
                                  : phaseColors.onSurface,
                            ),
                            icon: Icon(
                              soundState.isPlaying ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _showSoundscapeSheet = !_showSoundscapeSheet;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Pomodoro 4-Cycle Progression Dots
                _buildPomodoroCycleDots(timerState, phaseColors),

                const SizedBox(height: 24),

                // Central Large 16px Radial Countdown Ring
                Center(
                  child: AreteProgressRing(
                    progress: timerState.remainingRatio,
                    size: 280,
                    strokeWidth: 16,
                    color: phaseColors.primary,
                    backgroundColor: phaseColors.surface.withValues(alpha: 0.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Formatters.formatSeconds(timerState.remainingSeconds),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1.0,
                            color: phaseColors.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: phaseColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            timerState.sessionType.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                              color: phaseColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Today: ${Formatters.formatDurationHuman(liveSeconds)} / ${settings.dailyFocusGoalMinutes < 60 ? '${settings.dailyFocusGoalMinutes}m' : (settings.dailyFocusGoalMinutes % 60 == 0 ? '${settings.dailyFocusGoalMinutes ~/ 60}h' : '${(settings.dailyFocusGoalMinutes / 60).toStringAsFixed(1)}h')}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: phaseColors.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Step +/- 5m Quick Adjustments (only when paused/idle)
                if (!isRunning)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.remove, size: 14),
                        label: const Text('-5m'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: phaseColors.onSurface,
                          side: BorderSide(color: phaseColors.primary.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => timerController.adjustMinutes(-5),
                      ),
                      const SizedBox(width: 14),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('+5m'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: phaseColors.onSurface,
                          side: BorderSide(color: phaseColors.primary.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => timerController.adjustMinutes(5),
                      ),
                    ],
                  ),

                const Spacer(),

                // Play / Pause / Skip / Reset Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isRunning) ...[
                        _buildZenControlPill(
                          label: 'Pause',
                          icon: Icons.pause_rounded,
                          bgColor: phaseColors.surface,
                          fgColor: phaseColors.onSurface,
                          onTap: timerController.pause,
                        ),
                        const SizedBox(width: 14),
                        _buildZenControlPill(
                          label: 'Skip',
                          icon: Icons.skip_next_rounded,
                          bgColor: phaseColors.surface.withValues(alpha: 0.6),
                          fgColor: phaseColors.onSurface.withValues(alpha: 0.8),
                          onTap: timerController.skip,
                        ),
                      ] else if (isPaused) ...[
                        _buildZenControlPill(
                          label: 'Resume',
                          icon: Icons.play_arrow_rounded,
                          bgColor: phaseColors.primary,
                          fgColor: phaseColors.bg,
                          isPrimary: true,
                          onTap: timerController.resume,
                        ),
                        const SizedBox(width: 14),
                        _buildZenControlPill(
                          label: 'Reset',
                          icon: Icons.refresh_rounded,
                          bgColor: phaseColors.surface,
                          fgColor: phaseColors.onSurface,
                          onTap: timerController.reset,
                        ),
                      ] else ...[
                        _buildZenControlPill(
                          label: timerState.sessionType == FocusSessionType.focus
                              ? 'Start Focus'
                              : 'Start Break',
                          icon: Icons.play_arrow_rounded,
                          bgColor: phaseColors.primary,
                          fgColor: phaseColors.bg,
                          isPrimary: true,
                          onTap: timerController.start,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),

            // Floating Ambient Soundscapes Drawer
            if (_showSoundscapeSheet)
              Positioned(
                left: 16,
                right: 16,
                top: 76,
                child: _buildZenSoundscapesPanel(soundState, soundController, phaseColors),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPomodoroCycleDots(
    FocusTimerState timerState,
    ({Color bg, Color surface, Color onSurface, Color primary, Color accent}) phaseColors,
  ) {
    final completed = timerState.completedCycles; // 0 to 4

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: phaseColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cycle $completed/4',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: phaseColors.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (index) {
              final isDone = index < completed;
              final isCurrent = index == completed && timerState.sessionType == FocusSessionType.focus;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCurrent ? 14 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isDone
                      ? phaseColors.primary
                      : isCurrent
                          ? phaseColors.accent
                          : phaseColors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildZenControlPill({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color fgColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fgColor, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZenSoundscapesPanel(
    AmbientSoundscapeState soundState,
    AmbientSoundscapeController soundController,
    ({Color bg, Color surface, Color onSurface, Color primary, Color accent}) phaseColors,
  ) {
    const sounds = [
      {'type': 'rain', 'label': 'Rain', 'icon': '🌧️'},
      {'type': 'forest', 'label': 'Forest', 'icon': '🌲'},
      {'type': 'white_noise', 'label': 'Noise', 'icon': '🎧'},
      {'type': 'cafe', 'label': 'Café', 'icon': '☕'},
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: phaseColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: phaseColors.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.headphones_rounded, size: 18, color: phaseColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Ambient Soundscapes',
                        style: TextStyle(
                          color: phaseColors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: phaseColors.onSurface),
                    onPressed: () => setState(() => _showSoundscapeSheet = false),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: sounds.map((s) {
                  final isSelected = soundState.activeSound == s['type'];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => soundController.selectSoundscape(s['type'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? phaseColors.primary.withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? phaseColors.primary : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(s['icon'] as String, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(
                            s['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? phaseColors.primary
                                  : phaseColors.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => soundController.togglePlay(),
                    icon: Icon(
                      soundState.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: soundState.isPlaying ? phaseColors.accent : phaseColors.primary,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: phaseColors.surface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: soundState.volume,
                      min: 0.0,
                      max: 1.0,
                      activeColor: phaseColors.primary,
                      inactiveColor: phaseColors.onSurface.withValues(alpha: 0.2),
                      onChanged: (val) => soundController.setVolume(val),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
