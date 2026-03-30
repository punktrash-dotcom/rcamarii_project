import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/app_config.dart';

class Weather {
  final double temp;
  final String description;
  final String icon;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int pressure;
  final int cloudiness;
  final DateTime? sunrise;
  final DateTime? sunset;

  Weather({
    required this.temp,
    required this.description,
    required this.icon,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.cloudiness,
    this.sunrise,
    this.sunset,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    final main = (json['main'] as Map<String, dynamic>?) ?? {};
    final wind = (json['wind'] as Map<String, dynamic>?) ?? {};
    final clouds = (json['clouds'] as Map<String, dynamic>?) ?? {};
    final sys = (json['sys'] as Map<String, dynamic>?) ?? {};

    double parseDouble(dynamic value) => value is num ? value.toDouble() : 0.0;
    int parseInt(dynamic value) => value is num ? value.toInt() : 0;
    DateTime? parseDateTime(dynamic value) {
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000,
                isUtc: true)
            .toLocal();
      }
      return null;
    }

    final weatherList = (json['weather'] as List<dynamic>?) ?? [];
    final weatherItem = weatherList.isNotEmpty
        ? (weatherList.first as Map<String, dynamic>)
        : <String, dynamic>{};

    return Weather(
      temp: parseDouble(main['temp']),
      description: weatherItem['description'] ?? 'N/A',
      icon: weatherItem['icon'] ?? '01d',
      feelsLike: parseDouble(main['feels_like']),
      humidity: parseInt(main['humidity']),
      windSpeed: parseDouble(wind['speed']),
      pressure: parseInt(main['pressure']),
      cloudiness: parseInt(clouds['all']),
      sunrise: parseDateTime(sys['sunrise']),
      sunset: parseDateTime(sys['sunset']),
    );
  }

  factory Weather.fromOpenMeteoJson(Map<String, dynamic> json) {
    final current = (json['current'] as Map<String, dynamic>?) ?? {};
    final daily = (json['daily'] as Map<String, dynamic>?) ?? {};

    double parseDouble(dynamic value) => value is num ? value.toDouble() : 0.0;
    int parseInt(dynamic value) => value is num ? value.toInt() : 0;
    DateTime? parseDailyDate(String key) {
      final values = daily[key];
      if (values is List && values.isNotEmpty && values.first is String) {
        return DateTime.tryParse(values.first as String);
      }
      return null;
    }

    final weatherCode = parseInt(current['weather_code']);
    final isDay = parseInt(current['is_day']) != 0;

    return Weather(
      temp: parseDouble(current['temperature_2m']),
      description: _OpenMeteoWeatherCode.description(weatherCode),
      icon: _OpenMeteoWeatherCode.icon(weatherCode, isDay: isDay),
      feelsLike: parseDouble(current['apparent_temperature']),
      humidity: parseInt(current['relative_humidity_2m']),
      windSpeed: parseDouble(current['wind_speed_10m']),
      pressure: parseInt(current['surface_pressure']),
      cloudiness: parseInt(current['cloud_cover']),
      sunrise: parseDailyDate('sunrise'),
      sunset: parseDailyDate('sunset'),
    );
  }
}

class WeatherProvider extends ChangeNotifier {
  WeatherProvider({
    http.Client? client,
    String? weatherApiKey,
    String? weatherApiUrl,
  })  : _client = client ?? http.Client(),
        _weatherApiKeyOverride = weatherApiKey,
        _weatherApiUrlOverride = weatherApiUrl;

  final http.Client _client;
  final String? _weatherApiKeyOverride;
  final String? _weatherApiUrlOverride;

  Weather? _weatherData;
  bool _isLoading = false;
  String? _error;

