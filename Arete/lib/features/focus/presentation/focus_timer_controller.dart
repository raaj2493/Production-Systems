import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../data/focus_repository.dart';
import '../data/focus_shield_service.dart';
import '../data/pip_service.dart';
import '../domain/focus_session_model.dart';
import 'focus_shield_controller.dart';
import '../../notifications/data/notification_providers.dart';

enum TimerState { idle, running, paused, completed }

class FocusTimerState {
  final TimerState state;
  final FocusSessionType sessionType;
  final int totalSeconds;
  final int remainingSeconds;
  final String? linkedTaskId;
  final String? linkedGoalId;
  final DateTime? startedAt;
  final int completedCycles; // 0 to 4 completed focus sessions in current block
  final bool isZenMode; // Fullscreen immersive Zen overlay active
  final bool autoStartNextPhase;

  const FocusTimerState({
    this.state = TimerState.idle,
    this.sessionType = FocusSessionType.focus,
    this.totalSeconds = 25 * 60,
    this.remainingSeconds = 25 * 60,
    this.linkedTaskId,
    this.linkedGoalId,
    this.startedAt,
    this.completedCycles = 0,
    this.isZenMode = false,
    this.autoStartNextPhase = false,
  });

  /// Remaining ratio for countdown ring (starts at 1.0, depletes to 0.0 as timer gets over)
  double get remainingRatio => totalSeconds > 0
      ? (remainingSeconds / totalSeconds).clamp(0.0, 1.0)
      : 0.0;

  /// Elapsed ratio (starts at 0.0, reaches 1.0 at completion)
  double get elapsedRatio => totalSeconds > 0
      ? ((totalSeconds - remainingSeconds) / totalSeconds).clamp(0.0, 1.0)
      : 0.0;

  double get progressRatio => remainingRatio;

  FocusTimerState copyWith({
    TimerState? state,
    FocusSessionType? sessionType,
    int? totalSeconds,
    int? remainingSeconds,
    String? linkedTaskId,
    String? linkedGoalId,
    DateTime? startedAt,
    int? completedCycles,
    bool? isZenMode,
    bool? autoStartNextPhase,
  }) {
    return FocusTimerState(
      state: state ?? this.state,
      sessionType: sessionType ?? this.sessionType,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      startedAt: startedAt ?? this.startedAt,
      completedCycles: completedCycles ?? this.completedCycles,
      isZenMode: isZenMode ?? this.isZenMode,
      autoStartNextPhase: autoStartNextPhase ?? this.autoStartNextPhase,
    );
  }
}

class FocusTimerController extends StateNotifier<FocusTimerState> {
  static const _keyTimerState = 'focus_timer_state';
  static const _keySessionType = 'focus_session_type';
  static const _keyTargetEndMs = 'focus_target_end_ms';
  static const _keyRemainingSeconds = 'focus_remaining_seconds';
  static const _keyTotalSeconds = 'focus_total_seconds';
  static const _keyLinkedTaskId = 'focus_linked_task_id';
  static const _keyLinkedGoalId = 'focus_linked_goal_id';
  static const _keyStartedAt = 'focus_started_at';
  static const _keyCompletedCycles = 'focus_completed_cycles';
  static const _keyAutoStart = 'focus_auto_start_next_phase';

  final Ref _ref;
  Timer? _ticker;

  FocusTimerController(this._ref) : super(const FocusTimerState()) {
    _initFromPreferences();
    try {
      _ref.read(pipServiceProvider).setPipModeHandler((_) {}, (action) {
        if (action == 'pause') {
          pause();
        } else if (action == 'resume') {
          resume();
        }
      });
    } catch (_) {}
  }

  SharedPreferences? get _prefs => _ref.read(sharedPreferencesProvider);
  AppSettings get _settings => _ref.read(appSettingsProvider);

  int _getDurationForType(FocusSessionType type) {
    switch (type) {
      case FocusSessionType.focus:
        return _settings.defaultFocusMinutes * 60;
      case FocusSessionType.shortBreak:
        return _settings.defaultShortBreakMinutes * 60;
      case FocusSessionType.longBreak:
        return _settings.defaultLongBreakMinutes * 60;
    }
  }

