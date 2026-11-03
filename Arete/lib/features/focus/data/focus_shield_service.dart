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

  Future<bool> isXiaomiDevice() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isXiaomiDevice') ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: isXiaomiDevice error: $e');
      return false;
    }
  }

  Future<bool> openXiaomiAutostartSettings() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openXiaomiAutostartSettings') ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: openXiaomiAutostartSettings error: $e');
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

  /// Updates blocked packages set in native SharedPreferences
  Future<bool> setBlockedPackages(List<String> blockedPackages) async {
    if (!isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod<bool>('setBlockedPackages', {
        'blockedPackages': blockedPackages,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('FocusShieldService: setBlockedPackages error: $e');
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

  /// Check whether YouTube Shorts and Instagram Reels blocking is toggled ON
  Future<bool> isShortFormBlockingEnabled() async {
    if (!isAndroid) return true;
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isShortFormBlockingEnabled');
      return enabled ?? true;
    } catch (e) {
      debugPrint('FocusShieldService: isShortFormBlockingEnabled error: $e');
      return true;
    }
  }

  /// Toggle YouTube Shorts and Instagram Reels blocking
  Future<void> setShortFormBlockingEnabled(bool enabled) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('setShortFormBlockingEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('FocusShieldService: setShortFormBlockingEnabled error: $e');
    }
  }

  /// Get Quick Pass status and remaining seconds
  Future<Map<String, dynamic>> getQuickPassStatus() async {
    if (!isAndroid) return {'isGranted': false, 'remainingSeconds': 0, 'blockedCount': 0};
    try {
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getQuickPassStatus');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('FocusShieldService: getQuickPassStatus error: $e');
    }
    return {'isGranted': false, 'remainingSeconds': 0, 'blockedCount': 0};
  }

  /// Grant a temporary Quick Pass for short form viewing (e.g. 2, 5, 10 minutes)
  Future<void> grantQuickPass(int minutes) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('grantQuickPass', {'minutes': minutes});
    } catch (e) {
      debugPrint('FocusShieldService: grantQuickPass error: $e');
    }
  }

  /// Revoke Quick Pass immediately
  Future<void> clearQuickPass() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('clearQuickPass');
    } catch (e) {
      debugPrint('FocusShieldService: clearQuickPass error: $e');
    }
  }

  /// Play ambient sound (rain, white_noise, binaural, etc.)
  Future<void> playAmbientSound(String type, double volume) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('playAmbientSound', {'type': type, 'volume': volume});
    } catch (e) {
      debugPrint('FocusShieldService: playAmbientSound error: $e');
    }
  }

  /// Play custom user selected local music
  Future<void> playCustomMusic(String filePath, double volume) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('playCustomMusic', {'filePath': filePath, 'volume': volume});
    } catch (e) {
      debugPrint('FocusShieldService: playCustomMusic error: $e');
    }
  }

  /// Stop ambient or custom music
  Future<void> stopAmbientSound() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('stopAmbientSound');
    } catch (e) {
      debugPrint('FocusShieldService: stopAmbientSound error: $e');
    }
  }

  /// Adjust ambient sound volume
  Future<void> setAmbientVolume(double volume) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('setAmbientVolume', {'volume': volume});
    } catch (e) {
      debugPrint('FocusShieldService: setAmbientVolume error: $e');
    }
  }
}

final focusShieldServiceProvider = Provider<FocusShieldService>((ref) {
  return FocusShieldService();
});
