import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'app_settings_provider.dart';

class AppAudioProvider with ChangeNotifier {
  static const _audioTimeout = Duration(seconds: 4);
  static const _screenOpenAudioMap =
      <String, ({String funnyAssetPath, String seriousAssetPath})>{
    'tab_farm': (
      funnyAssetPath: 'lib/assets/audio/funny_farm.wav',
      seriousAssetPath: 'lib/assets/audio/serious_farm.mp3',
    ),
    'employees': (
      funnyAssetPath: 'lib/assets/audio/funny_workers.mp3',
      seriousAssetPath: 'lib/assets/audio/serious_workers.mp3',
    ),
    'about': (
      funnyAssetPath: 'lib/assets/audio/funny_about.mp3',
      seriousAssetPath: 'lib/assets/audio/serious_about.mp3',
    ),
    'ftracker': (
      funnyAssetPath: 'lib/assets/audio/funny_ftracker.mp3',
      seriousAssetPath: 'lib/assets/audio/serious_ftracker.mp3',
    ),
    'exit': (
      funnyAssetPath: 'lib/assets/audio/funny_exit.mp3',
      seriousAssetPath: 'lib/assets/audio/serious_exit.mp3',
    ),
    'tab_supplies': (
      funnyAssetPath: 'lib/assets/audio/funny_supplies.mp3',
      seriousAssetPath: 'lib/assets/audio/serious_supplies.mp3',
    ),
    'profit': (
      funnyAssetPath: 'lib/assets/audio/funny_profit.mp3',
      seriousAssetPath: 'lib/assets/audio/serious_profit.mp3',
    ),
    'settings': (
      funnyAssetPath: 'lib/assets/audio/funny_settings.mp3',
      seriousAssetPath: 'lib/assets/audio/serious_settings.mp3',
    ),
  };
  static const _errorAudioMap = (
    funnyAssetPath: 'lib/assets/audio/funny_error.mp3',
    seriousAssetPath: 'lib/assets/audio/serious_settings.mp3',
  );

  AudioPlayer? _player;
  String? _currentAssetPath;
  double _volumeMultiplier = 0.75;
  int _requestId = 0;

  void updateVolume(double volume) {
    if (_volumeMultiplier == volume) return;
    _volumeMultiplier = volume;
    _player?.setVolume(volume);
  }

  String? assetPathForScreenOpenSound({
    required String screenKey,
    required AudioSoundStyle style,
  }) {
    final mapping = _screenOpenAudioMap[screenKey];
    if (mapping == null) {
      return null;
    }
    return style == AudioSoundStyle.funny
        ? mapping.funnyAssetPath
        : mapping.seriousAssetPath;
  }

  Future<void> playAsset({
    required String assetPath,
    required bool enabled,
    bool loop = false,
  }) async {
    if (!enabled) {
      await stop();
      return;
    }

    final requestId = ++_requestId;

    try {
      final player = _player ??= AudioPlayer();
      final shouldReloadAsset = _currentAssetPath != assetPath;
      await player.stop().timeout(_audioTimeout);
      if (requestId != _requestId) {
        return;
      }

      if (shouldReloadAsset) {
        await player.setAsset(assetPath).timeout(_audioTimeout);
        _currentAssetPath = assetPath;
        if (requestId != _requestId) {
          return;
        }
      }

      await player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      // Normalized volume level to match platform expectations
      await player.setVolume(_volumeMultiplier);
      await player.seek(Duration.zero).timeout(_audioTimeout);
      if (requestId != _requestId) {
        return;
      }

      await player.play().timeout(_audioTimeout);
    } catch (error, stackTrace) {
      developer.log(
        'Shared audio playback failed',
        name: 'RCAMARii.Audio',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> playForStyle({
    required AudioSoundStyle style,
    required String seriousAssetPath,
    required String funnyAssetPath,
    required bool enabled,
  }) {
    return playAsset(
      assetPath:
          style == AudioSoundStyle.funny ? funnyAssetPath : seriousAssetPath,
      enabled: enabled,
    );
  }

  Future<void> playScreenOpenSound({
    required String screenKey,
    required AudioSoundStyle style,
    required bool enabled,
    bool loop = false,
  }) {
    final mapping = _screenOpenAudioMap[screenKey];
    if (mapping == null) {
      return Future.value();
    }
    return playAsset(
      assetPath: style == AudioSoundStyle.funny
          ? mapping.funnyAssetPath
          : mapping.seriousAssetPath,
      enabled: enabled,
      loop: loop,
    );
  }

  Future<void> playErrorSound({
    required AudioSoundStyle style,
    required bool enabled,
  }) {
    return playAsset(
      assetPath: style == AudioSoundStyle.funny
          ? _errorAudioMap.funnyAssetPath
          : _errorAudioMap.seriousAssetPath,
      enabled: enabled,
    );
  }

  Future<void> stopAsset(String assetPath) async {
    final player = _player;
    if (player == null || _currentAssetPath != assetPath) {
      return;
    }

    _requestId++;
    try {
      await player.stop().timeout(_audioTimeout);
    } catch (error, stackTrace) {
      developer.log(
        'Shared audio stop failed',
        name: 'RCAMARii.Audio',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> stopForStyle({
    required AudioSoundStyle style,
    required String seriousAssetPath,
    required String funnyAssetPath,
  }) {
    return stopAsset(
      style == AudioSoundStyle.funny ? funnyAssetPath : seriousAssetPath,
    );
  }

  Future<void> stopScreenOpenSound({
    required String screenKey,
    required AudioSoundStyle style,
  }) {
    final assetPath = assetPathForScreenOpenSound(
      screenKey: screenKey,
      style: style,
    );
    if (assetPath == null) {
      return Future.value();
    }
    return stopAsset(assetPath);
  }

  Future<void> stop() async {
    _requestId++;
    final player = _player;
    if (player == null) {
      return;
    }

    try {
      await player.stop().timeout(_audioTimeout);
    } catch (error, stackTrace) {
      developer.log(
        'Shared audio stop failed',
        name: 'RCAMARii.Audio',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _requestId++;
    final player = _player;
    if (player != null) {
      unawaited(player.stop());
      player.dispose();
    }
    super.dispose();
  }
}