  Future<void> _initFromPreferences() async {
    final prefs = _prefs;
    final defaultSec = _getDurationForType(FocusSessionType.focus);

    if (prefs == null) {
      state = state.copyWith(
        totalSeconds: defaultSec,
        remainingSeconds: defaultSec,
      );
      return;
    }

    final savedStateStr = prefs.getString(_keyTimerState);
    final savedTypeStr = prefs.getString(_keySessionType);
    final sessionType = savedTypeStr != null
        ? FocusSessionType.fromString(savedTypeStr)
        : FocusSessionType.focus;

    final totalSeconds = prefs.getInt(_keyTotalSeconds) ?? _getDurationForType(sessionType);
    final taskId = prefs.getString(_keyLinkedTaskId);
    final goalId = prefs.getString(_keyLinkedGoalId);
    final startedAtStr = prefs.getString(_keyStartedAt);
    final startedAt = startedAtStr != null ? DateTime.tryParse(startedAtStr) : null;
    final completedCycles = prefs.getInt(_keyCompletedCycles) ?? 0;
    final autoStart = prefs.getBool(_keyAutoStart) ?? false;

    if (savedStateStr == 'running') {
      final targetEndMs = prefs.getInt(_keyTargetEndMs) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (nowMs >= targetEndMs) {
        // Session finished while app was in background or closed!
        final duration = totalSeconds;
        await _logCompletedSession(
          sessionType: sessionType,
          durationSeconds: duration,
          completedSeconds: duration,
          startedAt: startedAt ?? DateTime.now().subtract(Duration(seconds: duration)),
          taskId: taskId,
          goalId: goalId,
        );

        final nextType = sessionType == FocusSessionType.focus
            ? (completedCycles + 1 >= 4 ? FocusSessionType.longBreak : FocusSessionType.shortBreak)
            : FocusSessionType.focus;
        final nextSec = _getDurationForType(nextType);
        final newCycles = sessionType == FocusSessionType.focus
            ? (completedCycles + 1 >= 4 ? 0 : completedCycles + 1)
            : completedCycles;

        state = FocusTimerState(
          state: TimerState.completed,
          sessionType: nextType,
          totalSeconds: nextSec,
          remainingSeconds: nextSec,
          completedCycles: newCycles,
          autoStartNextPhase: autoStart,
        );
        await prefs.setInt(_keyCompletedCycles, newCycles);
        await _clearPersistedState();
      } else {
        // Resume seamlessly from exact remaining seconds
        final remaining = ((targetEndMs - nowMs) / 1000).ceil();
        state = FocusTimerState(
          state: TimerState.running,
          sessionType: sessionType,
          totalSeconds: totalSeconds,
          remainingSeconds: remaining,
          linkedTaskId: taskId,
          linkedGoalId: goalId,
          startedAt: startedAt,
          completedCycles: completedCycles,
          autoStartNextPhase: autoStart,
        );
        _startTicker();
        _syncNotification(isRunning: true);
        _ref.read(pipServiceProvider).setAutoEnterEnabled(true);
      }
    } else if (savedStateStr == 'paused') {
      final remaining = prefs.getInt(_keyRemainingSeconds) ?? totalSeconds;
      state = FocusTimerState(
        state: TimerState.paused,
        sessionType: sessionType,
        totalSeconds: totalSeconds,
        remainingSeconds: remaining,
        linkedTaskId: taskId,
        linkedGoalId: goalId,
        startedAt: startedAt,
        completedCycles: completedCycles,
        autoStartNextPhase: autoStart,
      );
    } else {
      state = FocusTimerState(
        state: TimerState.idle,
        sessionType: sessionType,
        totalSeconds: totalSeconds,
        remainingSeconds: totalSeconds,
        linkedTaskId: taskId,
        linkedGoalId: goalId,
        completedCycles: completedCycles,
        autoStartNextPhase: autoStart,
      );
    }
  }

  void openZenMode() => toggleZenMode(true);
  void closeZenMode() => toggleZenMode(false);

