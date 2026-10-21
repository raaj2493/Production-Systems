import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/blocked_app_model.dart';

class FocusShieldService {
  static const MethodChannel _channel = MethodChannel('com.arete.app/focus_shield');

  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Checks if Areté Focus Shield Accessibility Service is toggled ON in Android Settings
  Future<bool> isAccessibilityServiceEnabled() async {
    if (!isAndroid) return false;
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return enabled ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: isAccessibilityServiceEnabled error: $e');
      return false;
    }
  }

  /// Opens Android Accessibility Settings screen directly for the user
  Future<bool> openAccessibilitySettings() async {
    if (!isAndroid) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return ok ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: openAccessibilitySettings error: $e');
      return false;
    }
  }

  /// Queries all launchable installed user applications
  Future<List<BlockedApp>> getInstalledApps() async {
    if (!isAndroid) return [];
    try {
      final List<dynamic>? rawList = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (rawList == null) return [];

      return rawList.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final pkgName = map['packageName'] as String? ?? '';
        final appName = map['appName'] as String? ?? pkgName;
        final iconBytes = map['iconBytes'] as Uint8List?;
        final isSystem = map['isSystemApp'] as bool? ?? false;

        return BlockedApp(
          packageName: pkgName,
          appName: appName,
          iconBytes: iconBytes,
          isBlocked: false,
          isSystemApp: isSystem,
        );
      }).toList();
    } catch (e) {
      debugPrint('FocusShieldService: getInstalledApps error: $e');
      return [];
    }
  }

  /// Activates native Focus Shield with list of blocked packages and expected session end time
  Future<bool> startShield({
    required List<String> blockedPackages,
    required int endTimeMs,
    required bool strictMode,
    String? sessionLabel,
    String? sessionId,
  }) async {
    if (!isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('startShield', {
        'blockedPackages': blockedPackages,
        'endTimeMs': endTimeMs,
        'strictMode': strictMode,
        'sessionLabel': sessionLabel ?? 'Deep Focus Session',
        'sessionId': sessionId ?? '',
      });
      return success ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: startShield error: $e');
      return false;
    }
  }

  /// Deactivates Focus Shield and restores normal access
  Future<bool> stopShield() async {
    if (!isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('stopShield');
      return success ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: stopShield error: $e');
      return false;
    }
  }

  /// Pauses Focus Shield temporarily during breaks
  Future<bool> pauseShield() async {
    if (!isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('pauseShield');
      return success ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: pauseShield error: $e');
      return false;
    }
  }

  /// Resumes Focus Shield with updated target end time
  Future<bool> resumeShield({required int newEndTimeMs}) async {
    if (!isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('resumeShield', {
        'newEndTimeMs': newEndTimeMs,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: resumeShield error: $e');
      return false;
    }
  }

  /// Retrieves live native status including recorded distraction interruptions
  Future<Map<String, dynamic>> getShieldStatus() async {
    if (!isAndroid) {
      return {
        'isActive': false,
        'isServiceEnabled': false,
        'isStrictMode': false,
        'interruptionCount': 0,
        'blockedPackages': <String>[],
      };
    }
    try {
      final Map<dynamic, dynamic>? status = await _channel.invokeMethod<Map<dynamic, dynamic>>('getShieldStatus');
      if (status == null) return {};
      return Map<String, dynamic>.from(status);
    } catch (e) {
      debugPrint('FocusShieldService: getShieldStatus error: $e');
      return {};
    }
  }

  /// Resets the interruption counter on session start
  Future<int> resetInterruptionCount() async {
    if (!isAndroid) return 0;
    try {
      final int? count = await _channel.invokeMethod<int>('resetInterruptionCount');
      return count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

final focusShieldServiceProvider = Provider<FocusShieldService>((ref) {
  return FocusShieldService();
});
