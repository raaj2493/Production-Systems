import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/arete_button.dart';
import '../../../core/widgets/arete_card.dart';
import '../../../core/widgets/arete_empty_state.dart';
import 'focus_shield_controller.dart';
import 'focus_timer_controller.dart';

class AppBlockerSettingsScreen extends ConsumerStatefulWidget {
  const AppBlockerSettingsScreen({super.key});

  @override
  ConsumerState<AppBlockerSettingsScreen> createState() => _AppBlockerSettingsScreenState();
}

class _AppBlockerSettingsScreenState extends ConsumerState<AppBlockerSettingsScreen> with WidgetsBindingObserver {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check accessibility permission when user returns from Android Settings
      ref.read(focusShieldProvider.notifier).checkPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shieldState = ref.watch(focusShieldProvider);
    final timerState = ref.watch(focusTimerProvider);
    final isLocked = timerState.state == TimerState.running;
    final controller = ref.read(focusShieldProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Shield Apps'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${shieldState.selectedCount} Blocked',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 0. Active Session Lock Banner
          if (isLocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_clock, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Focus session active. App blocking configuration is locked until completion.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 1. Accessibility Service Disclosure & Setup Banner
          if (!shieldState.isAccessibilityGranted)
            AreteCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: theme.colorScheme.error, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Accessibility Permission Required',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Areté Focus Shield uses Android Accessibility to detect when distracting apps are opened during an active timer, keeping you in deep flow.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Privacy Commitment: Areté never reads screen content, keystrokes, personal messages, or passwords. Everything is processed strictly on-device.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AreteButton(
                    label: 'Enable in Android Settings',
                    icon: Icons.open_in_new,
                    variant: AreteButtonVariant.primary,
                    onPressed: () => controller.openAccessibilitySettings(),
                  ),
                ],
              ),
            )
          else
            AreteCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus Shield Service Active',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Distractions will be interrupted when focus begins.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // 2. Strict Mode Option Card
          AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.lock_clock_outlined, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Strict Commitment Mode',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Resists impulsive early cancellations with thoughtful exit barriers.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: shieldState.strictMode,
                  onChanged: isLocked ? null : (val) => controller.toggleStrictMode(val),
                  activeColor: theme.colorScheme.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Search Bar
          AreteCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search installed applications...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => controller.setSearchQuery(val),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      controller.setSearchQuery('');
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 4. Batch Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Apps to Block (${shieldState.filteredApps.length})',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: isLocked ? null : () => controller.selectAll(),
                    child: const Text('Select All'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: isLocked ? null : () => controller.deselectAll(),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ],
          ),

          // 5. App List
          if (shieldState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (shieldState.filteredApps.isEmpty)
            AreteEmptyState(
              icon: Icons.apps_outage_outlined,
              title: 'No Applications Found',
              description: shieldState.searchQuery.isNotEmpty
                  ? 'No installed applications match "${shieldState.searchQuery}".'
                  : 'No launchable applications available to block.',
            )
          else
            ...shieldState.filteredApps.map((app) {
              final isSelected = shieldState.selectedPackages.contains(app.packageName);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AreteCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: isLocked
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('App configuration is locked during an active session.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      : () => controller.togglePackage(app.packageName, app.appName),
                  child: Row(
                    children: [
                      // Native App Icon
                      if (app.iconBytes != null && app.iconBytes!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            app.iconBytes!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.android, color: theme.colorScheme.primary),
                        ),

                      const SizedBox(width: 14),

                      // App Name & Package Identifier
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.appName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.packageName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Checkbox
                      Checkbox.adaptive(
                        value: isSelected,
                        activeColor: theme.colorScheme.primary,
                        onChanged: isLocked
                            ? null
                            : (_) => controller.togglePackage(app.packageName, app.appName),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
