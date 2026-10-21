import 'dart:typed_data';

class BlockedApp {
  final String packageName;
  final String appName;
  final Uint8List? iconBytes;
  final bool isBlocked;
  final bool isSystemApp;
  final DateTime? createdAt;

  const BlockedApp({
    required this.packageName,
    required this.appName,
    this.iconBytes,
    this.isBlocked = true,
    this.isSystemApp = false,
    this.createdAt,
  });

  BlockedApp copyWith({
    String? packageName,
    String? appName,
    Uint8List? iconBytes,
    bool? isBlocked,
    bool? isSystemApp,
    DateTime? createdAt,
  }) {
    return BlockedApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      iconBytes: iconBytes ?? this.iconBytes,
      isBlocked: isBlocked ?? this.isBlocked,
      isSystemApp: isSystemApp ?? this.isSystemApp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'package_name': packageName,
      'app_name': appName,
      'is_blocked': isBlocked ? 1 : 0,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory BlockedApp.fromMap(Map<String, dynamic> map, {Uint8List? icon}) {
    return BlockedApp(
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String,
      iconBytes: icon,
      isBlocked: (map['is_blocked'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
    );
  }

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return appName.toLowerCase().contains(q) || packageName.toLowerCase().contains(q);
  }
}
