import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_bottom_sheet.dart';
import '../../../core/widgets/arete_card.dart';
import '../data/screen_time_providers.dart';
import '../domain/app_category_model.dart';

class AppCategorizationSheet extends ConsumerStatefulWidget {
  const AppCategorizationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AreteBottomSheet.show(
      context: context,
      title: 'App Productivity Classification',
      child: const AppCategorizationSheet(),
    );
  }

  @override
  ConsumerState<AppCategorizationSheet> createState() => _AppCategorizationSheetState();
}

class _AppCategorizationSheetState extends ConsumerState<AppCategorizationSheet> {
  final TextEditingController _searchController = TextEditingController();
  AppCategory? _filterCategory; // null = all

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appsAsync = ref.watch(monitoredAppsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtitle explanation
        Text(
          'Classify installed apps as Productive, Neutral, or Distraction. The persistent screen time monitor dynamically adjusts alerts and Focus Shield limits based on these categories.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Search Bar
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search installed applications...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(context, 'All', null),
              const SizedBox(width: 8),
              _buildFilterChip(context, '🎯 Productive', AppCategory.productive),
              const SizedBox(width: 8),
              _buildFilterChip(context, '⚠️ Distraction', AppCategory.distraction),
              const SizedBox(width: 8),
              _buildFilterChip(context, '⚪ Neutral', AppCategory.neutral),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Apps List
        appsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Unable to load applications: $err'),
            ),
          ),
          data: (apps) {
            final query = _searchController.text.toLowerCase().trim();
            final filtered = apps.where((app) {
              final matchesQuery = query.isEmpty ||
                  app.appName.toLowerCase().contains(query) ||
                  app.packageName.toLowerCase().contains(query);
              final matchesFilter = _filterCategory == null || app.category == _filterCategory;
              return matchesQuery && matchesFilter;
            }).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 40, color: theme.colorScheme.outline),
                      const SizedBox(height: 8),
                      Text(
                        'No matching apps found',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final app = filtered[index];
                return _buildAppItemCard(context, app);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, AppCategory? category) {
    final theme = Theme.of(context);
    final isSelected = _filterCategory == category;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selected: isSelected,
      selectedColor: theme.colorScheme.primary,
      onSelected: (_) {
        setState(() {
          _filterCategory = category;
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildAppItemCard(BuildContext context, MonitoredApp app) {
    final theme = Theme.of(context);

    // Segment colors
    Color categoryBg;
    Color categoryColor;
    switch (app.category) {
      case AppCategory.productive:
        categoryBg = AppColors.sagePrimaryContainer;
        categoryColor = AppColors.sageOnPrimaryContainer;
        break;
      case AppCategory.distraction:
        categoryBg = const Color(0xFFFFDDB3);
        categoryColor = const Color(0xFFC04E00);
        break;
      case AppCategory.neutral:
        categoryBg = theme.colorScheme.surfaceContainerHighest;
        categoryColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return AreteCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon or Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: categoryBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: app.iconBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          app.iconBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildLetterAvatar(app),
                        ),
                      )
                    : _buildLetterAvatar(app),
              ),
              const SizedBox(width: 12),
              // App Name & Package
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      app.packageName,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Daily usage badge if recorded
              if (app.dailyScreenTimeMinutes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: categoryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    app.formattedScreenTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // 3-way Category Pill Selector
          Row(
            children: [
              Expanded(
                child: _buildCategorySegmentButton(
                  context,
                  app,
                  AppCategory.productive,
                  '🎯 Productive',
                  AppColors.sagePrimaryContainer,
                  AppColors.sageOnPrimaryContainer,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCategorySegmentButton(
                  context,
                  app,
                  AppCategory.neutral,
                  '⚪ Neutral',
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCategorySegmentButton(
                  context,
                  app,
                  AppCategory.distraction,
                  '⚠️ Distraction',
                  const Color(0xFFFFDDB3),
                  const Color(0xFFC04E00),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySegmentButton(
    BuildContext context,
    MonitoredApp app,
    AppCategory category,
    String label,
    Color activeBg,
    Color activeTextColor,
  ) {
    final isSelected = app.category == category;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        ref.read(monitoredAppsProvider.notifier).setCategory(app.packageName, category);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeTextColor.withValues(alpha: 0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? activeTextColor : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildLetterAvatar(MonitoredApp app) {
    final initial = app.appName.isNotEmpty ? app.appName[0].toUpperCase() : 'A';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
