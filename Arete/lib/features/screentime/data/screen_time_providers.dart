import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../focus/data/focus_shield_service.dart';
import '../domain/app_category_model.dart';
import '../domain/screen_time_status_model.dart';
import 'screen_time_repository.dart';

final screenTimeRepositoryProvider = Provider<ScreenTimeRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ScreenTimeRepository(prefs: prefs, shieldService: FocusShieldService());
});

final screenTimeStatusProvider =
    StateNotifierProvider<ScreenTimeStatusNotifier, ScreenTimeStatus>((ref) {
  final repo = ref.watch(screenTimeRepositoryProvider);
  return ScreenTimeStatusNotifier(repo);
});

class ScreenTimeStatusNotifier extends StateNotifier<ScreenTimeStatus> {
  final ScreenTimeRepository _repo;
  Timer? _pollTimer;

  ScreenTimeStatusNotifier(this._repo) : super(const ScreenTimeStatus()) {
    refresh();
    _startPeriodicPolling();
  }

  void _startPeriodicPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refresh();
    });
  }

  Future<void> refresh() async {
    final status = await _repo.getScreenTimeStatus();
    if (mounted) {
      state = status;
    }
  }

  Future<void> startMonitoring() async {
    await _repo.startScreenTimeMonitoring();
    await refresh();
  }

  Future<void> stopMonitoring() async {
    await _repo.stopScreenTimeMonitoring();
    await refresh();
  }

  Future<bool> checkUsagePermission() async {
    final granted = await _repo.isUsageStatsPermissionGranted();
    if (mounted) {
      state = state.copyWith(hasUsagePermission: granted);
    }
    return granted;
  }

  Future<void> openSettings() async {
    await _repo.openUsageStatsSettings();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final monitoredAppsProvider =
    StateNotifierProvider<MonitoredAppsNotifier, AsyncValue<List<MonitoredApp>>>((ref) {
  final repo = ref.watch(screenTimeRepositoryProvider);
  return MonitoredAppsNotifier(repo);
});

class MonitoredAppsNotifier extends StateNotifier<AsyncValue<List<MonitoredApp>>> {
  final ScreenTimeRepository _repo;

  MonitoredAppsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadApps();
  }

  Future<void> loadApps() async {
    state = const AsyncValue.loading();
    try {
      final apps = await _repo.getMonitoredApps();
      state = AsyncValue.data(apps);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setCategory(String packageName, AppCategory newCategory) async {
    final currentList = state.valueOrNull;
    if (currentList == null) return;

    // Optimistically update
    final updated = currentList.map((app) {
      if (app.packageName == packageName) {
        return app.copyWith(category: newCategory);
      }
      return app;
    }).toList();

    state = AsyncValue.data(updated);
    await _repo.setAppCategory(packageName, newCategory);
  }
}
