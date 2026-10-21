import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AreteButtonVariant { primary, secondary, ghost, danger }

class AreteButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AreteButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;

  const AreteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AreteButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.padding,
  });

  @override
  State<AreteButton> createState() => _AreteButtonState();
}

class _AreteButtonState extends State<AreteButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide borderSide = BorderSide.none;

    switch (widget.variant) {
      case AreteButtonVariant.primary:
        bg = isDark ? AppColors.darkPrimaryAccent : AppColors.lightPrimaryAccent;
        fg = isDark ? const Color(0xFF121212) : Colors.white;
        if (_isHovered) {
          bg = isDark ? AppColors.darkAccentHover : AppColors.lightAccentHover;
        }
        break;
      case AreteButtonVariant.secondary:
        bg = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
        fg = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
        borderSide = BorderSide(
          color: _isHovered
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1,
        );
        break;
      case AreteButtonVariant.ghost:
        bg = _isHovered
            ? (isDark ? AppColors.darkSurfaceVariant : AppColors.lightAccentLight)
            : Colors.transparent;
        fg = isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
        break;
      case AreteButtonVariant.danger:
        bg = isDark ? AppColors.dangerMutedDark : AppColors.dangerMutedLight;
        fg = AppColors.dangerMuted;
        borderSide = const BorderSide(
          color: AppColors.dangerMuted,
          width: 1,
        );
        break;
    }

    final effectivePadding = widget.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    Widget childWidget = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );

    return MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: widget.onPressed != null ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: widget.onPressed != null ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.01 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: widget.onPressed == null ? bg.withValues(alpha: 0.5) : bg,
              borderRadius: BorderRadius.circular(10),
              border: borderSide != BorderSide.none
                  ? Border.fromBorderSide(borderSide)
                  : null,
              boxShadow: _isHovered && widget.onPressed != null && widget.variant == AreteButtonVariant.primary
                  ? [
                      BoxShadow(
                        color: bg.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: widget.isLoading ? null : widget.onPressed,
                child: Padding(
                  padding: effectivePadding,
                  child: childWidget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