  void toggleZenMode([bool? forceState]) {
    state = state.copyWith(isZenMode: forceState ?? !state.isZenMode);
  }

  void toggleAutoStart([bool? value]) {
    final next = value ?? !state.autoStartNextPhase;
    state = state.copyWith(autoStartNextPhase: next);
    _prefs?.setBool(_keyAutoStart, next);
  }

  Future<void> selectSessionType(FocusSessionType type) async {
    if (state.state == TimerState.running) return;
    _ticker?.cancel();

    // If changing away from a focus session that had accumulated time, log it
    if (state.sessionType == FocusSessionType.focus && type != FocusSessionType.focus) {
      final elapsedSeconds = state.totalSeconds - state.remainingSeconds;
      if (elapsedSeconds >= 60) {
        await _logCompletedSession(
          sessionType: FocusSessionType.focus,
          durationSeconds: state.totalSeconds,
          completedSeconds: elapsedSeconds,
          isCompleted: elapsedSeconds >= state.totalSeconds,
          startedAt: state.startedAt ?? DateTime.now().subtract(Duration(seconds: elapsedSeconds)),
          taskId: state.linkedTaskId,
          goalId: state.linkedGoalId,
        );
      }
    }

    final sec = _getDurationForType(type);
    state = state.copyWith(
      state: TimerState.idle,
      sessionType: type,
      totalSeconds: sec,
      remainingSeconds: sec,
      startedAt: null,
    );
    await _persistState();
  }

  /// Sets a custom duration in minutes for the active session (1 to 240 mins)
  Future<void> setCustomMinutes(int minutes) async {
    if (state.state == TimerState.running) return;
    _ticker?.cancel();

    // If reconfiguring a focus session that had accumulated time, log it
    if (state.sessionType == FocusSessionType.focus) {
      final elapsedSeconds = state.totalSeconds - state.remainingSeconds;
      if (elapsedSeconds >= 60) {
        await _logCompletedSession(
          sessionType: FocusSessionType.focus,
          durationSeconds: state.totalSeconds,
          completedSeconds: elapsedSeconds,
          isCompleted: elapsedSeconds >= state.totalSeconds,
          startedAt: state.startedAt ?? DateTime.now().subtract(Duration(seconds: elapsedSeconds)),
          taskId: state.linkedTaskId,
          goalId: state.linkedGoalId,
        );
      }
    }

    final clamped = minutes.clamp(1, 240);
    final sec = clamped * 60;
    state = state.copyWith(
      state: TimerState.idle,
      totalSeconds: sec,
      remainingSeconds: sec,
      startedAt: null,
    );
    await _persistState();
  }

  /// Nudge duration up or down by delta minutes
  void adjustMinutes(int deltaMinutes) {
    if (state.state == TimerState.running) return;
    final currentMinutes = (state.totalSeconds / 60).round();
    final newMinutes = (currentMinutes + deltaMinutes).clamp(1, 240);
    setCustomMinutes(newMinutes);
  }

  void linkTask({String? taskId, String? goalId}) {
    state = state.copyWith(
      linkedTaskId: taskId,
      linkedGoalId: goalId,
    );
    _persistState();
  }

  void _syncNotification({required bool isRunning}) {
    try {
      final notifService = _ref.read(notificationServiceProvider);
      notifService.showFocusTimerNotification(
        remainingSeconds: state.remainingSeconds,
        totalSeconds: state.totalSeconds,
        isRunning: isRunning,
        sessionType: state.sessionType.name,
        sessionLabel: state.linkedTaskId != null ? 'Deep Focus Session' : null,
      );
      _ref.read(pipServiceProvider).updateOverlay(
        remainingSeconds: state.remainingSeconds,
        totalSeconds: state.totalSeconds,
        isRunning: isRunning,
        isBreak: state.sessionType != FocusSessionType.focus,
      );
    } catch (_) {}
  }

