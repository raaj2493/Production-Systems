import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiParticle {
  final Color color;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final double rotation;
  final double vRotation;

  ConfettiParticle({
    required this.color,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.vRotation,
  });
}

class AreteConfettiController {
  _AreteConfettiOverlayState? _state;

  void trigger({Offset? origin}) {
    _state?.trigger(origin: origin);
  }
}

class AreteConfettiOverlay extends StatefulWidget {
  final Widget child;
  final AreteConfettiController controller;

  const AreteConfettiOverlay({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<AreteConfettiOverlay> createState() => _AreteConfettiOverlayState();
}

class _AreteConfettiOverlayState extends State<AreteConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  static const _palette = [
    Color(0xFFFF7A59), // Vivid Coral
    Color(0xFF2A4E35), // Forest Olive
    Color(0xFFFFDDB3), // Warm Amber
    Color(0xFFE8DEF8), // Lavender
    Color(0xFF8CD49E), // Mint
    Color(0xFFFFD700), // Gold
    Color(0xFF6B8FB5), // Slate Blue
  ];

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    if (widget.controller._state == this) {
      widget.controller._state = null;
    }
    _animController.dispose();
    super.dispose();
  }

  void trigger({Offset? origin}) {
    _particles.clear();
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(400, 800);
    final startX = origin?.dx ?? (size.width / 2);
    final startY = origin?.dy ?? (size.height * 0.4);

    for (int i = 0; i < 48; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 4.0 + _random.nextDouble() * 9.0;
      _particles.add(
        ConfettiParticle(
          color: _palette[_random.nextInt(_palette.length)],
          x: startX,
          y: startY,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 5.0, // upward boost
          size: 6.0 + _random.nextDouble() * 7.0,
          rotation: _random.nextDouble() * math.pi,
          vRotation: (_random.nextDouble() - 0.5) * 0.3,
        ),
      );
    }
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_animController.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(
                  progress: _animController.value,
                  particles: _particles,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final currentX = p.x + p.vx * progress * 32;
      final currentY = p.y + p.vy * progress * 32 + (0.5 * 18.0 * progress * progress * 32);
      final currentRotation = p.rotation + p.vRotation * progress * 32;

      paint.color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
