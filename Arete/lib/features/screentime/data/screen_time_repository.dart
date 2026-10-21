import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../focus/data/focus_shield_service.dart';
import '../domain/app_category_model.dart';
import '../domain/screen_time_status_model.dart';

class ScreenTimeRepository {
  static const MethodChannel _channel = MethodChannel('com.arete.app/notifications_and_screentime');
  static const String _prefCategoriesKey = 'screen_time_app_categories_map';
  static const String _prefMonitoringKey = 'screen_time_monitoring_enabled';
  static const String _prefLimitKey = 'screen_time_distraction_limit';
  static const String _prefAutoShieldKey = 'screen_time_auto_shield';

  final SharedPreferences? _prefs;
  final FocusShieldService _shieldService;

  ScreenTimeRepository({
    SharedPreferences? prefs,
    FocusShieldService? shieldService,
  })  : _prefs = prefs,
        _shieldService = shieldService ?? FocusShieldService();

  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Check if Android Usage Access (PACKAGE_USAGE_STATS) permission is granted
  Future<bool> isUsageStatsPermissionGranted() async {
    if (!isAndroid) return true;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('isUsageStatsPermissionGranted');
      return granted ?? false;
    } catch (e) {
      debugPrint('ScreenTimeRepository: isUsageStatsPermissionGranted error: $e');
      return false;
    }
  }

  /// Open Android Usage Access Settings screen
  Future<bool> openUsageStatsSettings() async {
    if (!isAndroid) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openUsageStatsSettings');
      return ok ?? false;
    } catch (e) {
      debugPrint('ScreenTimeRepository: openUsageStatsSettings error: $e');
      return false;
    }
  }

  /// Start persistent screen time foreground tracking service
  Future<void> startScreenTimeMonitoring() async {
    await _prefs?.setBool(_prefMonitoringKey, true);
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('startScreenTimeMonitoring');
    } catch (e) {
      debugPrint('ScreenTimeRepository: startScreenTimeMonitoring error: $e');
    }
  }

  /// Stop persistent screen time service
  Future<void> stopScreenTimeMonitoring() async {
    await _prefs?.setBool(_prefMonitoringKey, false);
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('stopScreenTimeMonitoring');
    } catch (e) {
      debugPrint('ScreenTimeRepository: stopScreenTimeMonitoring error: $e');
    }
  }

  /// Query live screen time status from background service
  Future<ScreenTimeStatus> getScreenTimeStatus() async {
    if (!isAndroid) {
      final isMonitoring = _prefs?.getBool(_prefMonitoringKey) ?? false;
      return ScreenTimeStatus(
        totalScreenTimeMinutes: isMonitoring ? 135 : 0,
        currentPackage: 'com.arete.app.arete',
        currentAppName: 'Areté',
        currentAppMinutes: isMonitoring ? 28 : 0,
        category: AppCategory.productive,
        isMonitoring: isMonitoring,
        hasUsagePermission: true,
      );
    }

    try {
      final Map<dynamic, dynamic>? map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getScreenTimeStatus');
      if (map != null) {
        return ScreenTimeStatus.fromMap(map);
      }
    } catch (e) {
      debugPrint('ScreenTimeRepository: getScreenTimeStatus error: $e');
    }

    final isMonitoring = _prefs?.getBool(_prefMonitoringKey) ?? false;
    return ScreenTimeStatus(isMonitoring: isMonitoring);
  }

  /// Load all launchable apps with categorized status
  Future<List<MonitoredApp>> getMonitoredApps() async {
    final installedApps = await _shieldService.getInstalledApps();
    final categoriesMap = await getAppCategoriesMap();

    if (installedApps.isEmpty) {
      // Return representative demo apps when on non-android or no apps returned
      return _getDefaultDemoApps(categoriesMap);
    }

    return installedApps.map((app) {
      final customCatStr = categoriesMap[app.packageName];
      final category = customCatStr != null
          ? AppCategory.fromString(customCatStr)
          : classifyAppAutomatically(app.packageName, app.appName);

      return MonitoredApp(
        packageName: app.packageName,
        appName: app.appName,
        category: category,
        iconBytes: app.iconBytes,
        isSystemApp: app.isSystemApp,
      );
    }).toList();
  }

  /// Update single app category and sync to native preferences
  Future<void> setAppCategory(String packageName, AppCategory category) async {
    final map = await getAppCategoriesMap();
    map[packageName] = category.id;
    await _saveAppCategoriesMap(map);
  }

  /// Load stored categories map
  Future<Map<String, String>> getAppCategoriesMap() async {
    if (isAndroid) {
      try {
        final Map<dynamic, dynamic>? nativeMap = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppCategories');
        if (nativeMap != null && nativeMap.isNotEmpty) {
          return nativeMap.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (e) {
        debugPrint('ScreenTimeRepository: getAppCategories error: $e');
      }
    }

    final list = _prefs?.getStringList(_prefCategoriesKey) ?? [];
    final map = <String, String>{};
    for (final item in list) {
      final parts = item.split(':');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  Future<void> _saveAppCategoriesMap(Map<String, String> map) async {
    final list = map.entries.map((e) => '${e.key}:${e.value}').toList();
    await _prefs?.setStringList(_prefCategoriesKey, list);

    if (isAndroid) {
      try {
        await _channel.invokeMethod('updateAppCategories', {'categories': map});
      } catch (e) {
        debugPrint('ScreenTimeRepository: updateAppCategories error: $e');
      }
    }
  }

  /// Set distraction limit and auto-shield preference
  Future<void> setDistractionPreferences({
    required int limitMinutes,
    required bool autoShield,
  }) async {
    await _prefs?.setInt(_prefLimitKey, limitMinutes);
    await _prefs?.setBool(_prefAutoShieldKey, autoShield);

    if (isAndroid) {
      try {
        await _channel.invokeMethod('setDistractionPreferences', {
          'limitMinutes': limitMinutes,
          'autoShield': autoShield,
        });
      } catch (e) {
        debugPrint('ScreenTimeRepository: setDistractionPreferences error: $e');
      }
    }
  }

  /// Heuristic auto-classifier
  static AppCategory classifyAppAutomatically(String packageName, String appName) {
    final p = packageName.toLowerCase();
    final n = appName.toLowerCase();

    // Distractions
    if (p.contains('instagram') ||
        p.contains('tiktok') ||
        p.contains('musically') ||
        p.contains('facebook') ||
        p.contains('twitter') ||
        p.contains('reddit') ||
        p.contains('netflix') ||
        p.contains('twitch') ||
        p.contains('youtube') ||
        p.contains('snapchat') ||
        p.contains('clash') ||
        n.contains('instagram') ||
        n.contains('tiktok') ||
        n.contains('game') ||
        n.contains('reels')) {
      return AppCategory.distraction;
    }

    // Productive
    if (p.contains('notion') ||
        p.contains('coursera') ||
        p.contains('duolingo') ||
        p.contains('obsidian') ||
        p.contains('github') ||
        p.contains('books') ||
        p.contains('kindle') ||
        p.contains('linkedin') ||
        p.contains('todoist') ||
        p.contains('arete') ||
        n.contains('notion') ||
        n.contains('learn') ||
        n.contains('study') ||
        n.contains('books') ||
        n.contains('reader') ||
        n.contains('notes')) {
      return AppCategory.productive;
    }

    return AppCategory.neutral;
  }

  List<MonitoredApp> _getDefaultDemoApps(Map<String, String> categoriesMap) {
    final demo = [
      const MonitoredApp(
        packageName: 'com.arete.app.arete',
        appName: 'Areté Focus',
        category: AppCategory.productive,
        dailyScreenTimeMinutes: 45,
      ),
      const MonitoredApp(
        packageName: 'com.notion.id',
        appName: 'Notion',
        category: AppCategory.productive,
        dailyScreenTimeMinutes: 38,
      ),
      const MonitoredApp(
        packageName: 'org.coursera.android',
        appName: 'Coursera',
        category: AppCategory.productive,
        dailyScreenTimeMinutes: 25,
      ),
      const MonitoredApp(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        category: AppCategory.distraction,
        dailyScreenTimeMinutes: 42,
      ),
      const MonitoredApp(
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        category: AppCategory.distraction,
        dailyScreenTimeMinutes: 50,
      ),
      const MonitoredApp(
        packageName: 'com.reddit.frontpage',
        appName: 'Reddit',
        category: AppCategory.distraction,
        dailyScreenTimeMinutes: 30,
      ),
      const MonitoredApp(
        packageName: 'com.google.android.apps.messaging',
        appName: 'Messages',
        category: AppCategory.neutral,
        dailyScreenTimeMinutes: 15,
      ),
    ];

    return demo.map((app) {
      final custom = categoriesMap[app.packageName];
      if (custom != null) {
        return app.copyWith(category: AppCategory.fromString(custom));
      }
      return app;
    }).toList();
  }
}
