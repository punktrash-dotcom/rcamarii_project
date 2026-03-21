import 'platform_env.dart' if (dart.library.io) 'platform_env_io.dart';

class AppConfig {
  static const String _weatherApiKeyDefine =
      String.fromEnvironment('WEATHER_API_KEY');
  static const String _weatherApiUrlDefine =
      String.fromEnvironment('WEATHER_API_URL');

  static String? get weatherApiKey => _firstNonEmpty([
        _weatherApiKeyDefine,
        readPlatformEnv('WEATHER_API_KEY'),
      ]);

  static String? get weatherApiUrl => _firstNonEmpty([
        _weatherApiUrlDefine,
        readPlatformEnv('WEATHER_API_URL'),
      ]);

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}
