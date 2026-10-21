import 'package:flutter/material.dart';

/// Premium Material 3 Dropdown Form Field with rounded corners, tonal container,
/// elevated rounded popup menu, and custom trailing chevron.
class AreteDropdownFormField<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T?>? validator;
  final Widget? prefixIcon;
  final bool isExpanded;
  final EdgeInsetsGeometry? contentPadding;

  const AreteDropdownFormField({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.isExpanded = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fill = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.60);

    final popupBg = isDark
        ? const Color(0xFF252B27)
        : const Color(0xFFFAF7F2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: isExpanded,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          dropdownColor: popupBg,
          borderRadius: BorderRadius.circular(18),
          elevation: 6,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: fill,
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact inline rounded dropdown pill for Settings, Focus screen, and toolbars.
class AreteDropdownButton<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final Widget? icon;

  const AreteDropdownButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pillBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);

    final popupBg = isDark
        ? const Color(0xFF252B27)
        : const Color(0xFFFAF7F2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: hint != null
              ? Text(
                  hint!,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          dropdownColor: popupBg,
          borderRadius: BorderRadius.circular(16),
          elevation: 6,
          isDense: true,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
