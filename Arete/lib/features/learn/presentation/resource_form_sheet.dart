import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_dropdown.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../data/learn_repository.dart';
import '../domain/learning_resource_model.dart';
import '../utils/youtube_parser.dart';

class ResourceFormSheet extends ConsumerStatefulWidget {
  final LearningResource? resource;
  final String? initialCollectionId;

  const ResourceFormSheet({
    super.key,
    this.resource,
    this.initialCollectionId,
  });

  static Future<void> show(
    BuildContext context, {
    LearningResource? resource,
    String? initialCollectionId,
  }) {
    return AreteBottomSheet.show(
      context: context,
      title: resource == null ? 'Add Learning Resource' : 'Edit Resource',
      child: ResourceFormSheet(
        resource: resource,
        initialCollectionId: initialCollectionId,
      ),
    );
  }

  @override
  ConsumerState<ResourceFormSheet> createState() => _ResourceFormSheetState();
}

class _ResourceFormSheetState extends ConsumerState<ResourceFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _durationController;
  late final TextEditingController _notesController;

  late ResourceType _selectedType;
  String? _selectedCollectionId;
  String? _detectedThumbnailUrl;
  bool _isPlaylist = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.resource?.title ?? '');
    _urlController = TextEditingController(text: widget.resource?.url ?? '');
    _durationController = TextEditingController(text: widget.resource?.duration ?? '');
    _notesController = TextEditingController(text: widget.resource?.notes ?? '');

    _selectedType = widget.resource?.resourceType ?? ResourceType.video;
    _selectedCollectionId = widget.resource?.collectionId ?? widget.initialCollectionId;
    _detectedThumbnailUrl = widget.resource?.effectiveThumbnailUrl;

    if (_urlController.text.isNotEmpty) {
      _analyzeUrl(_urlController.text);
    }

    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _titleController.dispose();
    _urlController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    _analyzeUrl(_urlController.text);
  }

  void _analyzeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      if (_detectedThumbnailUrl != null) {
        setState(() {
          _detectedThumbnailUrl = null;
          _isPlaylist = false;
        });
      }
      return;
    }

    final isYt = YouTubeParser.isYouTubeUrl(trimmed);
    final isPl = YouTubeParser.isPlaylist(trimmed);
    final thumb = YouTubeParser.getThumbnailUrl(trimmed);

    setState(() {
      _isPlaylist = isPl;
      if (isYt) {
        _selectedType = ResourceType.video;
        if (thumb != null) {
          _detectedThumbnailUrl = thumb;
        }
      }
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    final duration = _durationController.text.trim();
    final effectiveThumb = _detectedThumbnailUrl ??
        (YouTubeParser.isYouTubeUrl(url) ? YouTubeParser.getThumbnailUrl(url) : null);

    final res = widget.resource != null
        ? widget.resource!.copyWith(
            title: title,
            url: url.isEmpty ? 'https://' : url,
            resourceType: _selectedType,
            collectionId: _selectedCollectionId,
            duration: duration.isEmpty ? null : duration,
            thumbnailUrl: effectiveThumb,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            updatedAt: now,
          )
        : LearningResource(
            id: const Uuid().v4(),
            title: title,
            url: url.isEmpty ? 'https://' : url,
            resourceType: _selectedType,
            collectionId: _selectedCollectionId,
            duration: duration.isEmpty ? null : duration,
            thumbnailUrl: effectiveThumb,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            status: ResourceStatus.notStarted,
            progressPercentage: 0,
            createdAt: now,
            updatedAt: now,
          );

    if (widget.resource != null) {
      ref.read(resourcesProvider.notifier).updateResource(res);
    } else {
      ref.read(resourcesProvider.notifier).addResource(res);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final collectionsState = ref.watch(collectionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // YouTube / Link Auto-Parser Input
        AreteTextField(
          label: 'URL / Link (YouTube Video, Playlist, Article, Course)',
          hint: 'https://youtube.com/watch?v=... or youtu.be/...',
          controller: _urlController,
          keyboardType: TextInputType.url,
          autofocus: widget.resource == null,
        ),
        const SizedBox(height: 12),

        // High-res YouTube Thumbnail Preview
        if (_detectedThumbnailUrl != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDark ? const Color(0xFF1E2320) : const Color(0xFFF4F1EA),
              border: Border.all(
                color: const Color(0xFFFF7A59).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      _detectedThumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        final fallback = YouTubeParser.getFallbackThumbnailUrl(_urlController.text);
                        if (fallback != null) {
                          return Image.network(
                            fallback,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildThumbPlaceholder(theme),
                          );
                        }
                        return _buildThumbPlaceholder(theme);
                      },
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF7A59), size: 16),
                          const SizedBox(width: 5),
                          Text(
                            _isPlaylist ? 'YouTube Playlist' : 'YouTube Video',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Direct Launch',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Title Input
        AreteTextField(
          label: 'Resource Title',
          hint: 'e.g. System Design Primer, Dynamic Programming Patterns',
          controller: _titleController,
        ),
        const SizedBox(height: 14),

        // Target Folder Selection
        collectionsState.when(
          data: (cols) {
            return AreteDropdownFormField<String?>(
              label: 'Target Folder',
              value: _selectedCollectionId,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.inbox_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('General Library (Unassigned)'),
                    ],
                  ),
                ),
                ...cols.map((c) {
                  return DropdownMenuItem<String?>(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(c.iconData, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _selectedCollectionId = val),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),

        // Resource Type & Duration Tag in 2 Columns
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AreteDropdownFormField<ResourceType>(
                    label: 'Category Type',
                    value: _selectedType,
                    isExpanded: true,
                    items: ResourceType.values.map((type) {
                      return DropdownMenuItem<ResourceType>(
                        value: type,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(type.icon, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                type.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duration Tag',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  AreteTextField(
                    hint: '45m or 1h 30m',
                    controller: _durationController,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Quick Duration Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['15m', '25m', '45m', '1h', '1h 30m', '2h', '3h 30m'].map((preset) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _durationController.text = preset;
                    setState(() {});
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Notes / Mental Models
        AreteTextField(
          label: 'Personal Key Takeaways / Notes (optional)',
          hint: 'Key concepts, mental models, or timestamps...',
          controller: _notesController,
          maxLines: 2,
        ),
        const SizedBox(height: 24),

        // Submit Button
        AreteButton(
          label: widget.resource == null ? 'Add to Learning Library' : 'Save Changes',
          onPressed: _save,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildThumbPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.video_library_rounded,
          size: 44,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
