import 'dart:math' as math;
import 'package:flutter/material.dart';

class AreteProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color? color;
  final Color? backgroundColor;
  final double height;
  final BorderRadiusGeometry? borderRadius;

  const AreteProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.backgroundColor,
    this.height = 6.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedProgress = progress.clamp(0.0, 1.0);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveBg = backgroundColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final radius = borderRadius ?? BorderRadius.circular(height / 2);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: effectiveBg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * clampedProgress,
                height: height,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: radius,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AreteProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0 (countdown ratio: 1.0 = full, 0.0 = over)
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? child;

  const AreteProgressRing({
    super.key,
    required this.progress,
    this.size = 54.0,
    this.strokeWidth = 5.0,
    this.color,
    this.backgroundColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    final effectiveBg = backgroundColor ??
        theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
      builder: (context, animatedProgress, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _AreteProgressRingPainter(
                  progress: animatedProgress,
                  strokeWidth: strokeWidth,
                  color: effectiveColor,
                  backgroundColor: effectiveBg,
                ),
              ),
              if (child != null) Center(child: child!),
            ],
          ),
        );
      },
    );
  }
}

class _AreteProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;

  const _AreteProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 1. Draw full background ring track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Draw active countdown arc
    if (progress > 0.001) {
      final activePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2; // 12 o'clock top
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        activePaint,
      );

      // 3. Subtle bead / dot at leading tip for large timer displays
      if (size.width >= 120 && progress > 0.02 && progress < 0.98) {
        final tipAngle = startAngle + sweepAngle;
        final tipOffset = Offset(
          center.dx + radius * math.cos(tipAngle),
          center.dy + radius * math.sin(tipAngle),
        );
        final beadPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tipOffset, strokeWidth * 0.75, beadPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AreteProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
