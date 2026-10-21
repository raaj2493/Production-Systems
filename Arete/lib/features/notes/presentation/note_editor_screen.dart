import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/arete_dropdown.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../../goals/data/goal_repository.dart';
import '../../learn/data/learn_repository.dart';
import '../data/note_repository.dart';
import '../domain/note_model.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late String _id;
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _tagsController;
  late bool _isPinned;
  String? _goalId;
  String? _resourceId;
  late DateTime _createdAt;

  Timer? _debounceTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _id = widget.note?.id ?? const Uuid().v4();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _bodyController = TextEditingController(text: widget.note?.body ?? '');
    _tagsController = TextEditingController(text: widget.note?.tags.join(', ') ?? '');
    _isPinned = widget.note?.isPinned ?? false;
    _goalId = widget.note?.goalId;
    _resourceId = widget.note?.resourceId;
    _createdAt = widget.note?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _saveImmediate();
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _saveImmediate();
    });
  }

  Future<void> _saveImmediate() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    // If both empty and new, don't create an empty orphan note
    if (title.isEmpty && body.isEmpty && widget.note == null) return;

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final note = Note(
      id: _id,
      title: title.isEmpty ? 'Untitled Note' : title,
      body: body,
      isPinned: _isPinned,
      goalId: _goalId,
      resourceId: _resourceId,
      tags: tags,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );

    if (mounted) setState(() => _isSaving = true);
    await ref.read(noteRepositoryProvider).saveNote(note);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalsState = ref.watch(goalsProvider);
    final resourcesState = ref.watch(resourcesProvider);

    return PopScope(
      onPopInvokedWithResult: (_, __) {
        _saveImmediate();
        ref.invalidate(notesProvider);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
          actions: [
            if (_isSaving)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    'Saving...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _isPinned ? theme.colorScheme.primary : null,
              ),
              tooltip: _isPinned ? 'Unpin' : 'Pin to top',
              onPressed: () {
                setState(() => _isPinned = !_isPinned);
                _onChanged();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          children: [
            // Title input
            TextField(
              controller: _titleController,
              onChanged: (_) => _onChanged(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Note Title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // Metadata: Tags, Goal association, Resource association
            AreteTextField(
              label: 'Tags (comma-separated)',
              hint: 'ideas, architecture, quotes',
              controller: _tagsController,
              onChanged: (_) => _onChanged(),
            ),
            const SizedBox(height: 14),

            // Goal Association
            goalsState.when(
              data: (goals) {
                if (goals.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AreteDropdownFormField<String?>(
                    label: 'Linked Goal (optional)',
                    value: _goalId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...goals.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _goalId = val);
                      _onChanged();
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Resource Association
            resourcesState.when(
              data: (resources) {
                if (resources.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AreteDropdownFormField<String?>(
                    label: 'Linked Learning Resource (optional)',
                    value: _resourceId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...resources.map(
                        (r) => DropdownMenuItem<String?>(
                          value: r.id,
                          child: Text(r.title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _resourceId = val);
                      _onChanged();
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Body input
            Text('Note Content', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            TextField(
              controller: _bodyController,
              onChanged: (_) => _onChanged(),
              maxLines: null,
              minLines: 12,
              style: theme.textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Reflect, take notes, capture ideas...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