  Future<void> start() async {
    if (state.state == TimerState.running) return;

    final now = DateTime.now();
    final targetEndMs = now.millisecondsSinceEpoch + (state.remainingSeconds * 1000);

    state = state.copyWith(
      state: TimerState.running,
      startedAt: state.startedAt ?? now,
    );

    _persistState(targetEndMs: targetEndMs);
    _startTicker();

    // Enable Picture-in-Picture auto-enter when running so user can float clock if they leave app
    _ref.read(pipServiceProvider).setAutoEnterEnabled(true);
    _syncNotification(isRunning: true);

    // Activate Focus Shield natively if enabled and in focus mode
    final shieldState = _ref.read(focusShieldProvider);
    final shieldService = _ref.read(focusShieldServiceProvider);

    if (shieldState.isShieldEnabled &&
        shieldState.selectedPackages.isNotEmpty &&
        state.sessionType == FocusSessionType.focus) {
      await shieldService.startShield(
        blockedPackages: shieldState.selectedPackages.toList(),
        endTimeMs: targetEndMs,
        strictMode: shieldState.strictMode,
        sessionLabel: 'Deep Focus Session',
        sessionId: const Uuid().v4(),
      );
    }
  }

  void addMinutes(int minutes) {
    if (state.state == TimerState.completed || state.state == TimerState.idle) return;
    final addedSeconds = minutes * 60;
    final newRemaining = state.remainingSeconds + addedSeconds;
    final newTotal = state.totalSeconds + addedSeconds;
    final targetEndMs = state.state == TimerState.running
        ? DateTime.now().millisecondsSinceEpoch + (newRemaining * 1000)
        : null;
    state = state.copyWith(
      remainingSeconds: newRemaining,
      totalSeconds: newTotal,
    );
    _persistState(targetEndMs: targetEndMs);
    if (state.state == TimerState.running) {
      _syncNotification(isRunning: true);
    }
  }

  void pause() {
    if (state.state != TimerState.running) return;
    _ticker?.cancel();

    state = state.copyWith(state: TimerState.paused);
    _persistState();
    _syncNotification(isRunning: false);

    // Pause Focus Shield
    _ref.read(focusShieldServiceProvider).pauseShield();

    // Auto-dismiss PiP when paused
    if (_ref.read(pipModeProvider)) {
      _ref.read(pipServiceProvider).exitPip();
    }
  }

  void resume() {
    if (state.state != TimerState.paused) return;
    _ref.read(pipServiceProvider).setAutoEnterEnabled(true);
    _syncNotification(isRunning: true);
    start();
  }

  Future<void> reset() async {
    _ticker?.cancel();
    _ref.read(focusShieldServiceProvider).stopShield();
    _ref.read(pipServiceProvider).setAutoEnterEnabled(false);
    _ref.read(notificationServiceProvider).cancelFocusTimerNotification();
    if (_ref.read(pipModeProvider)) {
      _ref.read(pipServiceProvider).exitPip();
    }

    // If resetting a focus session that had accumulated focus time, count every minute!
    if (state.sessionType == FocusSessionType.focus) {
      final elapsedSeconds = state.totalSeconds - state.remainingSeconds;
      if (elapsedSeconds >= 60) {
        await _logCompletedSession(
          sessionType: FocusSessionType.focus,
          durationSeconds: state.totalSeconds,
          completedSeconds: elapsedSeconds,
          isCompleted: elapsedSeconds >= state.totalSeconds,
          startedAt: state.startedAt ?? DateTime.now().subtract(Duration(seconds: elapsedSeconds)),
          taskId: state.linkedTaskId,
          goalId: state.linkedGoalId,
        );
      }
    }

    final sec = _getDurationForType(state.sessionType);
    state = state.copyWith(
      state: TimerState.idle,
      totalSeconds: sec,
      remainingSeconds: sec,
      startedAt: null,
    );
    await _clearPersistedState();
  }

