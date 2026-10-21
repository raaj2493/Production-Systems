import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Auto navigate after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      _proceed();
    });
  }

  void _proceed() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      try {
        context.go('/today');
      } catch (_) {
        // Fallback for standalone tests or environments without GoRouter
      }
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
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF141815) : const Color(0xFFFBFBF6);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _proceed,
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background ambient aura
              Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main content
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: 0.85 + (_scaleAnimation.value * 0.15),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Emblem with soft elevation shadow
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.45)
                                  : primaryColor.withValues(alpha: 0.12),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(36),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Brand Name Typography
                      AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              'A R E T É',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6.0,
                                color: isDark
                                    ? const Color(0xFFE2E9E3)
                                    : const Color(0xFF1B3623),
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Excellence through consistency',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : const Color(0xFF5A665D),
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.4,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom subtle indicator & version
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2DDD3),
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Virtue • Focus • Mastery',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
