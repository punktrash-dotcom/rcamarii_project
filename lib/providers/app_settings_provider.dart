import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  AppCurrency _currency = AppCurrency.php;
  LaunchDestination _launchDestination = LaunchDestination.hub;
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

  Future<void> setCurrency(AppCurrency value) async {
    if (_currency == value) return;
    _currency = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, value.code);
  }

  Future<void> setLaunchDestination(LaunchDestination value) async {
    if (_launchDestination == value) return;
    _launchDestination = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_launchDestinationKey, value.code);
  }

  Future<void> setVoiceAssistantEnabled(bool value) async {
    if (_voiceAssistantEnabled == value) return;
    _voiceAssistantEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceAssistantEnabledKey, value);
  }

  Future<void> setVoiceResponsesEnabled(bool value) async {
    if (_voiceResponsesEnabled == value) return;
    _voiceResponsesEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceResponsesEnabledKey, value);
  }

  Future<void> setAudioSoundsEnabled(bool value) async {
    if (_audioSoundsEnabled == value) return;
    _audioSoundsEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_audioSoundsEnabledKey, value);
  }

  Future<void> setAudioSoundsVolume(double value) async {
    if (_audioSoundsVolume == value) return;
    _audioSoundsVolume = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_audioSoundsVolumeKey, value);
  }

  Future<void> setAudioSoundStyle(AudioSoundStyle value) async {
    if (_audioSoundStyle == value) return;
    _audioSoundStyle = value;
    selectedGlobalAudioSoundStyle = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioSoundStyleKey, value.code);
  }

  Future<void> setWeatherAutoRefresh(bool value) async {
    if (_weatherAutoRefresh == value) return;
    _weatherAutoRefresh = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weatherAutoRefreshKey, value);
  }

  Future<void> setReducedMotion(bool value) async {
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reducedMotionKey, value);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    _currency = AppCurrencyX.fromCode(prefs.getString(_currencyKey));
    _launchDestination = LaunchDestinationX.fromCode(
      prefs.getString(_launchDestinationKey),
    );
    _voiceAssistantEnabled = prefs.getBool(_voiceAssistantEnabledKey) ?? true;
    _voiceResponsesEnabled = prefs.getBool(_voiceResponsesEnabledKey) ?? true;
    _audioSoundsEnabled = prefs.getBool(_audioSoundsEnabledKey) ?? false;
    _audioSoundsVolume = prefs.getDouble(_audioSoundsVolumeKey) ?? 0.75;
    _audioSoundStyle =
        AudioSoundStyleX.fromCode(prefs.getString(_audioSoundStyleKey));
    selectedGlobalAudioSoundStyle = _audioSoundStyle;
    _weatherAutoRefresh = prefs.getBool(_weatherAutoRefreshKey) ?? true;
    _reducedMotion = prefs.getBool(_reducedMotionKey) ?? false;

    notifyListeners();
  }
}