  Future<void> skip() async {
    _ticker?.cancel();
    _ref.read(focusShieldServiceProvider).stopShield();
    _ref.read(pipServiceProvider).setAutoEnterEnabled(false);
    _ref.read(notificationServiceProvider).cancelFocusTimerNotification();

    // If skipping an active focus session with elapsed focus time, log the minutes!
    if (state.sessionType == FocusSessionType.focus) {
      final elapsedSeconds = state.totalSeconds - state.remainingSeconds;
      if (elapsedSeconds >= 60) {
        await _logCompletedSession(
          sessionType: FocusSessionType.focus,
          durationSeconds: state.totalSeconds,
          completedSeconds: elapsedSeconds,
          isCompleted: elapsedSeconds >= state.totalSeconds,
          startedAt: state.startedAt ?? DateTime.now().subtract(Duration(seconds: elapsedSeconds)),
          taskId: state.linkedTaskId,
          goalId: state.linkedGoalId,
        );
      }
    }

    FocusSessionType nextType;
    int newCycles = state.completedCycles;

    if (state.sessionType == FocusSessionType.focus) {
      newCycles = state.completedCycles + 1;
      if (newCycles >= 4) {
        nextType = FocusSessionType.longBreak;
        newCycles = 0;
      } else {
        nextType = FocusSessionType.shortBreak;
      }
    } else {
      nextType = FocusSessionType.focus;
    }

    final nextSec = _getDurationForType(nextType);

    state = FocusTimerState(
      state: TimerState.idle,
      sessionType: nextType,
      totalSeconds: nextSec,
      remainingSeconds: nextSec,
      completedCycles: newCycles,
      isZenMode: state.isZenMode,
      autoStartNextPhase: state.autoStartNextPhase,
      linkedTaskId: state.linkedTaskId,
      linkedGoalId: state.linkedGoalId,
    );
    await _prefs?.setInt(_keyCompletedCycles, newCycles);
    await _clearPersistedState();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        timer.cancel();
        _onSessionComplete();
      } else {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
        _syncNotification(isRunning: true);
      }
    });
  }

  Future<void> _onSessionComplete() async {
    final sessionType = state.sessionType;
    final duration = state.totalSeconds;
    final started = state.startedAt ?? DateTime.now().subtract(Duration(seconds: duration));

    // Capture interruption count and stop shield
    final shieldService = _ref.read(focusShieldServiceProvider);
    final shieldState = _ref.read(focusShieldProvider);
    final status = await shieldService.getShieldStatus();
    final interruptions = (status['interruptionCount'] as num? ?? 0).toInt();
    await shieldService.stopShield();
    _ref.read(pipServiceProvider).setAutoEnterEnabled(false);
    _ref.read(notificationServiceProvider).cancelFocusTimerNotification();
    _ref.read(notificationServiceProvider).showFocusCompletionNotification(
      durationMinutes: (duration / 60).round().clamp(1, 480),
      sessionType: sessionType.name,
    );

    await _logCompletedSession(
      sessionType: sessionType,
      durationSeconds: duration,
      completedSeconds: duration,
      startedAt: started,
      taskId: state.linkedTaskId,
      goalId: state.linkedGoalId,
      shieldEnabled: shieldState.isShieldEnabled,
      strictMode: shieldState.strictMode,
      interruptionsCount: interruptions,
    );

    // Haptic / vibration feedback on phase completion
    try {
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
    } catch (_) {}

    // Pomodoro 4-cycle progression:
    // Focus -> Short Break -> Focus -> Short Break -> Focus -> Short Break -> Focus -> Long Break
    FocusSessionType nextType;
    int newCycles = state.completedCycles;

    if (sessionType == FocusSessionType.focus) {
      newCycles = state.completedCycles + 1;
      if (newCycles >= 4) {
        nextType = FocusSessionType.longBreak;
        newCycles = 0; // reset for next cycle
      } else {
        nextType = FocusSessionType.shortBreak;
      }
    } else {
      nextType = FocusSessionType.focus;
    }

    final nextSec = _getDurationForType(nextType);
    final willAutoStart = state.autoStartNextPhase;

    state = FocusTimerState(
      state: willAutoStart ? TimerState.running : TimerState.completed,
      sessionType: nextType,
      totalSeconds: nextSec,
      remainingSeconds: nextSec,
      completedCycles: newCycles,
      isZenMode: state.isZenMode,
      autoStartNextPhase: state.autoStartNextPhase,
      linkedTaskId: state.linkedTaskId,
      linkedGoalId: state.linkedGoalId,
    );

    await _prefs?.setInt(_keyCompletedCycles, newCycles);

    if (!willAutoStart && _ref.read(pipModeProvider)) {
      _ref.read(pipServiceProvider).exitPip();
    }
    await _clearPersistedState();

    if (willAutoStart) {
      _startTicker();
    }
  }

  Future<void> _logCompletedSession({
    required FocusSessionType sessionType,
    required int durationSeconds,
    required int completedSeconds,
    required DateTime startedAt,
    String? taskId,
    String? goalId,
    bool isCompleted = true,
    bool shieldEnabled = false,
    bool strictMode = false,
    int interruptionsCount = 0,
  }) async {
    final repo = _ref.read(focusRepositoryProvider);
    final session = FocusSession(
      id: const Uuid().v4(),
      taskId: taskId,
      goalId: goalId,
      sessionType: sessionType,
      durationSeconds: durationSeconds,
      completedSeconds: completedSeconds,
      isCompleted: isCompleted,
      shieldEnabled: shieldEnabled,
      strictMode: strictMode,
      interruptionsCount: interruptionsCount,
      startedAt: startedAt,
      endedAt: DateTime.now(),
    );

    await repo.logSession(session);
    _ref.invalidate(todayFocusSecondsProvider);
    _ref.invalidate(todayCompletedFocusSessionsProvider);
    _ref.invalidate(recentFocusSessionsProvider);
    try {
      await _ref.read(todayFocusSecondsProvider.future);
    } catch (_) {}
  }

  Future<void> _persistState({int? targetEndMs}) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (!mounted) return;

    final currentState = state;

    String stateStr = 'idle';
    if (currentState.state == TimerState.running) stateStr = 'running';
    if (currentState.state == TimerState.paused) stateStr = 'paused';

    await prefs.setString(_keyTimerState, stateStr);
    await prefs.setString(_keySessionType, currentState.sessionType.dbValue);
    await prefs.setInt(_keyTotalSeconds, currentState.totalSeconds);
    await prefs.setInt(_keyRemainingSeconds, currentState.remainingSeconds);

    if (targetEndMs != null) {
      await prefs.setInt(_keyTargetEndMs, targetEndMs);
    }
    if (currentState.linkedTaskId != null) {
      await prefs.setString(_keyLinkedTaskId, currentState.linkedTaskId!);
    } else {
      await prefs.remove(_keyLinkedTaskId);
    }
    if (currentState.linkedGoalId != null) {
      await prefs.setString(_keyLinkedGoalId, currentState.linkedGoalId!);
    } else {
      await prefs.remove(_keyLinkedGoalId);
    }
    if (currentState.startedAt != null) {
      await prefs.setString(_keyStartedAt, currentState.startedAt!.toIso8601String());
    }
  }

  Future<void> _clearPersistedState() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(_keyTimerState);
    await prefs.remove(_keyTargetEndMs);
    await prefs.remove(_keyRemainingSeconds);
    await prefs.remove(_keyStartedAt);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final focusTimerProvider =
    StateNotifierProvider<FocusTimerController, FocusTimerState>((ref) {
  return FocusTimerController(ref);
});

/// Combines logged database focus seconds for today with in-memory live focus seconds
/// from an active or paused focus session so that the Daily Focus Target and Focus timer
/// stay in 100% sync second-by-second and minute-by-minute.
final liveTodayFocusSecondsProvider = Provider<int>((ref) {
  final dbSeconds = ref.watch(todayFocusSecondsProvider).valueOrNull ?? 0;
  final timerState = ref.watch(focusTimerProvider);

  final liveElapsedSeconds = (timerState.sessionType == FocusSessionType.focus &&
          (timerState.state == TimerState.running || timerState.state == TimerState.paused))
      ? (timerState.totalSeconds - timerState.remainingSeconds).clamp(0, timerState.totalSeconds)
      : 0;

  return dbSeconds + liveElapsedSeconds;
});
