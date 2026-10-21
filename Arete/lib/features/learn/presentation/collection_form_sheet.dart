import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../data/learn_repository.dart';
import '../domain/learning_collection_model.dart';

class CollectionFormSheet extends ConsumerStatefulWidget {
  final LearningCollection? collection;

  const CollectionFormSheet({super.key, this.collection});

  static Future<void> show(BuildContext context, {LearningCollection? collection}) {
    return AreteBottomSheet.show(
      context: context,
      title: collection == null ? 'New Library Folder' : 'Edit Folder',
      child: CollectionFormSheet(collection: collection),
    );
  }

  @override
  ConsumerState<CollectionFormSheet> createState() => _CollectionFormSheetState();
}

class _CollectionFormSheetState extends ConsumerState<CollectionFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late String _selectedHexColor;
  late String _selectedIconKey;

  static const List<({Color color, String hex, String name})> pastelTints = [
    (color: Color(0xFFD2E8D4), hex: '#D2E8D4', name: 'Sage Mint'),
    (color: Color(0xFFFFDDB3), hex: '#FFDDB3', name: 'Warm Amber'),
    (color: Color(0xFFE8DEF8), hex: '#E8DEF8', name: 'Lavender'),
    (color: Color(0xFFFDE8E1), hex: '#FDE8E1', name: 'Soft Coral'),
    (color: Color(0xFFF4F1EA), hex: '#F4F1EA', name: 'Ceramic'),
    (color: Color(0xFFCFFAFE), hex: '#CFFAFE', name: 'Sky Cyan'),
    (color: Color(0xFFFEF3C7), hex: '#FEF3C7', name: 'Sun Amber'),
  ];

  static const List<({String key, IconData icon, String label})> folderIcons = [
    (key: 'folder', icon: Icons.folder_rounded, label: 'Folder'),
    (key: 'dns', icon: Icons.dns_rounded, label: 'Backend'),
    (key: 'code', icon: Icons.code_rounded, label: 'DSA & Code'),
    (key: 'psychology', icon: Icons.psychology_rounded, label: 'Mindset'),
    (key: 'spa', icon: Icons.spa_rounded, label: 'Growth'),
    (key: 'menu_book', icon: Icons.menu_book_rounded, label: 'Books'),
    (key: 'rocket_launch', icon: Icons.rocket_launch_rounded, label: 'Launch'),
    (key: 'school', icon: Icons.school_rounded, label: 'Courses'),
    (key: 'lightbulb', icon: Icons.lightbulb_rounded, label: 'Ideas'),
    (key: 'terminal', icon: Icons.terminal_rounded, label: 'Tools'),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.collection?.title ?? '');
    _descController = TextEditingController(text: widget.collection?.description ?? '');
    _selectedHexColor = widget.collection?.color ?? '#D2E8D4';
    _selectedIconKey = widget.collection?.icon ?? 'folder';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Color get _currentColor {
    try {
      final clean = _selectedHexColor.replaceFirst('#', '0xFF');
      return Color(int.parse(clean));
    } catch (_) {
      return const Color(0xFFD2E8D4);
    }
  }

  IconData get _currentIcon {
    return LearningCollection.getFolderIcon(_selectedIconKey);
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();

    final col = widget.collection != null
        ? widget.collection!.copyWith(
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            color: _selectedHexColor,
            icon: _selectedIconKey,
            updatedAt: now,
          )
        : LearningCollection(
            id: const Uuid().v4(),
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            color: _selectedHexColor,
            icon: _selectedIconKey,
            createdAt: now,
            updatedAt: now,
          );

    if (widget.collection != null) {
      ref.read(collectionsProvider.notifier).updateCollection(col);
    } else {
      ref.read(collectionsProvider.notifier).addCollection(col);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live Preview Card
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2320) : _currentColor.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : _currentColor.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : _currentColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _currentIcon,
                  size: 24,
                  color: isDark ? Colors.white : const Color(0xFF1B3623),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleController.text.trim().isEmpty
                          ? 'Folder Name'
                          : _titleController.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.collection != null
                          ? widget.collection!.summaryText
                          : '0 Items • 0m total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Preview',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Folder Title
        AreteTextField(
          label: 'Folder Title',
          hint: 'e.g. Backend & System Design, DSA & Algorithms',
          controller: _titleController,
          autofocus: widget.collection == null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),

        // Description
        AreteTextField(
          label: 'Scope / Description (optional)',
          hint: 'e.g. Core microservices, distributed systems, and DBs...',
          controller: _descController,
          maxLines: 2,
        ),
        const SizedBox(height: 18),

        // Pastel Color Tint Selector
        Text(
          'Pastel Color Tint',
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: pastelTints.map((tint) {
              final isSelected = tint.hex.toLowerCase() == _selectedHexColor.toLowerCase();
              return GestureDetector(
                onTap: () => setState(() => _selectedHexColor = tint.hex),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2.5)
                        : Border.all(color: Colors.black12, width: 1),
                  ),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tint.color,
                      shape: BoxShape.circle,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Color(0xFF1B3623))
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        // Icon Selector
        Text(
          'Folder Icon',
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: folderIcons.map((item) {
              final isSelected = item.key == _selectedIconKey;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  avatar: Icon(
                    item.icon,
                    size: 18,
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  ),
                  label: Text(item.label),
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedIconKey = item.key);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 26),

        // Submit Button
        AreteButton(
          label: widget.collection == null ? 'Create Folder' : 'Save Changes',
          onPressed: _save,
          fullWidth: true,
        ),

        if (widget.collection != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            label: const Text(
              'Delete Folder',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Folder'),
                  content: Text(
                    'Are you sure you want to delete "${widget.collection!.title}"? Associated resources will be unassigned.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                ref.read(collectionsProvider.notifier).deleteCollection(widget.collection!.id);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ],
    );
  }
}
