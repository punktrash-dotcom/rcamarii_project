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
}

class WeatherProvider extends ChangeNotifier {
  Weather? _weatherData;
  bool _isLoading = false;
  String? _error;

  Weather? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> getWeather(String city) async {
    final apiKey = AppConfig.weatherApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      _error = 'Weather API key not configured.';
      notifyListeners();
      return;
    }

    final encodedCity = Uri.encodeComponent(city);
    final baseUrl = AppConfig.weatherApiUrl;
    String url;
    if (baseUrl != null && baseUrl.contains('{city}')) {
      url = baseUrl.replaceAll('{city}', encodedCity);
    } else {
      url = 'https://api.openweathermap.org/data/2.5/weather?q=$encodedCity';
    }
    url = '$url&appid=$apiKey&units=metric';

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _weatherData = Weather.fromJson(data);
      } else {
        _error = 'Failed to load weather data: ${response.reasonPhrase}';
      }
    } catch (e) {
      _error = 'Failed to connect to the weather service.';
    }

    _isLoading = false;
    notifyListeners();
  }
}
