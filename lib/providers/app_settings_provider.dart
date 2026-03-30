import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_properties_store.dart';

enum AppCurrency { php, usd, eur }

enum LaunchDestination { hub, workspace }

enum AudioSoundStyle { serious, funny }

AudioSoundStyle selectedGlobalAudioSoundStyle = AudioSoundStyle.serious;

extension AppCurrencyX on AppCurrency {
  String get code {
    switch (this) {
      case AppCurrency.php:
        return 'php';
      case AppCurrency.usd:
        return 'usd';
      case AppCurrency.eur:
        return 'eur';
    }
  }

  String get label {
    switch (this) {
      case AppCurrency.php:
        return 'Philippine Peso';
      case AppCurrency.usd:
        return 'US Dollar';
      case AppCurrency.eur:
        return 'Euro';
    }
  }

  String get locale {
    switch (this) {
      case AppCurrency.php:
        return 'en_PH';
      case AppCurrency.usd:
        return 'en_US';
      case AppCurrency.eur:
        return 'de_DE';
    }
  }

  String get symbol {
    switch (this) {
      case AppCurrency.php:
        return '\u20B1';
      case AppCurrency.usd:
        return '\$';
      case AppCurrency.eur:
        return '\u20AC';
    }
  }

  static AppCurrency fromCode(String? code) {
    switch (code) {
      case 'usd':
        return AppCurrency.usd;
      case 'eur':
        return AppCurrency.eur;
      case 'php':
      default:
        return AppCurrency.php;
    }
  }
}

extension LaunchDestinationX on LaunchDestination {
  String get code {
    switch (this) {
      case LaunchDestination.hub:
        return 'hub';
      case LaunchDestination.workspace:
        return 'workspace';
    }
  }

  String get label {
    switch (this) {
      case LaunchDestination.hub:
        return 'Operational Hub';
      case LaunchDestination.workspace:
        return 'Field Workspace';
    }
  }

  static LaunchDestination fromCode(String? code) {
    switch (code) {
      case 'workspace':
        return LaunchDestination.workspace;
      case 'hub':
      default:
        return LaunchDestination.hub;
    }
  }
}

extension AudioSoundStyleX on AudioSoundStyle {
  String get code {
    switch (this) {
      case AudioSoundStyle.serious:
        return 'serious';
      case AudioSoundStyle.funny:
        return 'funny';
    }
  }

  String get label {
    switch (this) {
      case AudioSoundStyle.serious:
        return 'Serious';
      case AudioSoundStyle.funny:
        return 'Funny';
    }
  }

  static AudioSoundStyle fromCode(String? code) {
    switch (code) {
      case 'funny':
        return AudioSoundStyle.funny;
      case 'serious':
      default:
        return AudioSoundStyle.serious;
    }
  }
}

class AppSettingsProvider with ChangeNotifier {
  static const _currencyKey = 'app_settings.currency';
  static const _launchDestinationKey = 'app_settings.launch_destination';
  static const _userNameKey = 'app_settings.user_name';
  static const _userSetupCompleteKey = 'app_settings.user_setup_complete';
  static const _appLockEnabledKey = 'app_settings.app_lock_enabled';
  static const _appPasswordKey = 'app_settings.app_password';
  static const _voiceAssistantEnabledKey =
      'app_settings.voice_assistant_enabled';
  static const _voiceResponsesEnabledKey =
      'app_settings.voice_responses_enabled';
  static const _audioSoundsEnabledKey = 'app_settings.audio_sounds_enabled';
  static const _audioSoundsVolumeKey = 'app_settings.audio_sounds_volume';
  static const _audioSoundStyleKey = 'app_settings.audio_sound_style';
  static const _weatherAutoRefreshKey = 'app_settings.weather_auto_refresh';
  static const _reducedMotionKey = 'app_settings.reduced_motion';

  late final Future<void> _ready;
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  AppCurrency _currency = AppCurrency.php;
  LaunchDestination _launchDestination = LaunchDestination.hub;
  String _userName = '';
  bool _userSetupComplete = false;
  bool _appLockEnabled = false;
  String _appPassword = '';
  bool _voiceAssistantEnabled = true;
  bool _voiceResponsesEnabled = true;
  bool _audioSoundsEnabled = false;
  double _audioSoundsVolume = 0.75;
  AudioSoundStyle _audioSoundStyle = AudioSoundStyle.serious;
  bool _weatherAutoRefresh = true;
  bool _reducedMotion = false;

  Future<void> get ready => _ready;

  AppCurrency get currency => _currency;
  LaunchDestination get launchDestination => _launchDestination;
  String get userName => _userName;
  bool get hasCompletedUserSetup => _userSetupComplete;
  bool get appLockEnabled => _appLockEnabled;
  String get appPassword => _appPassword;
  bool get hasAppPassword => _appPassword.isNotEmpty;
  bool get requiresAppPassword => _appLockEnabled && hasAppPassword;
  bool get voiceAssistantEnabled => _voiceAssistantEnabled;
  bool get voiceResponsesEnabled => _voiceResponsesEnabled;
  bool get audioSoundsEnabled => _audioSoundsEnabled;
  double get audioSoundsVolume => _audioSoundsVolume;
  AudioSoundStyle get audioSoundStyle => _audioSoundStyle;
  bool get weatherAutoRefresh => _weatherAutoRefresh;
  bool get reducedMotion => _reducedMotion;

  String get currencyLabel => _currency.label;
  String get currencySymbol => _currency.symbol;
  NumberFormat get currencyFormat =>
      NumberFormat.currency(locale: _currency.locale, symbol: _currency.symbol);

