import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_text_field.dart';
import '../data/learning_hub_repository.dart';
import '../domain/learning_project_model.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  void _editCheckpointNotes(BuildContext context, LearningProject project) {
    final controller = TextEditingController(text: project.checkpointNotes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text(
                  'Update Checkpoint & Milestone',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  project.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.sagePrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                AreteTextField(
                  controller: controller,
                  label: 'Checkpoint Notes',
                  hint: 'Where did you leave off? Next implementation step...',
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final repo = ref.read(learningHubRepositoryProvider);
                        final updated = project.copyWith(
                          checkpointNotes: controller.text.trim(),
                          updatedAt: DateTime.now(),
                        );
                        await repo.updateProject(updated);
                        ref.invalidate(learningProjectsProvider);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Save Checkpoint'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStatusDialog(BuildContext context, LearningProject project) {
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Change Project Status'),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                final repo = ref.read(learningHubRepositoryProvider);
                await repo.updateProject(project.copyWith(status: 'planned', updatedAt: DateTime.now()));
                ref.invalidate(learningProjectsProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Planned'),
            ),
            SimpleDialogOption(
              onPressed: () async {
                final repo = ref.read(learningHubRepositoryProvider);
                await repo.updateProject(project.copyWith(status: 'in_progress', updatedAt: DateTime.now()));
                ref.invalidate(learningProjectsProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('In Progress'),
            ),
            SimpleDialogOption(
              onPressed: () async {
                final repo = ref.read(learningHubRepositoryProvider);
                await repo.updateProject(project.copyWith(status: 'completed', updatedAt: DateTime.now()));
                ref.invalidate(learningProjectsProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Completed'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final projectsAsync = ref.watch(learningProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Overview'),
        elevation: 0,
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (projects) {
          final project = projects.where((p) => p.id == widget.projectId).firstOrNull;
          if (project == null) {
            return const Center(child: Text('Project not found'));
          }

          final isPrimary = project.isPrimary;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainer
                        : (isPrimary
                            ? AppColors.sagePrimaryContainer.withValues(alpha: 0.35)
                            : const Color(0xFFFDE8E1).withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isPrimary
                          ? AppColors.sagePrimary.withValues(alpha: 0.25)
                          : const Color(0xFFFF7A59).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPrimary
                                  ? AppColors.sagePrimary.withValues(alpha: 0.12)
                                  : const Color(0xFFFF7A59).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPrimary
                                  ? 'Stage ${project.projectOrder} of 8'
                                  : 'Advanced AI System',
                              style: TextStyle(
                                color: isPrimary ? AppColors.sagePrimary : const Color(0xFFFF7A59),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showStatusDialog(context, project),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: project.statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    project.statusDisplay,
                                    style: TextStyle(
                                      color: project.statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, size: 16, color: project.statusColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        project.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (project.architecture != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.architecture_rounded, size: 16, color: AppColors.sagePrimary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                project.architecture!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                if (project.description != null) ...[
                  Text(
                    'About this Project',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  AreteCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 16,
                    child: Text(
                      project.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Checkpoint Notes (Resume Learning Section)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Checkpoint & Progress',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _editCheckpointNotes(context, project),
                      tooltip: 'Update checkpoint',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AreteCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  onTap: () => _editCheckpointNotes(context, project),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.flag_circle_rounded, color: AppColors.sagePrimary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.checkpointNotes != null && project.checkpointNotes!.isNotEmpty
                                  ? project.checkpointNotes!
                                  : 'No checkpoint recorded yet. Tap to note where you left off...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: project.checkpointNotes != null && project.checkpointNotes!.isNotEmpty
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontStyle: project.checkpointNotes == null || project.checkpointNotes!.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to update checkpoint note',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.sagePrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tech Stack
                if (project.techStack.isNotEmpty) ...[
                  Text(
                    'Technology Stack',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: project.techStack.map((tech) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.colorScheme.surfaceContainer
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          tech,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Domain Areas
                if (project.domainAreas.isNotEmpty) ...[
                  Text(
                    'Domain Areas & Entities',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: project.domainAreas.map((domain) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2E8D4).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          domain,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.sagePrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Learning Focus
                if (project.learningFocus.isNotEmpty) ...[
                  Text(
                    'Learning Focus & Objectives',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  AreteCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 16,
                    child: Column(
                      children: project.learningFocus.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.sagePrimary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    color: AppColors.sagePrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }
}
