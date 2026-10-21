import 'package:flutter/material.dart';

/// Interactive animated checkmark with an elastic spring bounce
/// providing tactile and delightful feedback upon completion.
class AreteCheckCircle extends StatelessWidget {
  final bool isChecked;
  final VoidCallback? onTap;
  final double size;

  const AreteCheckCircle({
    super.key,
    required this.isChecked,
    this.onTap,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            );
          },
          child: isChecked
              ? Icon(
                  Icons.check_circle,
                  key: const ValueKey('checked'),
                  color: theme.colorScheme.primary,
                  size: size,
                )
              : Icon(
                  Icons.radio_button_unchecked,
                  key: const ValueKey('unchecked'),
                  color: theme.colorScheme.outline,
                  size: size,
                ),
        ),
      ),
    );
  }
}
