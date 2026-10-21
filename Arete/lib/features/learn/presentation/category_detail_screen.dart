import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_empty_state.dart';
import '../data/learn_repository.dart';
import '../data/learning_hub_repository.dart';
import '../domain/learning_project_model.dart';
import '../domain/learning_roadmap_model.dart';

class CategoryDetailScreen extends ConsumerWidget {
  final String categoryId;

  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categoriesAsync = ref.watch(learningCategoriesProvider);
    final roadmapsAsync = ref.watch(learningRoadmapsProvider);
    final projectsAsync = ref.watch(learningProjectsProvider);
    final resourcesAsync = ref.watch(resourcesProvider);

    return categoriesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (categories) {
        final category = categories.where((c) => c.id == categoryId).firstOrNull;
        if (category == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Category not found')),
          );
        }

        final roadmaps = roadmapsAsync.value
                ?.where((r) => r.categoryId == categoryId)
                .toList() ??
            [];

        final projects = projectsAsync.value
                ?.where((p) => p.categoryId == categoryId)
                .toList() ??
            [];

        final resources = resourcesAsync.value
                ?.where((r) => r.topic == category.title || r.topic == category.id)
                .toList() ??
            [];

        final catColor = category.categoryColor;

        return Scaffold(
          appBar: AppBar(
            title: Text(category.title),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainer
                        : catColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: catColor.withValues(alpha: isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              category.iconData,
                              size: 28,
                              color: catColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${roadmaps.length} Roadmap${roadmaps.length == 1 ? '' : 's'} • ${projects.length} Project${projects.length == 1 ? '' : 's'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Topics Mastery',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${category.completedTopics} / ${category.totalTopics} (${(category.progressRatio * 100).toInt()}%)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: catColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: LinearProgressIndicator(
                          value: category.progressRatio,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(catColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Roadmaps Section
                Row(
                  children: [
                    Icon(Icons.alt_route_rounded, size: 20, color: catColor),
                    const SizedBox(width: 8),
                    Text(
                      'Roadmaps',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (roadmaps.isEmpty)
                  const AreteEmptyState(
                    icon: Icons.alt_route_outlined,
                    title: 'No Roadmaps',
                    description: 'No roadmaps defined for this category.',
                  )
                else
                  ...roadmaps.map((roadmap) => _buildRoadmapCard(context, roadmap, catColor)),

                const SizedBox(height: 24),

                // Projects Section
                Row(
                  children: [
                    Icon(Icons.code_rounded, size: 20, color: catColor),
                    const SizedBox(width: 8),
                    Text(
                      'Projects',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (projects.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No dedicated standalone projects in this category yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...projects.map((project) => _buildProjectCard(context, project)),

                const SizedBox(height: 24),

                // Resources Section
                if (resources.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.bookmark_border_rounded, size: 20, color: catColor),
                      const SizedBox(width: 8),
                      Text(
                        'Category Resources',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...resources.map((resource) {
                    return AreteCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      borderRadius: 16,
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded, color: catColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resource.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (resource.notes != null)
                                  Text(
                                    resource.notes!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoadmapCard(
    BuildContext context,
    LearningRoadmap roadmap,
    Color catColor,
  ) {
    final theme = Theme.of(context);

    return AreteCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      onTap: () {
        context.push('/learn/roadmap/${roadmap.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  roadmap.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (roadmap.primaryLanguage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    roadmap.primaryLanguage!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: catColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (roadmap.description != null) ...[
            const SizedBox(height: 6),
            Text(
              roadmap.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${roadmap.completedTopics} of ${roadmap.totalTopics} topics',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(roadmap.progressRatio * 100).toInt()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: catColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: roadmap.progressRatio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(catColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, LearningProject project) {
    final theme = Theme.of(context);

    return AreteCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      onTap: () {
        context.push('/learn/project/${project.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: project.statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  project.statusDisplay,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: project.statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (project.description != null) ...[
            const SizedBox(height: 6),
            Text(
              project.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (project.techStack.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: project.techStack.take(4).map((tech) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tech,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
