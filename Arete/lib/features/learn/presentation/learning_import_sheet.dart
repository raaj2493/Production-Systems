import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_button.dart';
import '../data/learning_hub_repository.dart';
import '../data/learning_import_service.dart';

class LearningImportSheet extends ConsumerStatefulWidget {
  const LearningImportSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LearningImportSheet(),
    );
  }

  @override
  ConsumerState<LearningImportSheet> createState() => _LearningImportSheetState();
}

class _LearningImportSheetState extends ConsumerState<LearningImportSheet> {
  bool _isLoading = true;
  bool _isImporting = false;
  String? _errorMessage;
  LearningImportPreview? _preview;
  Map<String, dynamic>? _loadedJson;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final importService = ref.read(learningImportServiceProvider);
      final jsonStr = await importService.loadDefaultAssetJsonString();
      if (jsonStr == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load asset file arete_learning_import_organized.json';
        });
        return;
      }

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid JSON structure: expected top-level JSON object.';
        });
        return;
      }

      if (!importService.validateJson(decoded)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incompatible schema or missing learning_categories in JSON.';
        });
        return;
      }

      final preview = importService.inspectImport(decoded);
      setState(() {
        _isLoading = false;
        _loadedJson = decoded;
        _preview = preview;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error inspecting JSON: $e';
      });
    }
  }

  Future<void> _performImport() async {
    if (_loadedJson == null || _isImporting) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final importService = ref.read(learningImportServiceProvider);
      final result = await importService.executeImport(_loadedJson!, preserveUserProgress: true);

      if (!result.success) {
        setState(() {
          _isImporting = false;
          _errorMessage = result.message;
        });
        return;
      }

      // Invalidate all learning providers
      ref.invalidate(learningCategoriesProvider);
      ref.invalidate(learningRoadmapsProvider);
      ref.invalidate(dsaProblemsProvider);
      ref.invalidate(learningProjectsProvider);
      ref.invalidate(learningProfileProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.sagePrimary,
            content: Text(
              'Successfully imported: ${result.categoriesImported} categories, ${result.roadmapsImported} roadmaps, ${result.topicsImported} topics, ${result.projectsImported} projects, and ${result.dsaProblemsImported} DSA problems.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _errorMessage = 'Import failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.sagePrimaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.sync_alt_rounded,
                      color: AppColors.sagePrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Learning Data',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'arete_learning_import_organized.json',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      left: BorderSide(color: theme.colorScheme.error, width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_preview != null) ...[
                // Integrity Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2822) : const Color(0xFFEAF5EC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.sagePrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppColors.sagePrimary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Safe Transaction & Deduplication',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.sagePrimaryContainer : AppColors.sagePrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your completed topic checkmarks and reflections will never be overwritten. Existing records are safely merged without duplicating data.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Data Preview Grid
                Text(
                  'Content to Import',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        icon: Icons.category_rounded,
                        label: 'Categories',
                        count: '${_preview!.categoriesCount}',
                        color: AppColors.sagePrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        icon: Icons.flag_rounded,
                        label: 'Goals',
                        count: '${_preview!.goalsCount}',
                        color: const Color(0xFFFF7A59),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        icon: Icons.alt_route_rounded,
                        label: 'Roadmaps',
                        count: '${_preview!.roadmapsCount}',
                        color: const Color(0xFF0F4C5C),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Topics',
                        count: '${_preview!.topicsCount}',
                        color: const Color(0xFF7B2CBF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        icon: Icons.code_rounded,
                        label: 'Primary Projects',
                        count: '${_preview!.primaryProjectsCount}',
                        color: const Color(0xFF1B3623),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        icon: Icons.smart_toy_rounded,
                        label: 'AI Systems',
                        count: '${_preview!.advancedAiProjectsCount}',
                        color: const Color(0xFF5A2D00),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        icon: Icons.psychology_rounded,
                        label: 'DSA Practice',
                        count: '${_preview!.dsaProblemsCount} Problems',
                        color: const Color(0xFFE36414),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: 'Known Skills',
                        count: '${_preview!.knownSkillsCount} Skills',
                        color: const Color(0xFF2A4E35),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // Categories List Preview
                Text(
                  'Included Categories',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _preview!.categoryTitles.map((title) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        title,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Import Button
                AreteButton(
                  label: _isImporting ? 'Importing...' : 'Import Learning System',
                  icon: _isImporting ? null : Icons.download_done_rounded,
                  isLoading: _isImporting,
                  fullWidth: true,
                  onPressed: _isImporting ? null : _performImport,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String count,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainer : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
