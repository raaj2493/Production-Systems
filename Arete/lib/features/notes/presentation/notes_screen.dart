import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_dialog.dart';
import '../../../core/widgets/arete_empty_state.dart';
import '../data/note_repository.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notesState = ref.watch(notesProvider);
    final allTagsAsync = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes & Reflections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Note',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
          );
        },
        child: const Icon(Icons.edit_outlined),
      ),
      body: notesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) {
          var filteredNotes = notes;
          if (_selectedTag != null) {
            filteredNotes = filteredNotes.where((n) => n.tags.contains(_selectedTag)).toList();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notesProvider);
              ref.invalidate(allTagsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Tag Filter Row
                allTagsAsync.maybeWhen(
                  data: (tags) {
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: const Text('All Tags'),
                                selected: _selectedTag == null,
                                onSelected: (_) => setState(() => _selectedTag = null),
                              ),
                              const SizedBox(width: 8),
                              ...tags.map((tag) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: FilterChip(
                                    label: Text('#$tag'),
                                    selected: _selectedTag == tag,
                                    onSelected: (selected) {
                                      setState(() => _selectedTag = selected ? tag : null);
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),

                if (filteredNotes.isEmpty) ...[
                  AreteEmptyState(
                    icon: Icons.note_alt_outlined,
                    title: 'No Notes Found',
                    description: 'Capture principles, deep insights, or summaries of what you learn.',
                    actionLabel: 'Write Note',
                    onAction: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                      );
                    },
                  ),
                ] else ...[
                  ...filteredNotes.map((note) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: AreteCard(
                        padding: const EdgeInsets.all(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NoteEditorScreen(note: note),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (note.isPinned) ...[
                                  Icon(
                                    Icons.push_pin,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    note.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      size: 18,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                  padding: EdgeInsets.zero,
                                  onSelected: (val) async {
                                    if (val == 'pin') {
                                      ref.read(notesProvider.notifier).togglePin(note.id);
                                    } else if (val == 'delete') {
                                      final confirmed = await AreteDialog.showConfirmation(
                                        context: context,
                                        title: 'Delete Note',
                                        message: 'Are you sure you want to delete "${note.title}"?',
                                        confirmLabel: 'Delete',
                                        isDestructive: true,
                                      );
                                      if (confirmed == true) {
                                        ref.read(notesProvider.notifier).deleteNote(note.id);
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'pin',
                                      child: Text(note.isPinned ? 'Unpin' : 'Pin to Top'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete Note', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (note.body.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                note.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (note.goalTitle != null) ...[
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.flag_outlined,
                                              size: 11, color: theme.colorScheme.primary),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              note.goalTitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (note.tags.isNotEmpty) ...[
                                  Expanded(
                                    child: Text(
                                      note.tags.map((t) => '#$t').join(' '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ] else ...[
                                  const Spacer(),
                                ],
                                Text(
                                  AppDateUtils.formatShortDate(note.updatedAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
