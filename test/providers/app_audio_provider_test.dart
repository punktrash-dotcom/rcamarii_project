import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/providers/app_audio_provider.dart';

void main() {
  test('normalization trims louder assets and leaves quieter assets unchanged',
      () {
    final provider = AppAudioProvider();

    expect(
      provider.normalizationMultiplierForAsset(
        'lib/assets/audio/serious_settings.mp3',
      ),
      closeTo(0.56, 0.02),
    );
    expect(
      provider.normalizationMultiplierForAsset(
        'lib/assets/audio/serious_about.mp3',
      ),
      1.0,
    );
  });

  test('speech volume is normalized before talkback playback', () {
    expect(
      AppAudioProvider.effectiveSpeechVolume(0.75),
      closeTo(0.42, 0.02),
    );
    expect(
      AppAudioProvider.effectiveSpeechVolume(1.0),
      lessThan(1.0),
    );
  });

  test('android session matches transient UI sonification playback', () {
    final configuration = AppAudioProvider.sessionConfigurationForPlatform(
      TargetPlatform.android,
    );

    expect(
      configuration.androidAudioAttributes?.contentType,
      AndroidAudioContentType.sonification,
    );
    expect(
      configuration.androidAudioAttributes?.usage,
      AndroidAudioUsage.assistanceSonification,
    );
    expect(
      configuration.androidAudioFocusGainType,
      AndroidAudioFocusGainType.gainTransientMayDuck,
    );
    expect(configuration.androidWillPauseWhenDucked, isFalse);
  });

  test('ios session respects ambient platform audio behavior', () {
    final configuration = AppAudioProvider.sessionConfigurationForPlatform(
      TargetPlatform.iOS,
    );

    expect(
        configuration.avAudioSessionCategory, AVAudioSessionCategory.ambient);
    expect(
      configuration.avAudioSessionCategoryOptions,
      AVAudioSessionCategoryOptions.mixWithOthers,
    );
    expect(configuration.avAudioSessionMode, AVAudioSessionMode.defaultMode);
  });
}
