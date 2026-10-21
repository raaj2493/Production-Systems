import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/blocked_apps_repository.dart';
import '../data/focus_shield_service.dart';
import '../domain/blocked_app_model.dart';

class FocusShieldState {
  final bool isShieldEnabled;
  final bool strictMode;
  final bool isAccessibilityGranted;
  final List<BlockedApp> installedApps;
  final Set<String> selectedPackages;
  final String searchQuery;
  final bool isLoading;
  final int liveInterruptionCount;

  const FocusShieldState({
    this.isShieldEnabled = false,
    this.strictMode = false,
    this.isAccessibilityGranted = false,
    this.installedApps = const [],
    this.selectedPackages = const {},
    this.searchQuery = '',
    this.isLoading = false,
    this.liveInterruptionCount = 0,
  });

  List<BlockedApp> get filteredApps {
    if (searchQuery.trim().isEmpty) {
      return installedApps;
    }
    final q = searchQuery.toLowerCase().trim();
    return installedApps.where((app) {
      return app.appName.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q);
    }).toList();
  }

  int get selectedCount => selectedPackages.length;

  FocusShieldState copyWith({
    bool? isShieldEnabled,
    bool? strictMode,
    bool? isAccessibilityGranted,
    List<BlockedApp>? installedApps,
    Set<String>? selectedPackages,
    String? searchQuery,
    bool? isLoading,
    int? liveInterruptionCount,
  }) {
    return FocusShieldState(
      isShieldEnabled: isShieldEnabled ?? this.isShieldEnabled,
      strictMode: strictMode ?? this.strictMode,
      isAccessibilityGranted: isAccessibilityGranted ?? this.isAccessibilityGranted,
      installedApps: installedApps ?? this.installedApps,
      selectedPackages: selectedPackages ?? this.selectedPackages,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      liveInterruptionCount: liveInterruptionCount ?? this.liveInterruptionCount,
    );
  }
}

class FocusShieldController extends StateNotifier<FocusShieldState> {
  final FocusShieldService _shieldService;
  final BlockedAppsRepository _repo;

  FocusShieldController(this._shieldService, this._repo)
      : super(const FocusShieldState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final isGranted = await _shieldService.isAccessibilityServiceEnabled();
    final savedBlocked = await _repo.getBlockedPackageNames();

    state = state.copyWith(
      isAccessibilityGranted: isGranted,
      selectedPackages: savedBlocked.toSet(),
      isShieldEnabled: savedBlocked.isNotEmpty,
      isLoading: false,
    );

    await loadInstalledApps();
  }

  Future<void> checkPermission() async {
    final isGranted = await _shieldService.isAccessibilityServiceEnabled();
    state = state.copyWith(isAccessibilityGranted: isGranted);
  }

  Future<void> openAccessibilitySettings() async {
    await _shieldService.openAccessibilitySettings();
  }

  Future<void> loadInstalledApps() async {
    state = state.copyWith(isLoading: true);
    final apps = await _shieldService.getInstalledApps();
    final isGranted = await _shieldService.isAccessibilityServiceEnabled();

    state = state.copyWith(
      installedApps: apps,
      isAccessibilityGranted: isGranted,
      isLoading: false,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleShieldEnabled(bool enabled) {
    state = state.copyWith(isShieldEnabled: enabled);
  }

  void toggleStrictMode(bool enabled) {
    state = state.copyWith(strictMode: enabled);
  }

  Future<void> togglePackage(String packageName, String appName) async {
    final updated = Set<String>.from(state.selectedPackages);
    final bool willBeBlocked;
    if (updated.contains(packageName)) {
      updated.remove(packageName);
      willBeBlocked = false;
    } else {
      updated.add(packageName);
      willBeBlocked = true;
    }

    state = state.copyWith(selectedPackages: updated);
    await _repo.setAppBlocked(packageName, appName, willBeBlocked);
  }

  Future<void> selectAll() async {
    final allPkgs = state.installedApps.map((a) => a.packageName).toSet();
    state = state.copyWith(selectedPackages: allPkgs);
    final names = {for (final a in state.installedApps) a.packageName: a.appName};
    await _repo.syncBlockedPackages(allPkgs, names);
  }

  Future<void> deselectAll() async {
    state = state.copyWith(selectedPackages: {});
    await _repo.syncBlockedPackages({}, {});
  }

  void updateInterruptionCount(int count) {
    state = state.copyWith(liveInterruptionCount: count);
  }
}

final focusShieldProvider = StateNotifierProvider<FocusShieldController, FocusShieldState>((ref) {
  final service = ref.watch(focusShieldServiceProvider);
  final repo = ref.watch(blockedAppsRepositoryProvider);
  return FocusShieldController(service, repo);
});
