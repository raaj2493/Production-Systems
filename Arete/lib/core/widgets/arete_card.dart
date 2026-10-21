import 'package:flutter/material.dart';

class AreteCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool hoverEffect;

  const AreteCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 12.0,
    this.hoverEffect = true,
  });

  @override
  State<AreteCard> createState() => _AreteCardState();
}

class _AreteCardState extends State<AreteCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBg = widget.backgroundColor ??
        (isDark ? theme.colorScheme.surface : theme.colorScheme.surface);
    final effectiveBorder = widget.borderColor ?? theme.colorScheme.outline;
    final hoveredBorder = theme.colorScheme.primary.withValues(alpha: 0.5);

    Widget content = Padding(
      padding: widget.padding ?? const EdgeInsets.all(16.0),
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onTap,
          child: content,
        ),
      );
    }

    final canHover = widget.hoverEffect && widget.onTap != null;

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: canHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: canHover ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        transform: canHover && _isHovered
            ? (Matrix4.identity()..translate(0.0, -2.0, 0.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: canHover && _isHovered ? hoveredBorder : effectiveBorder,
            width: 1.0,
          ),
          boxShadow: canHover && _isHovered
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: content,
        ),
      ),
    );
  }
}