  Weather? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> getWeather(String city) async {
    final location = city.trim();
    if (location.isEmpty) {
      _weatherData = null;
      _error = 'Enter a location first.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final apiKey =
          (_weatherApiKeyOverride ?? AppConfig.weatherApiKey)?.trim();
      String? openWeatherError;

      if (apiKey != null && apiKey.isNotEmpty) {
        try {
          _weatherData = await _fetchOpenWeather(location, apiKey);
        } on _WeatherFetchException catch (error) {
          openWeatherError = error.message;
        }
      }

      if (_weatherData == null) {
        try {
          _weatherData = await _fetchOpenMeteo(location);
        } on _WeatherFetchException catch (error) {
          _weatherData = null;
          _error = openWeatherError ?? error.message;
        }
      }
    } catch (e) {
      _weatherData = null;
      _error = 'Failed to connect to the weather service.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Weather> _fetchOpenWeather(String location, String apiKey) async {
    final baseUrl = (_weatherApiUrlOverride ?? AppConfig.weatherApiUrl)?.trim();
    final rawUrl = (baseUrl != null && baseUrl.isNotEmpty)
        ? baseUrl
        : 'https://api.openweathermap.org/data/2.5/weather';
    final uri = _buildOpenWeatherUri(rawUrl, location, apiKey);
    final json = await _getJson(uri);
    return Weather.fromJson(json);
  }

  Uri _buildOpenWeatherUri(String rawUrl, String location, String apiKey) {
    final templateUrl = rawUrl.contains('{city}')
        ? rawUrl.replaceAll('{city}', Uri.encodeComponent(location))
        : rawUrl;
    final uri = Uri.parse(templateUrl);
    final queryParameters = Map<String, String>.from(uri.queryParameters);

    queryParameters.putIfAbsent('q', () => location);
    queryParameters['appid'] = apiKey;
    queryParameters.putIfAbsent('units', () => 'metric');

    return uri.replace(queryParameters: queryParameters);
  }

  Future<Weather> _fetchOpenMeteo(String location) async {
    final resolvedLocation = await _resolveOpenMeteoLocation(location);
    final forecastUri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '${resolvedLocation.latitude}',
        'longitude': '${resolvedLocation.longitude}',
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,cloud_cover,surface_pressure,wind_speed_10m,is_day',
        'daily': 'sunrise,sunset',
        'forecast_days': '1',
        'timezone': 'auto',
        'wind_speed_unit': 'ms',
      },
    );
    final json = await _getJson(forecastUri);
    return Weather.fromOpenMeteoJson(json);
  }

  Future<_ResolvedLocation> _resolveOpenMeteoLocation(String location) async {
    final attempts = _locationSearchAttempts(location);

    for (final attempt in attempts) {
      final uri = Uri.https(
        'geocoding-api.open-meteo.com',
        '/v1/search',
        {
          'name': attempt,
          'count': '1',
          'language': 'en',
          'format': 'json',
          if (!_containsCountryName(attempt)) 'countryCode': 'PH',
        },
      );
      final json = await _getJson(uri, allowEmptyResults: true);
      final results = (json['results'] as List<dynamic>?) ?? const [];
      if (results.isEmpty) {
        continue;
      }
      final first = results.first;
      if (first is Map<String, dynamic>) {
        final latitude = first['latitude'];
        final longitude = first['longitude'];
        if (latitude is num && longitude is num) {
          return _ResolvedLocation(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          );
        }
      }
    }

    throw _WeatherFetchException(
      'Unable to find a weather match for "$location".',
    );
  }

  List<String> _locationSearchAttempts(String location) {
    final attempts = <String>{location};
    final parts = location
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isNotEmpty) {
      attempts.add(parts.first);
      if (parts.length > 1) {
        attempts.add('${parts.first}, Philippines');
      }
    }

    if (!_containsCountryName(location)) {
      attempts.add('$location, Philippines');
    }

    return attempts.toList();
  }

  bool _containsCountryName(String location) {
    return location.toLowerCase().contains('philippines');
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    bool allowEmptyResults = false,
  }) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw _WeatherFetchException(
        'Weather request failed (${response.statusCode}).',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw _WeatherFetchException('Weather service returned invalid data.');
    }

    if (!allowEmptyResults && decoded['error'] == true) {
      throw _WeatherFetchException(
        (decoded['reason'] as String?)?.trim().isNotEmpty == true
            ? decoded['reason'] as String
            : 'Weather service returned an error.',
      );
    }

    return decoded;
  }
}

class _ResolvedLocation {
  const _ResolvedLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class _WeatherFetchException implements Exception {
  const _WeatherFetchException(this.message);

  final String message;
}

class _OpenMeteoWeatherCode {
  static String description(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with hail';
      default:
        return 'Weather unavailable';
    }
  }

  static String icon(int code, {required bool isDay}) {
    final suffix = isDay ? 'd' : 'n';

    if (code == 0) {
      return '01$suffix';
    }
    if (code == 1) {
      return '02$suffix';
    }
    if (code == 2) {
      return '03$suffix';
    }
    if (code == 3) {
      return '04$suffix';
    }
    if (code == 45 || code == 48) {
      return '50$suffix';
    }
    if ({51, 53, 55, 56, 57}.contains(code)) {
      return '09$suffix';
    }
    if ({61, 63, 65, 66, 67, 80, 81, 82}.contains(code)) {
      return '10$suffix';
    }
    if ({71, 73, 75, 77, 85, 86}.contains(code)) {
      return '13$suffix';
    }
    if ({95, 96, 99}.contains(code)) {
      return '11$suffix';
    }
    return '03$suffix';
  }
}
