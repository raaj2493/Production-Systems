import 'app_category_model.dart';

class ScreenTimeStatus {
  final int totalScreenTimeMinutes;
  final String currentPackage;
  final String currentAppName;
  final int currentAppMinutes;
  final AppCategory category;
  final bool isMonitoring;
  final bool hasUsagePermission;

  const ScreenTimeStatus({
    this.totalScreenTimeMinutes = 0,
    this.currentPackage = '',
    this.currentAppName = '',
    this.currentAppMinutes = 0,
    this.category = AppCategory.neutral,
    this.isMonitoring = false,
    this.hasUsagePermission = false,
  });

  String get formattedTotalScreenTime {
    final hours = totalScreenTimeMinutes ~/ 60;
    final mins = totalScreenTimeMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String get formattedCurrentAppTime {
    final hours = currentAppMinutes ~/ 60;
    final mins = currentAppMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  bool get isDistractionAlert => category == AppCategory.distraction && currentAppMinutes >= 20;

  ScreenTimeStatus copyWith({
    int? totalScreenTimeMinutes,
    String? currentPackage,
    String? currentAppName,
    int? currentAppMinutes,
    AppCategory? category,
    bool? isMonitoring,
    bool? hasUsagePermission,
  }) {
    return ScreenTimeStatus(
      totalScreenTimeMinutes: totalScreenTimeMinutes ?? this.totalScreenTimeMinutes,
      currentPackage: currentPackage ?? this.currentPackage,
      currentAppName: currentAppName ?? this.currentAppName,
      currentAppMinutes: currentAppMinutes ?? this.currentAppMinutes,
      category: category ?? this.category,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      hasUsagePermission: hasUsagePermission ?? this.hasUsagePermission,
    );
  }

  factory ScreenTimeStatus.fromMap(Map<dynamic, dynamic> map) {
    return ScreenTimeStatus(
      totalScreenTimeMinutes: (map['totalScreenTimeMinutes'] as num?)?.toInt() ?? 0,
      currentPackage: map['currentPackage'] as String? ?? '',
      currentAppName: map['currentAppName'] as String? ?? '',
      currentAppMinutes: (map['currentAppMinutes'] as num?)?.toInt() ?? 0,
      category: AppCategory.fromString(map['category'] as String?),
      isMonitoring: map['isMonitoring'] as bool? ?? false,
      hasUsagePermission: map['hasUsagePermission'] as bool? ?? false,
    );
  }
}
