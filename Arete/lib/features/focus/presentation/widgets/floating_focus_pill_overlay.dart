import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/focus_session_model.dart';
import '../focus_timer_controller.dart';

/// A draggable, edge-snapping floating Material 3 / Material You pill overlay
/// that displays active focus/break countdown, live pulsing breathing indicator,
/// inline play/pause, quick +5m, dismiss, and collapses into an edge bubble.
class FloatingFocusPillOverlay extends ConsumerStatefulWidget {
  const FloatingFocusPillOverlay({super.key});

  @override
  ConsumerState<FloatingFocusPillOverlay> createState() => _FloatingFocusPillOverlayState();
}

class _FloatingFocusPillOverlayState extends ConsumerState<FloatingFocusPillOverlay>
    with TickerProviderStateMixin {
  // Draggable position coordinates
  Offset? _position;
  bool _isCollapsed = false;
  bool _isUserDismissed = false;

  // Snapping animation
  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  // Breathing / pulsing dot animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _snapToClosestEdge(Size screenSize, EdgeInsets padding, double pillWidth, double pillHeight) {
    if (_position == null) return;

    final minX = 12.0;
    final maxX = screenSize.width - pillWidth - 12.0;
    final minY = padding.top + 60.0;
    final maxY = screenSize.height - padding.bottom - 110.0;

    final targetX = (_position!.dx + pillWidth / 2) < (screenSize.width / 2) ? minX : maxX;
    final targetY = _position!.dy.clamp(minY, maxY);

    // If dragged extremely close to the left or right edge, auto-collapse into edge bubble
    final distanceToEdge = math.min(_position!.dx, screenSize.width - (_position!.dx + pillWidth));
    if (distanceToEdge < 8.0) {
      _isCollapsed = true;
    }

    _snapAnimation = Tween<Offset>(
      begin: _position!,
      end: Offset(targetX, targetY),
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic))
      ..addListener(() {
        setState(() {
          _position = _snapAnimation!.value;
        });
      });

    _snapController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(focusTimerProvider);
    final timerNotifier = ref.read(focusTimerProvider.notifier);

    // Only render if a session is currently running (or paused and not dismissed)
    // and full-screen Zen mode is not active.
    final isActive = timerState.state == TimerState.running ||
        (timerState.state == TimerState.paused && !_isUserDismissed);
    if (!isActive || timerState.isZenMode || _isUserDismissed) {
      return const SizedBox.shrink();
    }

    final isBreak = timerState.sessionType != FocusSessionType.focus;
    final isRunning = timerState.state == TimerState.running;

    // Material You Dynamic Color Scheme (Warm Pastel Container, High Contrast Text)
    // Focus Phase: #D2E8D4 (Sage) / #0F291E text
    // Break Phase: #FFDDB3 (Warm Amber) / #2A1800 text
    final containerColor = isBreak ? const Color(0xFFFFDDB3) : const Color(0xFFD2E8D4);
    final textColor = isBreak ? const Color(0xFF2A1800) : const Color(0xFF0F291E);
    final borderColor = isBreak ? const Color(0xFFF0CAA0) : const Color(0xFFB8D6BC);
    final accentDotColor = isBreak ? const Color(0xFFFF6F00) : const Color(0xFF1B5E20);

    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final pillWidth = _isCollapsed ? 56.0 : 310.0;
    final pillHeight = _isCollapsed ? 56.0 : 54.0;

    // Initialize position at top right on first render
    _position ??= Offset(
      screenSize.width - pillWidth - 16.0,
      padding.top + 72.0,
    );

    // Keep position within safe screen bounds
    final currentX = (_position!.dx.clamp(8.0, math.max(8.0, screenSize.width - pillWidth - 8.0))).toDouble();
    final currentY = (_position!.dy.clamp(padding.top + 40.0, math.max(padding.top + 40.0, screenSize.height - padding.bottom - 100.0))).toDouble();

    final timeString = Formatters.formatSeconds(timerState.remainingSeconds);
    final phaseLabel = isBreak
        ? (timerState.sessionType == FocusSessionType.shortBreak ? 'Break' : 'Long Break')
        : 'Focus';

    return Positioned(
      left: currentX,
      top: currentY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position?.dx ?? currentX) + details.delta.dx,
              (_position?.dy ?? currentY) + details.delta.dy,
            );
          });
        },
        onPanEnd: (details) {
          _snapToClosestEdge(screenSize, padding, pillWidth, pillHeight);
        },
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: pillWidth,
            height: pillHeight,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(9999), // Extra rounded M3 pill / 24.dp+
              border: Border.all(
                color: borderColor,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _isCollapsed
                ? _buildCollapsedEdgeBubble(
                    context: context,
                    timerState: timerState,
                    accentDotColor: accentDotColor,
                    textColor: textColor,
                    isBreak: isBreak,
                    isRunning: isRunning,
                  )
                : _buildExpandedPill(
                    context: context,
                    timerState: timerState,
                    timerNotifier: timerNotifier,
                    textColor: textColor,
                    accentDotColor: accentDotColor,
                    phaseLabel: phaseLabel,
                    timeString: timeString,
                    isRunning: isRunning,
                  ),
          ),
        ),
      ),
    );
  }

  /// Minimized State: Sleek circular edge bubble with continuous progress ring arc
  Widget _buildCollapsedEdgeBubble({
    required BuildContext context,
    required FocusTimerState timerState,
    required Color accentDotColor,
    required Color textColor,
    required bool isBreak,
    required bool isRunning,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: () {
        setState(() {
          _isCollapsed = false;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress ring arc
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: timerState.remainingRatio,
              strokeWidth: 3.5,
              strokeCap: StrokeCap.round,
              backgroundColor: textColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accentDotColor),
            ),
          ),
          // Center Icon with live breathing dot
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBreak ? Icons.coffee_rounded : Icons.bolt_rounded,
                size: 16,
                color: textColor,
              ),
              if (isRunning) ...[
                const SizedBox(height: 2),
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accentDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Expanded State: Full Material 3 Pill with Play/Pause, +5m, Countdown, Phase Badge & Dismiss
  Widget _buildExpandedPill({
    required BuildContext context,
    required FocusTimerState timerState,
    required FocusTimerController timerNotifier,
    required Color textColor,
    required Color accentDotColor,
    required String phaseLabel,
    required String timeString,
    required bool isRunning,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Play / Pause Button (minimum touch target >= 48x48)
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: Icon(
              isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 22,
              color: textColor,
            ),
            tooltip: isRunning ? 'Pause countdown' : 'Resume countdown',
            onPressed: () {
              if (isRunning) {
                timerNotifier.pause();
              } else {
                timerNotifier.resume();
              }
            },
          ),
        ),

        // 2. Middle Section: Tappable body to reopen Immersive Full-Screen Focus View
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Seamlessly reopen Areté directly into the Immersive Full-Screen Focus View
              timerNotifier.openZenMode();
              context.go('/focus');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phase Badge Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      phaseLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Countdown digits + live breathing dot
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRunning) ...[
                        FadeTransition(
                          opacity: _pulseAnimation,
                          child: Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: accentDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. Quick +5m Add Time Button (touch target >= 48x48)
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 14, color: textColor),
                Text(
                  '5m',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ],
            ),
            tooltip: 'Add 5 minutes',
            onPressed: () {
              timerNotifier.addMinutes(5);
            },
          ),
        ),

        // 4. Collapse to Edge Bubble button
        SizedBox(
          width: 32,
          height: 48,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: textColor.withValues(alpha: 0.7),
            ),
            tooltip: 'Collapse to edge',
            onPressed: () {
              setState(() {
                _isCollapsed = true;
              });
            },
          ),
        ),

        // 5. Dismiss 'X' Button
        SizedBox(
          width: 36,
          height: 48,
          child: IconButton(
            padding: const EdgeInsets.only(right: 6),
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: textColor.withValues(alpha: 0.65),
            ),
            tooltip: 'Dismiss overlay',
            onPressed: () {
              setState(() {
                _isUserDismissed = true;
              });
            },
          ),
        ),
      ],
    );
  }
}
