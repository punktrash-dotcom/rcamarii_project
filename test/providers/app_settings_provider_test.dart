import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/providers/app_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('audio sounds preference defaults to disabled and persists when enabled',
      () async {
    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundsEnabled, isFalse);

    await provider.setAudioSoundsEnabled(true);

    final prefs = await SharedPreferences.getInstance();
    expect(provider.audioSoundsEnabled, isTrue);
    expect(prefs.getBool('app_settings.audio_sounds_enabled'), isTrue);
  });

  test('audio sounds preference loads from shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'app_settings.audio_sounds_enabled': true,
    });

    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundsEnabled, isTrue);
  });

  test('legacy audio sounds volume preference is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'app_settings.audio_sounds_volume': 0.65,
    });

    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundsEnabled, isFalse);
    expect(provider.audioSoundStyle, AudioSoundStyle.serious);
  });

  test('audio sound style defaults to serious and persists updates', () async {
    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundStyle, AudioSoundStyle.serious);

    await provider.setAudioSoundStyle(AudioSoundStyle.funny);

    final prefs = await SharedPreferences.getInstance();
    expect(provider.audioSoundStyle, AudioSoundStyle.funny);
    expect(prefs.getString('app_settings.audio_sound_style'), 'funny');
  });

  test('audio sound style loads from shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'app_settings.audio_sound_style': 'funny',
    });

    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundStyle, AudioSoundStyle.funny);
  });
}
