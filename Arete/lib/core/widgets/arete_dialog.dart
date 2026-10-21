import 'package:flutter/material.dart';
import 'arete_button.dart';

class AreteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const AreteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.onCancel,
    this.isDestructive = false,
  });

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AreteDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(title, style: theme.textTheme.headlineMedium),
      content: Text(message, style: theme.textTheme.bodyMedium),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        AreteButton(
          label: cancelLabel,
          variant: AreteButtonVariant.ghost,
          onPressed: () {
            if (onCancel != null) {
              onCancel!();
            } else {
              Navigator.of(context).pop(false);
            }
          },
        ),
        const SizedBox(width: 8),
        AreteButton(
          label: confirmLabel,
          variant: isDestructive
              ? AreteButtonVariant.danger
              : AreteButtonVariant.primary,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}
