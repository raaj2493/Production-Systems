import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../data/goal_repository.dart';
import '../domain/goal_model.dart';

class GoalFormSheet extends ConsumerStatefulWidget {
  final Goal? goal;

  const GoalFormSheet({super.key, this.goal});

  static Future<void> show(BuildContext context, {Goal? goal}) {
    return AreteBottomSheet.show(
      context: context,
      title: goal == null ? 'New Goal' : 'Edit Goal',
      child: GoalFormSheet(goal: goal),
    );
  }

  @override
  ConsumerState<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<GoalFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal?.title ?? '');
    _descController = TextEditingController(text: widget.goal?.description ?? '');
    if (widget.goal?.color != null) {
      _selectedColor = Color(int.parse(widget.goal!.color!.replaceFirst('#', '0xFF')));
    } else {
      _selectedColor = AppColors.categoryPalette.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final hexColor = '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    final now = DateTime.now();

    final goal = widget.goal != null
        ? widget.goal!.copyWith(
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            color: hexColor,
            updatedAt: now,
          )
        : Goal(
            id: const Uuid().v4(),
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            color: hexColor,
            createdAt: now,
            updatedAt: now,
          );

    if (widget.goal != null) {
      ref.read(goalsProvider.notifier).updateGoal(goal);
    } else {
      ref.read(goalsProvider.notifier).addGoal(goal);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AreteTextField(
          label: 'Goal Title',
          hint: 'What meaningful outcome are you pursuing?',
          controller: _titleController,
          autofocus: widget.goal == null,
        ),
        const SizedBox(height: 14),
        AreteTextField(
          label: 'Description (optional)',
          hint: 'Why does this matter to you?',
          controller: _descController,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Text('Color Accent', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: AppColors.categoryPalette.map((color) {
            final isSelected = color.toARGB32() == _selectedColor.toARGB32();
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        AreteButton(
          label: widget.goal == null ? 'Create Goal' : 'Save Changes',
          onPressed: _save,
          fullWidth: true,
        ),
      ],
    );
  }
}
