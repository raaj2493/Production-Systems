import 'package:flutter/foundation.dart';
import 'app_category_model.dart';

class AppUsageDetail {
  final String packageName;
  final String appName;
  final int minutes;
  final AppCategory category;
  final int launches;
  final Uint8List? iconBytes;

  const AppUsageDetail({
    required this.packageName,
    required this.appName,
    required this.minutes,
    required this.category,
    this.launches = 0,
    this.iconBytes,
  });

  String get formattedTime {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  factory AppUsageDetail.fromMap(Map<dynamic, dynamic> map, {Uint8List? iconBytes}) {
    return AppUsageDetail(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      minutes: (map['minutes'] as num?)?.toInt() ?? 0,
      category: AppCategory.fromString(map['category'] as String?),
      launches: (map['launches'] as num?)?.toInt() ?? 0,
      iconBytes: iconBytes,
    );
  }
}

class DigitalWellbeingStats {
  final int totalScreenTimeMinutes;
  final int productiveMinutes;
  final int distractionMinutes;
  final int neutralMinutes;
  final int deviceUnlockCount;
  final int notificationCount;
  final int shortFormBlockedCount;
  final bool isShortFormBlockingEnabled;
  final int remainingQuickPassSeconds;
  final String currentPackage;
  final String currentAppName;
  final List<AppUsageDetail> appDetails;

  const DigitalWellbeingStats({
    this.totalScreenTimeMinutes = 0,
    this.productiveMinutes = 0,
    this.distractionMinutes = 0,
    this.neutralMinutes = 0,
    this.deviceUnlockCount = 0,
    this.notificationCount = 0,
    this.shortFormBlockedCount = 0,
    this.isShortFormBlockingEnabled = true,
    this.remainingQuickPassSeconds = 0,
    this.currentPackage = '',
    this.currentAppName = '',
    this.appDetails = const [],
  });

  String get formattedTotalTime {
    final hours = totalScreenTimeMinutes ~/ 60;
    final mins = totalScreenTimeMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String get formattedProductiveTime {
    final hours = productiveMinutes ~/ 60;
    final mins = productiveMinutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  String get formattedDistractionTime {
    final hours = distractionMinutes ~/ 60;
    final mins = distractionMinutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  double get productivePercentage {
    if (totalScreenTimeMinutes == 0) return 0;
    return (productiveMinutes / totalScreenTimeMinutes).clamp(0.0, 1.0);
  }

  double get distractionPercentage {
    if (totalScreenTimeMinutes == 0) return 0;
    return (distractionMinutes / totalScreenTimeMinutes).clamp(0.0, 1.0);
  }

  double get neutralPercentage {
    if (totalScreenTimeMinutes == 0) return 0;
    return (neutralMinutes / totalScreenTimeMinutes).clamp(0.0, 1.0);
  }

  bool get isQuickPassActive => remainingQuickPassSeconds > 0;

  factory DigitalWellbeingStats.fromMap(Map<dynamic, dynamic> map, {Map<String, Uint8List?>? icons}) {
    final rawApps = (map['appDetails'] as List<dynamic>?) ?? [];
    final details = rawApps.map((e) {
      final m = Map<dynamic, dynamic>.from(e as Map);
      final pkg = m['packageName'] as String? ?? '';
      return AppUsageDetail.fromMap(m, iconBytes: icons?[pkg]);
    }).toList();

    return DigitalWellbeingStats(
      totalScreenTimeMinutes: (map['totalScreenTimeMinutes'] as num?)?.toInt() ?? 0,
      productiveMinutes: (map['productiveMinutes'] as num?)?.toInt() ?? 0,
      distractionMinutes: (map['distractionMinutes'] as num?)?.toInt() ?? 0,
      neutralMinutes: (map['neutralMinutes'] as num?)?.toInt() ?? 0,
      deviceUnlockCount: (map['deviceUnlockCount'] as num?)?.toInt() ?? 0,
      notificationCount: (map['notificationCount'] as num?)?.toInt() ?? 0,
      shortFormBlockedCount: (map['shortFormBlockedCount'] as num?)?.toInt() ?? 0,
      isShortFormBlockingEnabled: map['isShortFormBlockingEnabled'] as bool? ?? true,
      remainingQuickPassSeconds: (map['remainingQuickPassSeconds'] as num?)?.toInt() ?? 0,
      currentPackage: map['currentPackage'] as String? ?? '',
      currentAppName: map['currentAppName'] as String? ?? '',
      appDetails: details,
    );
  }
}
