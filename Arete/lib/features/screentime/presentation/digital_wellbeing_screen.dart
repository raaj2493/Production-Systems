import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/arete_card.dart';
import '../data/screen_time_providers.dart';
import '../domain/app_category_model.dart';
import '../domain/digital_wellbeing_model.dart';
import 'app_categorization_sheet.dart';

class DigitalWellbeingScreen extends ConsumerStatefulWidget {
  const DigitalWellbeingScreen({super.key});

  @override
  ConsumerState<DigitalWellbeingScreen> createState() => _DigitalWellbeingScreenState();
}

class _DigitalWellbeingScreenState extends ConsumerState<DigitalWellbeingScreen> {
  AppCategory? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(digitalWellbeingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Digital Wellbeing',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'App Categories',
            onPressed: () => AppCategorizationSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Stats',
            onPressed: () {
              ref.read(digitalWellbeingProvider.notifier).refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing Digital Wellbeing statistics...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Could not load Wellbeing stats', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(err.toString(), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.read(digitalWellbeingProvider.notifier).refresh(),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          final maxMinutes = stats.appDetails.isNotEmpty ? stats.appDetails.first.minutes : 1;
          final filteredApps = _selectedFilter == null
              ? stats.appDetails
              : stats.appDetails.where((a) => a.category == _selectedFilter).toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(digitalWellbeingProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Total Screen Time & Category Segments Card
                _buildScreenTimeOverview(context, stats),
                const SizedBox(height: 16),

                // 2. Android Phone Metrics (Unlocks, Notifications, Distractions)
                _buildPhoneMetricsRow(context, stats),
                const SizedBox(height: 20),

                // 4. App Breakdown Header & Filter Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'App Usage Breakdown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${stats.appDetails.length} Apps active',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildFilterChips(context),
                const SizedBox(height: 12),

                // 5. App List
                if (filteredApps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        'No applications in this category today',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...filteredApps.map((app) => _buildAppRow(context, app, maxMinutes)),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScreenTimeOverview(BuildContext context, DigitalWellbeingStats stats) {
    final theme = Theme.of(context);

    return AreteCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TODAY\'S SCREEN TIME',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Phone Synced',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stats.formattedTotalTime,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),

          // Multi-Segment Usage Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (stats.productivePercentage > 0)
                    Expanded(
                      flex: (stats.productivePercentage * 100).round().clamp(1, 100),
                      child: Container(color: AppColors.statusGreen),
                    ),
                  if (stats.distractionPercentage > 0)
                    Expanded(
                      flex: (stats.distractionPercentage * 100).round().clamp(1, 100),
                      child: Container(color: AppColors.statusRed),
                    ),
                  if (stats.neutralPercentage > 0)
                    Expanded(
                      flex: (stats.neutralPercentage * 100).round().clamp(1, 100),
                      child: Container(color: theme.colorScheme.outlineVariant),
                    ),
                  if (stats.totalScreenTimeMinutes == 0)
                    Expanded(
                      child: Container(color: theme.colorScheme.surfaceContainerHighest),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(
                label: 'Productive',
                time: stats.formattedProductiveTime,
                color: AppColors.statusGreen,
              ),
              _buildLegendItem(
                label: 'Distraction',
                time: stats.formattedDistractionTime,
                color: AppColors.statusRed,
              ),
              _buildLegendItem(
                label: 'Neutral',
                time: '${stats.neutralMinutes}m',
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required String time,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneMetricsRow(BuildContext context, DigitalWellbeingStats stats) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_open_rounded, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Unlocks',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${stats.deviceUnlockCount}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'device pickups',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      'Alerts',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${stats.notificationCount}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'notifications',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: AppColors.statusGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Distraction',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${stats.distractionMinutes}m',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'screen time',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Apps'),
            selected: _selectedFilter == null,
            onSelected: (_) => setState(() => _selectedFilter = null),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Distractions'),
            selected: _selectedFilter == AppCategory.distraction,
            onSelected: (_) => setState(() => _selectedFilter = AppCategory.distraction),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Productive'),
            selected: _selectedFilter == AppCategory.productive,
            onSelected: (_) => setState(() => _selectedFilter = AppCategory.productive),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Neutral'),
            selected: _selectedFilter == AppCategory.neutral,
            onSelected: (_) => setState(() => _selectedFilter = AppCategory.neutral),
          ),
        ],
      ),
    );
  }

  Widget _buildAppRow(BuildContext context, AppUsageDetail app, int maxMinutes) {
    final theme = Theme.of(context);
    final ratio = (app.minutes / maxMinutes).clamp(0.02, 1.0);

    Color catColor;
    switch (app.category) {
      case AppCategory.productive:
        catColor = AppColors.statusGreen;
        break;
      case AppCategory.distraction:
        catColor = AppColors.statusRed;
        break;
      case AppCategory.neutral:
        catColor = theme.colorScheme.outlineVariant;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // App Icon or initial
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: app.iconBytes != null
                ? Image.memory(app.iconBytes!, width: 38, height: 38, fit: BoxFit.cover)
                : Container(
                    width: 38,
                    height: 38,
                    color: theme.colorScheme.primaryContainer,
                    child: Center(
                      child: Text(
                        app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Title & Progress Bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        app.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    Text(
                      app.formattedTime,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(catColor),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${app.launches} opens today',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        // Cycle category on tap
                        final nextCat = app.category == AppCategory.distraction
                            ? AppCategory.productive
                            : (app.category == AppCategory.productive
                                ? AppCategory.neutral
                                : AppCategory.distraction);
                        ref.read(monitoredAppsProvider.notifier).setCategory(app.packageName, nextCat);
                        ref.read(digitalWellbeingProvider.notifier).refresh(silent: true);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          app.category.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
