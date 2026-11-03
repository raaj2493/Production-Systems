import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AmbientSoundscapeState {
  final bool isPlaying;
  final String activeSound; // 'rain', 'forest', 'white_noise', 'cafe', 'custom'
  final String? customTrackPath;
  final String? customTrackName;
  final double volume;

  const AmbientSoundscapeState({
    this.isPlaying = false,
    this.activeSound = 'rain',
    this.customTrackPath,
    this.customTrackName,
    this.volume = 0.65,
  });

  bool get isCustom => activeSound == 'custom';

  AmbientSoundscapeState copyWith({
    bool? isPlaying,
    String? activeSound,
    String? customTrackPath,
    String? customTrackName,
    double? volume,
  }) {
    return AmbientSoundscapeState(
      isPlaying: isPlaying ?? this.isPlaying,
      activeSound: activeSound ?? this.activeSound,
      customTrackPath: customTrackPath ?? this.customTrackPath,
      customTrackName: customTrackName ?? this.customTrackName,
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
      if (soundType == 'custom' && state.customTrackPath != null) {
        await _playCustomMusic(state.customTrackPath!, state.volume);
      } else {
        await _startNativeSound(soundType, state.volume);
      }
    }
  }

  Future<bool> pickCustomAudioFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        state = state.copyWith(
          activeSound: 'custom',
          customTrackPath: path,
          customTrackName: name,
          isPlaying: true,
        );
        await _playCustomMusic(path, state.volume);
        return true;
      }
    } catch (e) {
      debugPrint('AmbientSoundscapeController: pickCustomAudioFile error: $e');
    }
    return false;
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
    if (state.activeSound == 'custom' && state.customTrackPath != null) {
      await _playCustomMusic(state.customTrackPath!, state.volume);
    } else {
      await _startNativeSound(state.activeSound, state.volume);
    }
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

  Future<void> _playCustomMusic(String filePath, double volume) async {
    try {
      await _channel.invokeMethod('playCustomMusic', {
        'filePath': filePath,
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
