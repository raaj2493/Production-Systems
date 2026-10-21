import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/focus_session_model.dart';
import '../../data/pip_service.dart';
import '../focus_timer_controller.dart';

/// Ultra-Minimal Floating Pill Capsule (Dynamic Island Style) - Option B.
///
/// Lifecycle:
/// - Never appears while actively navigating inside Areté.
/// - Triggers only when a focus/Pomodoro session is running and the user minimizes Areté.
/// - Automatically vanishes when the timer finishes, pauses, or resets.
///
/// Design:
/// - Single-line slim capsule (~38dp height, rounded 9999.dp).
/// - Translucent pastel Material You container (`#D2E8D4` for focus, `#FFDDB3` for break).
/// - Left: Animated micro pulse dot (Green for Focus, Amber for Break).
/// - Center: Clean bold countdown digits ("04:28").
/// - Right: Micro play/pause icon.
/// - Single Tap anywhere on the pill capsule instantly re-opens Areté into full-screen Zen Focus View.
class PipFocusView extends ConsumerStatefulWidget {
  const PipFocusView({super.key});

  @override
  ConsumerState<PipFocusView> createState() => _PipFocusViewState();
}

class _PipFocusViewState extends ConsumerState<PipFocusView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _restoreToFullScreen(BuildContext context) {
    ref.read(pipServiceProvider).exitPip();
    ref.read(focusTimerProvider.notifier).openZenMode();
    context.go('/focus');
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(focusTimerProvider);
    final timerNotifier = ref.read(focusTimerProvider.notifier);
    final isRunning = timerState.state == TimerState.running;
    final isBreak = timerState.sessionType != FocusSessionType.focus;

    // Material 3 tonal container colors (Sage & Coral / Amber)
    final capsuleBg = isBreak
        ? const Color(0xFFFFDDB3).withValues(alpha: 0.92)
        : const Color(0xFFD2E8D4).withValues(alpha: 0.92);
    final textColor = isBreak ? const Color(0xFF2A1800) : const Color(0xFF0F291E);
    final borderColor = isBreak ? const Color(0xFFF0CAA0) : const Color(0xFFB8D6BC);
    final pulseColor = isBreak ? const Color(0xFFFF6F00) : const Color(0xFF1B5E20);

    final timeString = Formatters.formatSeconds(timerState.remainingSeconds);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF6),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _restoreToFullScreen(context),
          child: Center(
            child: Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: capsuleBg,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Animated Micro Pulse Dot (Green for Focus, Amber for Break)
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pulseColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: pulseColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Center: Clean Bold Countdown Digits
                  Text(
                    timeString,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                      letterSpacing: -0.4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),

                  // Right: Micro Play/Pause Icon
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (isRunning) {
                        timerNotifier.pause();
                      } else {
                        timerNotifier.resume();
                      }
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: textColor,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
