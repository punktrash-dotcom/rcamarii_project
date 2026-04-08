import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'app_settings_provider.dart';

class AppAudioProvider with ChangeNotifier {
  static const _targetMeanVolumeDb = -15.0;
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
  static const _measuredMeanVolumeDb = <String, double>{
    'lib/assets/audio/cancel.mp3': -29.6,
    'lib/assets/audio/english.mp3': -10.8,
    'lib/assets/audio/funny_about.mp3': -14.9,
    'lib/assets/audio/funny_error.mp3': -13.7,
    'lib/assets/audio/funny_exit.mp3': -21.2,
    'lib/assets/audio/funny_farm.wav': -13.7,
    'lib/assets/audio/funny_ftracker.mp3': -13.5,
    'lib/assets/audio/funny_knowledge.mp3': -10.8,
    'lib/assets/audio/funny_profit.mp3': -16.9,
    'lib/assets/audio/funny_reports.mp3': -16.7,
    'lib/assets/audio/funny_settings.mp3': -13.2,
    'lib/assets/audio/funny_sugarcalc.mp3': -13.4,
    'lib/assets/audio/funny_supplies.mp3': -20.8,
    'lib/assets/audio/funny_workers.mp3': -19.7,
    'lib/assets/audio/save.mp3': -18.9,
    'lib/assets/audio/serious_about.mp3': -21.9,
    'lib/assets/audio/serious_addfarm.mp3': -34.3,
    'lib/assets/audio/serious_exit.mp3': -15.1,
    'lib/assets/audio/serious_farm.mp3': -13.5,
    'lib/assets/audio/serious_ftracker.mp3': -23.2,
    'lib/assets/audio/serious_knowledge.mp3': -13.4,
    'lib/assets/audio/serious_profit.mp3': -18.0,
    'lib/assets/audio/serious_settings.mp3': -10.0,
    'lib/assets/audio/serious_sugarcalc.mp3': -14.1,
    'lib/assets/audio/serious_supplies.mp3': -13.2,
    'lib/assets/audio/serious_workers.mp3': -10.7,
    'lib/assets/audio/tagalog.mp3': -16.9,
    'lib/assets/audio/visayan.mp3': -14.5,
  };

  AudioPlayer? _player;
  String? _currentAssetPath;
  double _volumeMultiplier = 0.75;
  int _requestId = 0;
  Future<void>? _initialization;

  void updateVolume(double volume) {
    if (_volumeMultiplier == volume) return;
    _volumeMultiplier = volume;
    final player = _player;
    final currentAssetPath = _currentAssetPath;
    if (player != null && currentAssetPath != null) {
      unawaited(player.setVolume(_effectiveVolumeForAsset(currentAssetPath)));
    }
  }

  static AudioSessionConfiguration sessionConfigurationForPlatform(
    TargetPlatform platform,
  ) {
    switch (platform) {
      case TargetPlatform.iOS:
        return const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.ambient,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
        );
      case TargetPlatform.android:
        return const AudioSessionConfiguration(
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.assistanceSonification,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return const AudioSessionConfiguration();
    }
  }

  static double normalizationMultiplierForMeanVolumeDb(double meanVolumeDb) {
    if (meanVolumeDb <= _targetMeanVolumeDb) {
      return 1.0;
    }

    final attenuationDb = _targetMeanVolumeDb - meanVolumeDb;
    return math.pow(10, attenuationDb / 20).toDouble();
  }

  double normalizationMultiplierForAsset(String assetPath) {
    final meanVolumeDb = _measuredMeanVolumeDb[assetPath];
    if (meanVolumeDb == null || meanVolumeDb <= _targetMeanVolumeDb) {
      return 1.0;
    }

    return normalizationMultiplierForMeanVolumeDb(meanVolumeDb);
  }

  double _effectiveVolumeForAsset(String assetPath) {
    return (_volumeMultiplier * normalizationMultiplierForAsset(assetPath))
        .clamp(0.0, 1.0);
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        sessionConfigurationForPlatform(defaultTargetPlatform),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Audio session configuration failed',
        name: 'RCAMARii.Audio',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
      await _ensureInitialized();
      final player = _player ??= AudioPlayer();

      // Reuse the already loaded source when possible to avoid unnecessary
      // decoder teardown/recreation on Android.
      if (_currentAssetPath == assetPath && player.playing) {
        return;
      }

      await player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      await player.setVolume(_effectiveVolumeForAsset(assetPath));
      if (requestId != _requestId) {
        return;
      }

      if (_currentAssetPath != assetPath) {
        await player.setAsset(assetPath);
        _currentAssetPath = assetPath;
        if (requestId != _requestId) {
          return;
        }
      } else {
        await player.seek(Duration.zero);
      }
      if (requestId != _requestId) {
        return;
      }

      unawaited(player.play());
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
      await player.stop();
      _currentAssetPath = null;
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
      await player.stop();
      _currentAssetPath = null;
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
    _currentAssetPath = null;
    final player = _player;
    if (player != null) {
      unawaited(player.stop());
      player.dispose();
    }
    super.dispose();
  }
}
