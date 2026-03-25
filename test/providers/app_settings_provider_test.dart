import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/providers/app_settings_provider.dart';
import 'package:nmd/services/app_properties_store.dart';

void main() {
  setUp(() {
    AppPropertiesStore.instance.useMemoryStoreForTesting();
  });

  tearDown(() {
    AppPropertiesStore.instance.resetTestingOverrides();
  });

  test('audio sounds preference defaults to disabled and persists when enabled',
      () async {
    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundsEnabled, isFalse);

    await provider.setAudioSoundsEnabled(true);

    final values = await AppPropertiesStore.instance.exportAll();
    expect(provider.audioSoundsEnabled, isTrue);
    expect(values['app_settings.audio_sounds_enabled'], isTrue);
  });

  test('user setup defaults to unlocked and incomplete', () async {
    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.hasCompletedUserSetup, isFalse);
    expect(provider.userName, isEmpty);
    expect(provider.appLockEnabled, isFalse);
    expect(provider.requiresAppPassword, isFalse);
  });

  test('user setup persists name, lock choice, and password', () async {
    final provider = AppSettingsProvider();
    await provider.ready;

    await provider.completeUserSetup(
      userName: 'Ram',
      appLockEnabled: true,
      password: '1234',
    );

    final values = await AppPropertiesStore.instance.exportAll();
    expect(provider.hasCompletedUserSetup, isTrue);
    expect(provider.userName, 'Ram');
    expect(provider.appLockEnabled, isTrue);
    expect(provider.appPassword, '1234');
    expect(provider.requiresAppPassword, isTrue);
    expect(values['app_settings.user_name'], 'Ram');
    expect(values['app_settings.user_setup_complete'], isTrue);
    expect(values['app_settings.app_lock_enabled'], isTrue);
    expect(values['app_settings.app_password'], '1234');
  });

  test('user setup clears saved password when app lock is disabled', () async {
    final provider = AppSettingsProvider();
    await provider.ready;

    await provider.completeUserSetup(
      userName: 'Ram',
      appLockEnabled: false,
      password: '1234',
    );

    final values = await AppPropertiesStore.instance.exportAll();
    expect(provider.appLockEnabled, isFalse);
    expect(provider.appPassword, isEmpty);
    expect(provider.requiresAppPassword, isFalse);
    expect(values.containsKey('app_settings.app_password'), isFalse);
  });

  test('user name updates after setup', () async {
    final provider = AppSettingsProvider();
    await provider.ready;
    await provider.completeUserSetup(
      userName: 'Ram',
      appLockEnabled: false,
    );

    await provider.setUserName('Amari');

    final values = await AppPropertiesStore.instance.exportAll();
    expect(provider.userName, 'Amari');
    expect(values['app_settings.user_name'], 'Amari');
  });

  test('user access edit updates username and password state', () async {
    final provider = AppSettingsProvider();
    await provider.ready;
    await provider.completeUserSetup(
      userName: 'Ram',
      appLockEnabled: true,
      password: '1234',
    );

    await provider.updateUserAccess(
      userName: 'Amari',
      appLockEnabled: true,
      password: '5678',
    );

    final values = await AppPropertiesStore.instance.exportAll();
    expect(provider.userName, 'Amari');
    expect(provider.appPassword, '5678');
    expect(provider.appLockEnabled, isTrue);
    expect(values['app_settings.user_name'], 'Amari');
    expect(values['app_settings.app_password'], '5678');
  });

  test('audio sounds preference loads from stored properties', () async {
    AppPropertiesStore.instance.useMemoryStoreForTesting({
      'app_settings.audio_sounds_enabled': true,
    });

    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundsEnabled, isTrue);
  });

  test('audio sounds volume defaults to 0.75 when unset', () async {
    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundsVolume, 0.75);
    expect(provider.audioSoundsEnabled, isFalse);
    expect(provider.audioSoundStyle, AudioSoundStyle.serious);
  });

  test('audio sound style defaults to serious and persists updates', () async {
    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundStyle, AudioSoundStyle.serious);

    await provider.setAudioSoundStyle(AudioSoundStyle.funny);

    final values = await AppPropertiesStore.instance.exportAll();
    expect(provider.audioSoundStyle, AudioSoundStyle.funny);
    expect(values['app_settings.audio_sound_style'], 'funny');
  });

  test('audio sound style loads from stored properties', () async {
    AppPropertiesStore.instance.useMemoryStoreForTesting({
      'app_settings.audio_sound_style': 'funny',
    });

    final provider = AppSettingsProvider();
    await provider.ready;

    expect(provider.audioSoundStyle, AudioSoundStyle.funny);
  });
}
