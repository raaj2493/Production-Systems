import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../focus/data/pip_service.dart';
import '../../focus/presentation/focus_timer_controller.dart';
import '../../focus/presentation/zen_focus_overlay.dart';
import '../../focus/presentation/widgets/pip_focus_view.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPipMode = ref.watch(pipModeProvider);
    if (isPipMode) {
      return const PipFocusView();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isZenMode = ref.watch(focusTimerProvider.select((s) => s.isZenMode));
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final hidePill = isZenMode || keyboardOpen;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 1. Content view with smooth fade transitions
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<int>(navigationShell.currentIndex),
                child: navigationShell,
              ),
            ),
          ),

          // 2. Floating iPhone / Instagram Style Glassmorphic Pill Nav Bar (Auto-hides in Zen Mode & when keyboard is open)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: 16,
            right: 16,
            bottom: hidePill ? -120 : (16 + MediaQuery.of(context).padding.bottom),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              opacity: hidePill ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: hidePill,
                child: _FloatingPillNavBar(
                  currentIndex: navigationShell.currentIndex,
                  onTap: _onTap,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // 3. Immersive Full-Screen Zen Overlay Mode (fixed inset-0 z-50)
          if (isZenMode)
            const Positioned.fill(
              child: ZenFocusOverlay(),
            ),
        ],
      ),
    );
  }
}

class _FloatingPillNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _FloatingPillNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  static const _items = [
    _NavItem(
      label: 'Today',
      activeIcon: Icons.wb_sunny,
      inactiveIcon: Icons.wb_sunny_outlined,
    ),
    _NavItem(
      label: 'Tasks',
      activeIcon: Icons.check_circle,
      inactiveIcon: Icons.check_circle_outline,
    ),
    _NavItem(
      label: 'Focus',
      activeIcon: Icons.timer,
      inactiveIcon: Icons.timer_outlined,
    ),
    _NavItem(
      label: 'Learn',
      activeIcon: Icons.menu_book,
      inactiveIcon: Icons.menu_book_outlined,
    ),
    _NavItem(
      label: 'More',
      activeIcon: Icons.more_horiz,
      inactiveIcon: Icons.more_horiz,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // High contrast specs matching exact requirements
    final activeIndicatorColor = isDark
        ? const Color(0xFF24452E)
        : (theme.colorScheme.primaryContainer);
    final activeTextColor = isDark
        ? const Color(0xFFE2F1E4)
        : const Color(0xFF0F291E);
    final inactiveTextColor = isDark
        ? const Color(0xFF8B948C)
        : const Color(0xFF5A645D);

    final glassBg = isDark
        ? const Color.fromRGBO(24, 28, 25, 0.84)
        : const Color.fromRGBO(255, 255, 255, 0.82);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: glassBg,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: glassBorder, width: 1.2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = (constraints.maxWidth - 8) / _items.length;

                return Stack(
                  children: [
                    // Smooth Sliding Spring Active Pill Physics
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 340),
                      curve: const Cubic(0.34, 1.56, 0.64, 1.0), // spring curve
                      left: 4 + (currentIndex * tabWidth),
                      top: 6,
                      width: tabWidth,
                      height: 54,
                      child: Container(
                        decoration: BoxDecoration(
                          color: activeIndicatorColor,
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: [
                            BoxShadow(
                              color: activeIndicatorColor.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tap Targets & Visible Labels
                    Row(
                      children: List.generate(_items.length, (index) {
                        final item = _items[index];
                        final isSelected = index == currentIndex;

                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9999),
                            onTap: () => onTap(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.08 : 0.95,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      isSelected ? item.activeIcon : item.inactiveIcon,
                                      size: isSelected ? 22 : 20,
                                      color: isSelected ? activeTextColor : inactiveTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isSelected ? 11.0 : 10.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? activeTextColor : inactiveTextColor,
                                      letterSpacing: isSelected ? -0.2 : 0.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _NavItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}
