import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String colorPalette; // 'sage_coral', 'ocean_sunrise', 'berry_lavender', 'cyber_lime'
  final int dailyTaskTarget;
  final int defaultFocusMinutes;
  final int defaultShortBreakMinutes;
  final int defaultLongBreakMinutes;
  final int weekStartDay; // 1 = Monday, 7 = Sunday
  final int dailyFocusGoalMinutes;
  final bool hasCompletedTour;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.colorPalette = 'sage_coral',
    this.dailyTaskTarget = 3,
    this.defaultFocusMinutes = 25,
    this.defaultShortBreakMinutes = 5,
    this.defaultLongBreakMinutes = 15,
    this.weekStartDay = 1,
    this.focusDurationPresets = const [15, 25, 45, 60],
    this.dailyFocusGoalMinutes = 120,
    this.hasCompletedTour = false,
  });

  final List<int> focusDurationPresets;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? colorPalette,
    int? dailyTaskTarget,
    int? defaultFocusMinutes,
    int? defaultShortBreakMinutes,
    int? defaultLongBreakMinutes,
    int? weekStartDay,
    List<int>? focusDurationPresets,
    int? dailyFocusGoalMinutes,
    bool? hasCompletedTour,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      colorPalette: colorPalette ?? this.colorPalette,
      dailyTaskTarget: dailyTaskTarget ?? this.dailyTaskTarget,
      defaultFocusMinutes: defaultFocusMinutes ?? this.defaultFocusMinutes,
      defaultShortBreakMinutes:
          defaultShortBreakMinutes ?? this.defaultShortBreakMinutes,
      defaultLongBreakMinutes:
          defaultLongBreakMinutes ?? this.defaultLongBreakMinutes,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      focusDurationPresets: focusDurationPresets ?? this.focusDurationPresets,
      dailyFocusGoalMinutes:
          dailyFocusGoalMinutes ?? this.dailyFocusGoalMinutes,
      hasCompletedTour: hasCompletedTour ?? this.hasCompletedTour,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyColorPalette = 'settings_color_palette';
  static const _keyDailyTarget = 'settings_daily_task_target';
  static const _keyFocusMinutes = 'settings_focus_minutes';
  static const _keyShortBreakMinutes = 'settings_short_break_minutes';
  static const _keyLongBreakMinutes = 'settings_long_break_minutes';
  static const _keyWeekStartDay = 'settings_week_start_day';
  static const _keyFocusDurationPresets = 'settings_focus_duration_presets';
  static const _keyDailyFocusGoalMinutes = 'settings_daily_focus_goal_minutes';
  static const _keyHasCompletedTour = 'settings_has_completed_tour';

  final SharedPreferences? _prefs;

  AppSettingsNotifier([this._prefs]) : super(const AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    if (_prefs == null) return;

    final themeStr = _prefs.getString(_keyThemeMode);
    ThemeMode themeMode = ThemeMode.light;
    if (themeStr == 'dark') themeMode = ThemeMode.dark;
    if (themeStr == 'system') themeMode = ThemeMode.system;

    final palette = _prefs.getString(_keyColorPalette) ?? 'sage_coral';
    final dailyTarget = _prefs.getInt(_keyDailyTarget) ?? 3;
    final focusMinutes = _prefs.getInt(_keyFocusMinutes) ?? 25;
    final shortBreak = _prefs.getInt(_keyShortBreakMinutes) ?? 5;
    final longBreak = _prefs.getInt(_keyLongBreakMinutes) ?? 15;
    final weekStart = _prefs.getInt(_keyWeekStartDay) ?? 1;
    final dailyGoal = _prefs.getInt(_keyDailyFocusGoalMinutes) ?? 120;
    final hasTour = _prefs.getBool(_keyHasCompletedTour) ?? false;

    final presetsStringList = _prefs.getStringList(_keyFocusDurationPresets);
    List<int> presets = const [15, 25, 45, 60];
    if (presetsStringList != null && presetsStringList.isNotEmpty) {
      presets = presetsStringList
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toList();
      if (presets.isEmpty) presets = const [15, 25, 45, 60];
    }

    state = AppSettings(
      themeMode: themeMode,
      colorPalette: palette,
      dailyTaskTarget: dailyTarget,
      defaultFocusMinutes: focusMinutes,
      defaultShortBreakMinutes: shortBreak,
      defaultLongBreakMinutes: longBreak,
      weekStartDay: weekStart,
      focusDurationPresets: presets,
      dailyFocusGoalMinutes: dailyGoal,
      hasCompletedTour: hasTour,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _prefs?.setString(_keyThemeMode, modeStr);
  }

  Future<void> setColorPalette(String palette) async {
    state = state.copyWith(colorPalette: palette);
    await _prefs?.setString(_keyColorPalette, palette);
  }

  Future<void> setDailyTaskTarget(int target) async {
    state = state.copyWith(dailyTaskTarget: target);
    await _prefs?.setInt(_keyDailyTarget, target);
  }

  Future<void> setFocusMinutes(int minutes) async {
    state = state.copyWith(defaultFocusMinutes: minutes);
    await _prefs?.setInt(_keyFocusMinutes, minutes);
  }

  Future<void> setShortBreakMinutes(int minutes) async {
    state = state.copyWith(defaultShortBreakMinutes: minutes);
    await _prefs?.setInt(_keyShortBreakMinutes, minutes);
  }

  Future<void> setLongBreakMinutes(int minutes) async {
    state = state.copyWith(defaultLongBreakMinutes: minutes);
    await _prefs?.setInt(_keyLongBreakMinutes, minutes);
  }

  Future<void> setWeekStartDay(int day) async {
    state = state.copyWith(weekStartDay: day);
    await _prefs?.setInt(_keyWeekStartDay, day);
  }

  Future<void> setFocusDurationPresets(List<int> presets) async {
    final cleaned = presets.where((p) => p > 0).toSet().toList()..sort();
    state = state.copyWith(focusDurationPresets: cleaned);
    await _prefs?.setStringList(
      _keyFocusDurationPresets,
      cleaned.map((p) => p.toString()).toList(),
    );
  }

  Future<void> setDailyFocusGoalMinutes(int minutes) async {
    final validMinutes = minutes > 0 ? minutes : 120;
    state = state.copyWith(dailyFocusGoalMinutes: validMinutes);
    await _prefs?.setInt(_keyDailyFocusGoalMinutes, validMinutes);
  }

  Future<void> setHasCompletedTour(bool completed) async {
    state = state.copyWith(hasCompletedTour: completed);
    await _prefs?.setBool(_keyHasCompletedTour, completed);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppSettingsNotifier(prefs);
});
