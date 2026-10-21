import 'dart:typed_data';

enum AppCategory {
  productive,
  neutral,
  distraction;

  String get id {
    switch (this) {
      case AppCategory.productive:
        return 'productive';
      case AppCategory.distraction:
        return 'distraction';
      case AppCategory.neutral:
        return 'neutral';
    }
  }

  String get label {
    switch (this) {
      case AppCategory.productive:
        return 'Productive';
      case AppCategory.distraction:
        return 'Distraction';
      case AppCategory.neutral:
        return 'Neutral';
    }
  }

  static AppCategory fromString(String? val) {
    if (val == null) return AppCategory.neutral;
    switch (val.toLowerCase().trim()) {
      case 'productive':
        return AppCategory.productive;
      case 'distraction':
        return AppCategory.distraction;
      default:
        return AppCategory.neutral;
    }
  }
}

class MonitoredApp {
  final String packageName;
  final String appName;
  final AppCategory category;
  final int dailyScreenTimeMinutes;
  final Uint8List? iconBytes;
  final bool isSystemApp;

  const MonitoredApp({
    required this.packageName,
    required this.appName,
    this.category = AppCategory.neutral,
    this.dailyScreenTimeMinutes = 0,
    this.iconBytes,
    this.isSystemApp = false,
  });

  MonitoredApp copyWith({
    String? packageName,
    String? appName,
    AppCategory? category,
    int? dailyScreenTimeMinutes,
    Uint8List? iconBytes,
    bool? isSystemApp,
  }) {
    return MonitoredApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      category: category ?? this.category,
      dailyScreenTimeMinutes: dailyScreenTimeMinutes ?? this.dailyScreenTimeMinutes,
      iconBytes: iconBytes ?? this.iconBytes,
      isSystemApp: isSystemApp ?? this.isSystemApp,
    );
  }

  String get formattedScreenTime {
    if (dailyScreenTimeMinutes <= 0) return '0m';
    final hours = dailyScreenTimeMinutes ~/ 60;
    final mins = dailyScreenTimeMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }
}
