import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';

final pipServiceProvider = Provider<PipService>((ref) {
  return PipService();
});

final pipModeProvider = StateNotifierProvider<PipModeNotifier, bool>((ref) {
  return PipModeNotifier(ref.watch(pipServiceProvider));
});

/// Service controlling the Native Android WindowManager Floating Overlay Pill.
class PipService {
  static const MethodChannel _channel = MethodChannel('com.arete.app/pip');

  PipService();

  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isPipSupported() async {
    if (!isAndroid) return false;
    try {
      final bool? supported = await _channel.invokeMethod<bool>('isOverlaySupported');
      return supported ?? false;
    } catch (e) {
      debugPrint('PipService: isPipSupported error: $e');
      return false;
    }
  }

  Future<bool> hasOverlayPermission() async {
    if (!isAndroid) return false;
    try {
      final bool? hasPerm = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return hasPerm ?? false;
    } catch (e) {
      debugPrint('PipService: hasOverlayPermission error: $e');
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('PipService: requestOverlayPermission error: $e');
    }
  }

  Future<bool> isPipMode() async {
    if (!isAndroid) return false;
    try {
      final bool? inPip = await _channel.invokeMethod<bool>('isPipMode');
      return inPip ?? false;
    } catch (e) {
      debugPrint('PipService: isPipMode error: $e');
      return false;
    }
  }

  Future<bool> enterPip({
    int? remainingSeconds,
    int? totalSeconds,
    bool? isRunning,
    bool? isBreak,
  }) async {
    if (!isAndroid) return false;
    try {
      final bool? ok = await _channel.invokeMethod<bool>('showOverlay', {
        if (remainingSeconds != null) 'remainingSeconds': remainingSeconds,
        if (totalSeconds != null) 'totalSeconds': totalSeconds,
        if (isRunning != null) 'isRunning': isRunning,
        if (isBreak != null) 'isBreak': isBreak,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('PipService: enterPip error: $e');
      return false;
    }
  }

  Future<void> updateOverlay({
    required int remainingSeconds,
    int? totalSeconds,
    required bool isRunning,
    required bool isBreak,
  }) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('updateOverlay', {
        'remainingSeconds': remainingSeconds,
        if (totalSeconds != null) 'totalSeconds': totalSeconds,
        'isRunning': isRunning,
        'isBreak': isBreak,
      });
    } catch (e) {
      debugPrint('PipService: updateOverlay error: $e');
    }
  }

  Future<void> setAutoEnterEnabled(bool enabled) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('setAutoEnterEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('PipService: setAutoEnterEnabled error: $e');
    }
  }

  Future<void> exitPip() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('exitPip');
    } catch (e) {
      debugPrint('PipService: exitPip error: $e');
    }
  }

  void setPipModeHandler(void Function(bool inPip) onPipChanged, [void Function(String action)? onAction]) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final inPip = call.arguments as bool? ?? false;
        onPipChanged(inPip);
      } else if (call.method == 'onOverlayAction') {
        final action = call.arguments as String? ?? '';
        if (action == 'open_focus_view') {
          try {
            appRouter.go('/focus');
          } catch (e) {
            debugPrint('PipService: go to /focus error: $e');
          }
        }
        onAction?.call(action);
      }
    });
  }
}

class PipModeNotifier extends StateNotifier<bool> {
  final PipService _service;

  PipModeNotifier(this._service) : super(false) {
    _init();
  }

  Future<void> _init() async {
    _service.setPipModeHandler((inPip) {
      if (mounted) {
        state = inPip;
      }
    });
    final current = await _service.isPipMode();
    if (mounted) {
      state = current;
    }
  }

  void setPipMode(bool inPip) {
    state = inPip;
  }
}
