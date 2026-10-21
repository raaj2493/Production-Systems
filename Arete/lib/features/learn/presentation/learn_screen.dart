import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_dialog.dart';
import '../../../core/widgets/arete_empty_state.dart';
import '../data/learn_repository.dart';
import '../data/learning_hub_repository.dart';
import '../domain/learning_category_model.dart';
import '../domain/learning_collection_model.dart';
import '../domain/learning_project_model.dart';
import '../domain/learning_resource_model.dart';
import '../domain/learning_roadmap_model.dart';
import 'collection_form_sheet.dart';
import 'learning_import_sheet.dart';
import 'resource_form_sheet.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  // 0: Overview, 1: Roadmaps, 2: Projects, 3: Library, 4: Skills
  int _selectedTab = 0;

  // Library category filter: 0: All Items, 1: YouTube Playlists & Videos, 2: Courses, 3: Articles
  int _selectedLibraryCategoryIndex = 0;
  String? _filterCollectionId;

  // Projects sub-segment: 'primary' or 'advanced_ai'
  String _selectedProjectGroup = 'primary';

  Future<void> _launchUrl(String urlStr) async {
    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $urlStr')),
          );
        }
      }
    }
  }

  ({Color bg, Color fg}) _getTypeColors(ResourceType type, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case ResourceType.video:
        return (
          bg: isDark ? const Color(0xFF3E2818) : const Color(0xFFFFDDB3),
          fg: isDark ? const Color(0xFFFFB77D) : const Color(0xFF5A2D00),
        );
      case ResourceType.course:
        return (
          bg: isDark ? const Color(0xFF1B3623) : const Color(0xFFD2E8D4),
          fg: isDark ? const Color(0xFF86D99B) : const Color(0xFF1B3623),
        );
      case ResourceType.article:
        return (
          bg: isDark ? const Color(0xFF382A4C) : const Color(0xFFE8DEF8),
          fg: isDark ? const Color(0xFFD0BCFF) : const Color(0xFF382A4C),
        );
      case ResourceType.book:
        return (
          bg: isDark ? const Color(0xFF3E201B) : const Color(0xFFFDE8E1),
          fg: isDark ? const Color(0xFFFF8B70) : const Color(0xFF6E2E1D),
        );
      case ResourceType.documentation:
        return (
          bg: isDark ? const Color(0xFF1E323A) : const Color(0xFFD0E8F2),
          fg: isDark ? const Color(0xFF82B8D2) : const Color(0xFF0F364C),
        );
      case ResourceType.roadmap:
        return (
          bg: isDark ? const Color(0xFF352B1E) : const Color(0xFFFBF0D2),
          fg: isDark ? const Color(0xFFE5C065) : const Color(0xFF4C3805),
        );
      case ResourceType.other:
        return (
          bg: Theme.of(context).colorScheme.surfaceContainerHighest,
          fg: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(learningCategoriesProvider);
    final roadmapsAsync = ref.watch(learningRoadmapsProvider);
    final projectsAsync = ref.watch(learningProjectsProvider);
    final resourcesState = ref.watch(resourcesProvider);
    final collectionsState = ref.watch(collectionsProvider);
    final profileAsync = ref.watch(learningProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Hub'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt_rounded),
            tooltip: 'Import / Sync Learning Data',
            onPressed: () => LearningImportSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildTopTabItem('Overview', Icons.dashboard_outlined, 0),
                const SizedBox(width: 6),
                _buildTopTabItem('Roadmaps', Icons.alt_route_rounded, 1),
                const SizedBox(width: 6),
                _buildTopTabItem('Projects', Icons.code_rounded, 2),
                const SizedBox(width: 6),
                _buildTopTabItem('Library', Icons.menu_book_rounded, 3),
                const SizedBox(width: 6),
                _buildTopTabItem('Skills & Profile', Icons.person_outline_rounded, 4),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _selectedTab == 3
          ? Padding(
              padding: const EdgeInsets.only(bottom: 84), // clearance over floating pill
              child: FloatingActionButton.extended(
                onPressed: () {
                  ResourceFormSheet.show(context, initialCollectionId: _filterCollectionId);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Resource'),
              ),
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: switch (_selectedTab) {
          0 => _buildOverviewTab(categoriesAsync, roadmapsAsync, projectsAsync),
          1 => _buildRoadmapsTab(roadmapsAsync),
          2 => _buildProjectsTab(projectsAsync),
          3 => _buildLibraryTab(resourcesState, collectionsState),
          4 => _buildSkillsProfileTab(profileAsync),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _buildTopTabItem(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (_selectedTab != index) {
          setState(() => _selectedTab = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sagePrimaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.sagePrimary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.sagePrimary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: OVERVIEW
  // ==========================================
  Widget _buildOverviewTab(
    AsyncValue<List<LearningCategory>> categoriesAsync,
    AsyncValue<List<LearningRoadmap>> roadmapsAsync,
    AsyncValue<List<LearningProject>> projectsAsync,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading categories: $e')),
      data: (categories) {
        if (categories.isEmpty) {
          // Welcome Banner / Empty state to trigger import
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surfaceContainer : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.sagePrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.sagePrimaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 36,
                        color: AppColors.sagePrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Welcome to Areté Learning Hub',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Import your 7 core engineering categories, structured roadmaps, backend projects, and DSA practice sets.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sagePrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => LearningImportSheet.show(context),
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      label: const Text(
                        'Import Learning Data',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final totalTopics = categories.fold(0, (sum, c) => sum + c.totalTopics);
        final completedTopics = categories.fold(0, (sum, c) => sum + c.completedTopics);
        final overallProgress = totalTopics > 0 ? (completedTopics / totalTopics).clamp(0.0, 1.0) : 0.0;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(learningCategoriesProvider);
            ref.invalidate(learningRoadmapsProvider);
            ref.invalidate(learningProjectsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resume Learning Banner / Active Focus
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainer
                        : AppColors.sagePrimaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.sagePrimary.withValues(alpha: isDark ? 0.3 : 0.2),
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
                              color: AppColors.sagePrimary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'CURRENT FOCUS',
                              style: TextStyle(
                                color: AppColors.sagePrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$completedTopics / $totalTopics topics',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.sagePrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Focus Item 1: Two Pointers (DSA)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push('/learn/roadmap/roadmap-dsa'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? theme.colorScheme.surface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF7A59).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.psychology_rounded,
                                  color: Color(0xFFFF7A59),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Two Pointers • DSA Practice',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    Text(
                                      '7 Practice Problems • Java • Recognition Signals',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Focus Item 2: HeroVerse + TaskFlow (Go Backend)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push('/learn/project/proj-primary-1'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? theme.colorScheme.surface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.sagePrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.code_rounded,
                                  color: AppColors.sagePrimary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'HeroVerse + TaskFlow',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    Text(
                                      'Go & Gin Modular Monolith • Port 8080',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: LinearProgressIndicator(
                          value: overallProgress,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sagePrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Categories Header
                Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 20, color: AppColors.sagePrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Learning Categories (7)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Categories Grid
                ...categories.map((cat) {
                  final catColor = cat.categoryColor;

                  return AreteCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    borderRadius: 20,
                    onTap: () {
                      context.push('/learn/category/${cat.id}');
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(cat.iconData, color: catColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${cat.totalRoadmaps} Roadmap${cat.totalRoadmaps == 1 ? '' : 's'} • ${cat.totalProjects} Project${cat.totalProjects == 1 ? '' : 's'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${cat.completedTopics} of ${cat.totalTopics} topics',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${(cat.progressRatio * 100).toInt()}%',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9999),
                          child: LinearProgressIndicator(
                            value: cat.progressRatio,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(catColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 1: ROADMAPS
  // ==========================================
  Widget _buildRoadmapsTab(AsyncValue<List<LearningRoadmap>> roadmapsAsync) {
    final theme = Theme.of(context);

    return roadmapsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (roadmaps) {
        if (roadmaps.isEmpty) {
          return AreteEmptyState(
            icon: Icons.alt_route_outlined,
            title: 'No Roadmaps Found',
            description: 'Import the organized learning JSON to view roadmaps.',
            actionLabel: 'Import Data',
            onAction: () => LearningImportSheet.show(context),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(learningRoadmapsProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: roadmaps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
              final roadmap = roadmaps[index];

              return AreteCard(
                padding: const EdgeInsets.all(18),
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
                              color: AppColors.sagePrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              roadmap.primaryLanguage!,
                              style: const TextStyle(
                                color: AppColors.sagePrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (roadmap.categoryTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        roadmap.categoryTitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.sagePrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${(roadmap.progressRatio * 100).toInt()}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.sagePrimary,
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
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sagePrimary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: PROJECTS
  // ==========================================
  Widget _buildProjectsTab(AsyncValue<List<LearningProject>> projectsAsync) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Projects Group Segmented Control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildProjectSegmentPill('Primary Backend (8)', 'primary'),
                ),
                Expanded(
                  child: _buildProjectSegmentPill('Advanced AI (6)', 'advanced_ai'),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (projects) {
              final filtered = projects
                  .where((p) => p.projectGroup == _selectedProjectGroup)
                  .toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No projects found in this group.'));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(learningProjectsProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final project = filtered[index];

                    return AreteCard(
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
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.sagePrimaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${project.projectOrder}',
                                  style: const TextStyle(
                                    color: AppColors.sagePrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                  style: TextStyle(
                                    color: project.statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (project.architecture != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              project.architecture!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.sagePrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProjectSegmentPill(String label, String group) {
    final isSelected = _selectedProjectGroup == group;
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (_selectedProjectGroup != group) {
          setState(() => _selectedProjectGroup = group);
        }
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: LIBRARY (Resources & Collections)
  // ==========================================
  Widget _buildLibraryTab(
    AsyncValue<List<LearningResource>> resourcesState,
    AsyncValue<List<LearningCollection>> collectionsState,
  ) {
    final theme = Theme.of(context);

    return resourcesState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading resources: $e')),
      data: (resources) {
        return collectionsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading folders: $e')),
          data: (collections) {
            // Apply category and folder filters
            final filteredResources = resources.where((res) {
              if (_filterCollectionId != null && res.collectionId != _filterCollectionId) {
                return false;
              }
              switch (_selectedLibraryCategoryIndex) {
                case 1: // YouTube Playlists & Videos
                  return res.isYouTube || res.type == ResourceType.video;
                case 2: // Courses
                  return res.type == ResourceType.course;
                case 3: // Articles
                  return res.type == ResourceType.article;
                default: // All Items
                  return true;
              }
            }).toList();

            final activeCollection = _filterCollectionId != null
                ? collections.where((c) => c.id == _filterCollectionId).firstOrNull
                : null;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(resourcesProvider);
                ref.invalidate(collectionsProvider);
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  // 1. Folders Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Folders & Collections',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${collections.length} ${collections.length == 1 ? 'folder' : 'folders'} • tap to filter',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => CollectionFormSheet.show(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Folder'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Folder Grid / Carousel
                  _buildFolderCarousel(collections),
                  const SizedBox(height: 18),

                  // 3. Category Filter Chips Bar
                  _buildCategoryFilterBar(resources.length),
                  const SizedBox(height: 10),

                  // Active Folder Banner (if filtered)
                  if (activeCollection != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _parseFolderColor(activeCollection.color).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _parseFolderColor(activeCollection.color).withValues(alpha: 0.8),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(activeCollection.iconData, size: 18, color: const Color(0xFF1B3623)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Filtering: ${activeCollection.title}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _filterCollectionId = null),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close_rounded, size: 14),
                                    SizedBox(width: 4),
                                    Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // 4. Resource Cards List
                  if (filteredResources.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: AreteEmptyState(
                        icon: Icons.video_library_outlined,
                        title: 'No Resources in Library',
                        description: activeCollection != null
                            ? 'No resources inside "${activeCollection.title}". Add YouTube videos, playlists, or courses!'
                            : 'Add YouTube videos, playlists, articles, or courses to organize your knowledge.',
                        actionLabel: 'Add Resource',
                        onAction: () => ResourceFormSheet.show(
                          context,
                          initialCollectionId: _filterCollectionId,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: filteredResources.map((res) {
                          return _buildResourceCard(res, collections);
                        }).toList(),
                      ),
                    ),

                  // Bottom padding clearance for FAB and navigation bar
                  const SizedBox(height: 120),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Folder Grid / Carousel ---
  Widget _buildFolderCarousel(List<LearningCollection> collections) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: collections.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == collections.length) {
            return _buildAddFolderCarouselCard();
          }
          final col = collections[index];
          return _buildFolderCard(col);
        },
      ),
    );
  }

  Widget _buildFolderCard(LearningCollection col) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _filterCollectionId == col.id;
    final baseColor = _parseFolderColor(col.color);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        setState(() {
          if (_filterCollectionId == col.id) {
            _filterCollectionId = null; // Deselect / toggle off
          } else {
            _filterCollectionId = col.id; // Filter by this folder
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2421) : baseColor.withValues(alpha: isSelected ? 0.45 : 0.28),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? Colors.white12 : baseColor.withValues(alpha: 0.8)),
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon Badge & Options
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : baseColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    col.iconData,
                    size: 20,
                    color: isDark ? Colors.white : const Color(0xFF1B3623),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Filtered',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) async {
                    if (val == 'add') {
                      ResourceFormSheet.show(context, initialCollectionId: col.id);
                    } else if (val == 'edit') {
                      CollectionFormSheet.show(context, collection: col);
                    } else if (val == 'delete') {
                      final confirmed = await AreteDialog.showConfirmation(
                        context: context,
                        title: 'Delete Folder',
                        message: 'Delete "${col.title}"? Resources inside will be unassigned to General Library.',
                        confirmLabel: 'Delete',
                        isDestructive: true,
                      );
                      if (confirmed == true) {
                        ref.read(collectionsProvider.notifier).deleteCollection(col.id);
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'add',
                      child: Row(
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Add Resource to Folder'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Folder'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Middle: Title & Summary
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  col.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  col.summaryText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFolderCarouselCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => CollectionFormSheet.show(context),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1E1C) : const Color(0xFFF4F1EA),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.create_new_folder_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '+ Add Folder',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Category Filter Chips Bar ---
  Widget _buildCategoryFilterBar(int totalCount) {
    final chips = [
      'All Items ($totalCount)',
      'YouTube Playlists & Videos',
      'Courses',
      'Articles',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: chips.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isSelected = _selectedLibraryCategoryIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              showCheckmark: false,
              avatar: idx == 1
                  ? const Icon(Icons.play_circle_fill_rounded, size: 16, color: Color(0xFFFF7A59))
                  : null,
              onSelected: (_) {
                setState(() => _selectedLibraryCategoryIndex = idx);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Resource Item Card (Material 3 Pastel with Direct YouTube Launch) ---
  Widget _buildResourceCard(
    LearningResource res,
    List<LearningCollection> collections,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = _getTypeColors(res.type, context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AreteCard(
        borderRadius: 24.0,
        backgroundColor: isDark ? const Color(0xFF1B201D) : const Color(0xFFFBFBF6),
        borderColor: isDark ? Colors.white12 : const Color(0xFFE2E0D8),
        padding: const EdgeInsets.all(14),
        onTap: () => _launchUrl(res.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. High-Res Thumbnail Preview (for YouTube videos or items with thumbnails)
            if (res.effectiveThumbnailUrl != null) ...[
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        res.effectiveThumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          final fallback = res.fallbackThumbnailUrl;
                          if (fallback != null) {
                            return Image.network(
                              fallback,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildCardThumbnailPlaceholder(theme),
                            );
                          }
                          return _buildCardThumbnailPlaceholder(theme);
                        },
                      ),
                    ),
                  ),

                  // Top-Left YouTube Badge
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
                            res.badgeTypeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Right External Launch Button (direct tap opens YouTube)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: () => _launchUrl(res.url),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_outward_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 3),
                            Text(
                              'Open App',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom-Right Duration Tag
                  if (res.duration != null && res.duration!.isNotEmpty)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              res.duration!,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 2. Title & Options
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    res.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) async {
                    if (val == 'launch') {
                      _launchUrl(res.url);
                    } else if (val == 'move') {
                      _showMoveToFolderSheet(context, res, collections);
                    } else if (val == 'edit') {
                      ResourceFormSheet.show(context, resource: res);
                    } else if (val == 'delete') {
                      final confirmed = await AreteDialog.showConfirmation(
                        context: context,
                        title: 'Delete Resource',
                        message: 'Are you sure you want to delete "${res.title}"?',
                        confirmLabel: 'Delete',
                        isDestructive: true,
                      );
                      if (confirmed == true) {
                        ref.read(resourcesProvider.notifier).deleteResource(res.id);
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'launch',
                      child: Row(
                        children: [
                          Icon(
                            res.isYouTube ? Icons.play_circle_fill_rounded : Icons.open_in_new_rounded,
                            size: 18,
                            color: res.isYouTube ? const Color(0xFFFF7A59) : null,
                          ),
                          const SizedBox(width: 8),
                          Text(res.isYouTube ? 'Open in YouTube App' : 'Open in Browser'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'move',
                      child: Row(
                        children: [
                          Icon(Icons.drive_file_move_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Move to Folder...'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (res.description != null && res.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                res.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // 3. Badges Row (Type, Duration, Folder)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    res.badgeTypeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.fg,
                      fontSize: 11,
                    ),
                  ),
                ),

                // Duration Badge (if non-thumbnail)
                if (res.duration != null && res.duration!.isNotEmpty && res.effectiveThumbnailUrl == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '⏱️ ${res.duration}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),

                // Folder Badge
                if (res.collectionTitle != null)
                  InkWell(
                    onTap: () {
                      setState(() => _filterCollectionId = res.collectionId);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2E8D4).withValues(alpha: isDark ? 0.25 : 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_outlined, size: 13, color: Color(0xFF1B3623)),
                          const SizedBox(width: 4),
                          Text(
                            res.collectionTitle!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1B3623),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // 4. Footer Row: Direct Launch Button & Status
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: res.status == ResourceStatus.completed
                        ? const Color(0xFFD2E8D4).withValues(alpha: 0.5)
                        : (res.status == ResourceStatus.inProgress
                            ? const Color(0xFFFFDDB3).withValues(alpha: 0.5)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    res.status.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: res.status == ResourceStatus.completed
                          ? const Color(0xFF1B3623)
                          : (res.status == ResourceStatus.inProgress
                              ? const Color(0xFF5A2D00)
                              : theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const Spacer(),
                // Direct Launch Tap Target
                InkWell(
                  onTap: () => _launchUrl(res.url),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          res.isYouTube ? 'Launch YouTube' : 'Launch Link',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: res.isYouTube ? const Color(0xFFFF7A59) : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 14,
                          color: res.isYouTube ? const Color(0xFFFF7A59) : theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardThumbnailPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 40,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  // --- Move to Folder Sheet ---
  void _showMoveToFolderSheet(
    BuildContext context,
    LearningResource resource,
    List<LearningCollection> collections,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: theme.colorScheme.outline, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Move to Folder',
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a target folder for "${resource.title}"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inbox_rounded, size: 18, color: Color(0xFF334155)),
                ),
                title: const Text('General Library (No Folder)'),
                trailing: resource.collectionId == null
                    ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                    : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  ref.read(resourcesProvider.notifier).moveResource(resource.id, null);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Moved to General Library')),
                  );
                },
              ),
              ...collections.map((col) {
                final isCurrent = resource.collectionId == col.id;
                final colColor = _parseFolderColor(col.color);

                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(col.iconData, size: 18, color: const Color(0xFF1B3623)),
                  ),
                  title: Text(col.title),
                  subtitle: Text(col.summaryText),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                      : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () {
                    ref.read(resourcesProvider.notifier).moveResource(resource.id, col.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Moved to "${col.title}"')),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Color _parseFolderColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFD2E8D4);
    try {
      final clean = hex.replaceFirst('#', '0xFF');
      return Color(int.parse(clean));
    } catch (_) {
      return const Color(0xFFD2E8D4);
    }
  }

  // ==========================================
  // TAB 4: SKILLS & PROFILE
  // ==========================================
  Widget _buildSkillsProfileTab(AsyncValue<dynamic> profileAsync) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        if (profile == null) {
          return AreteEmptyState(
            icon: Icons.person_outline_rounded,
            title: 'No Profile Found',
            description: 'Import the organized learning data to view your learning profile.',
            actionLabel: 'Import Data',
            onAction: () => LearningImportSheet.show(context),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Career Goal Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainer
                      : AppColors.sagePrimaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.sagePrimary.withValues(alpha: isDark ? 0.3 : 0.2),
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
                            color: AppColors.sagePrimary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CAREER DIRECTION',
                            style: TextStyle(
                              color: AppColors.sagePrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.careerTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.primaryGoal,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.sagePrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            profile.targetHorizon,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.sagePrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Known Skills
              Text(
                'Known & Practicing Skills',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (profile.knownSkills as List<String>).map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.surfaceContainer
                          : const Color(0xFFD2E8D4).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.sagePrimary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      skill,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.sagePrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Preferred Method: 20% Theory / 80% Practice
              Text(
                'Preferred Learning Method',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              AreteCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology_alt_rounded, color: Color(0xFFFF7A59)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            profile.learningStyle,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A59).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        profile.theoryPracticeRatio,
                        style: const TextStyle(
                          color: Color(0xFFFF7A59),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hackathon Rhythm
              Text(
                'Preferred Hackathon Rhythm',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              AreteCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  children: (profile.hackathonRhythm as List<String>).asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.sagePrimary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                color: AppColors.sagePrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e.value,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Workflow Steps
              Text(
                'First-Principles Workflow',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              AreteCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  children: (profile.learningWorkflow as List<String>).asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('0${e.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              e.value,
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
          ),
        );
      },
    );
  }
}