  AppSettingsProvider() {
    _ready = _load();
  }

  Future<void> completeUserSetup({
    required String userName,
    required bool appLockEnabled,
    String password = '',
  }) async {
    await updateUserAccess(
      userName: userName,
      appLockEnabled: appLockEnabled,
      password: password,
      markSetupComplete: true,
    );
  }

  Future<void> updateUserAccess({
    required String userName,
    required bool appLockEnabled,
    String password = '',
    bool markSetupComplete = true,
  }) async {
    final trimmedName = userName.trim();
    final trimmedPassword = password.trim();

    _userName = trimmedName;
    _userSetupComplete = markSetupComplete || _userSetupComplete;
    _appLockEnabled = appLockEnabled;
    _appPassword = appLockEnabled ? trimmedPassword : '';
    notifyListeners();

    await _store.setString(_userNameKey, _userName);
    await _store.setBool(_userSetupCompleteKey, _userSetupComplete);
    await _store.setBool(_appLockEnabledKey, _appLockEnabled);
    if (_appPassword.isEmpty) {
      await _store.remove(_appPasswordKey);
    } else {
      await _store.setString(_appPasswordKey, _appPassword);
    }
  }

  Future<void> setUserName(String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty || _userName == trimmedValue) return;

    _userName = trimmedValue;
    notifyListeners();

    await _store.setString(_userNameKey, _userName);
  }

  bool isAppPasswordValid(String value) {
    if (!hasAppPassword) return true;
    return _appPassword == value;
  }

  Future<void> setCurrency(AppCurrency value) async {
    if (_currency == value) return;
    _currency = value;
    notifyListeners();

    await _store.setString(_currencyKey, value.code);
  }

  Future<void> setLaunchDestination(LaunchDestination value) async {
    if (_launchDestination == value) return;
    _launchDestination = value;
    notifyListeners();

    await _store.setString(_launchDestinationKey, value.code);
  }

  Future<void> setAppLockEnabled(bool value) async {
    if (_appLockEnabled == value) return;
    if (value && !hasAppPassword) {
      throw StateError('Cannot enable app lock without a saved password.');
    }

    _appLockEnabled = value;
    notifyListeners();

    await _store.setBool(_appLockEnabledKey, value);
  }

  Future<void> setVoiceAssistantEnabled(bool value) async {
    if (_voiceAssistantEnabled == value) return;
    _voiceAssistantEnabled = value;
    notifyListeners();

    await _store.setBool(_voiceAssistantEnabledKey, value);
  }

  Future<void> setVoiceResponsesEnabled(bool value) async {
    if (_voiceResponsesEnabled == value) return;
    _voiceResponsesEnabled = value;
    notifyListeners();

    await _store.setBool(_voiceResponsesEnabledKey, value);
  }

  Future<void> setAudioSoundsEnabled(bool value) async {
    if (_audioSoundsEnabled == value) return;
    _audioSoundsEnabled = value;
    notifyListeners();

    await _store.setBool(_audioSoundsEnabledKey, value);
  }

  Future<void> setAudioSoundsVolume(double value) async {
    if (_audioSoundsVolume == value) return;
    _audioSoundsVolume = value;
    notifyListeners();

    await _store.setDouble(_audioSoundsVolumeKey, value);
  }

  Future<void> setAudioSoundStyle(AudioSoundStyle value) async {
    if (_audioSoundStyle == value) return;
    _audioSoundStyle = value;
    selectedGlobalAudioSoundStyle = value;
    notifyListeners();

    await _store.setString(_audioSoundStyleKey, value.code);
  }

  Future<void> setWeatherAutoRefresh(bool value) async {
    if (_weatherAutoRefresh == value) return;
    _weatherAutoRefresh = value;
    notifyListeners();

    await _store.setBool(_weatherAutoRefreshKey, value);
  }

  Future<void> setReducedMotion(bool value) async {
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    notifyListeners();

    await _store.setBool(_reducedMotionKey, value);
  }

  Future<void> reload() async {
    await _load(notify: true);
  }

  Future<void> _load({bool notify = true}) async {
    await _store.ready;

    _currency = AppCurrencyX.fromCode(await _store.getString(_currencyKey));
    _launchDestination = LaunchDestinationX.fromCode(
      await _store.getString(_launchDestinationKey),
    );
    _userName = (await _store.getString(_userNameKey))?.trim() ?? '';
    _userSetupComplete = await _store.getBool(_userSetupCompleteKey) ?? false;
    _appLockEnabled = await _store.getBool(_appLockEnabledKey) ?? false;
    _appPassword = await _store.getString(_appPasswordKey) ?? '';
    _voiceAssistantEnabled =
        await _store.getBool(_voiceAssistantEnabledKey) ?? true;
    _voiceResponsesEnabled =
        await _store.getBool(_voiceResponsesEnabledKey) ?? true;
    _audioSoundsEnabled = await _store.getBool(_audioSoundsEnabledKey) ?? false;
    _audioSoundsVolume = await _store.getDouble(_audioSoundsVolumeKey) ?? 0.75;
    _audioSoundStyle =
        AudioSoundStyleX.fromCode(await _store.getString(_audioSoundStyleKey));
    selectedGlobalAudioSoundStyle = _audioSoundStyle;
    _weatherAutoRefresh = await _store.getBool(_weatherAutoRefreshKey) ?? true;
    _reducedMotion = await _store.getBool(_reducedMotionKey) ?? false;

    if (notify) {
      notifyListeners();
    }
  }
}
