import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AmbientSoundscapeState {
  final bool isPlaying;
  final String activeSound; // 'rain', 'forest', 'white_noise', 'cafe'
  final double volume;

  const AmbientSoundscapeState({
    this.isPlaying = false,
    this.activeSound = 'rain',
    this.volume = 0.65,
  });

  AmbientSoundscapeState copyWith({
    bool? isPlaying,
    String? activeSound,
    double? volume,
  }) {
    return AmbientSoundscapeState(
      isPlaying: isPlaying ?? this.isPlaying,
      activeSound: activeSound ?? this.activeSound,
      volume: volume ?? this.volume,
    );
  }
}

class AmbientSoundscapeController extends StateNotifier<AmbientSoundscapeState> {
  static const _channel = MethodChannel('com.arete.app/focus_shield');

  AmbientSoundscapeController() : super(const AmbientSoundscapeState());

  Future<void> selectSoundscape(String soundType) async {
    state = state.copyWith(activeSound: soundType);
    if (state.isPlaying) {
      await _startNativeSound(soundType, state.volume);
    }
  }

  Future<void> togglePlay() async {
    if (state.isPlaying) {
      await stop();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    state = state.copyWith(isPlaying: true);
    await _startNativeSound(state.activeSound, state.volume);
  }

  Future<void> stop() async {
    state = state.copyWith(isPlaying: false);
    try {
      await _channel.invokeMethod('stopAmbientSound');
    } catch (_) {}
  }

  Future<void> setVolume(double newVolume) async {
    final clamped = newVolume.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    try {
      await _channel.invokeMethod('setAmbientVolume', {'volume': clamped});
    } catch (_) {}
  }

  Future<void> _startNativeSound(String type, double volume) async {
    try {
      await _channel.invokeMethod('playAmbientSound', {
        'type': type,
        'volume': volume,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final ambientSoundscapeProvider =
    StateNotifierProvider<AmbientSoundscapeController, AmbientSoundscapeState>((ref) {
  return AmbientSoundscapeController();
});
