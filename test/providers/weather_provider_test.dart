import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nmd/providers/weather_provider.dart';

void main() {
  test('falls back to Open-Meteo when no API key is configured', () async {
    final requestedNames = <String>[];
    final client = MockClient((request) async {
      if (request.url.host == 'geocoding-api.open-meteo.com') {
        requestedNames.add(request.url.queryParameters['name'] ?? '');
        if (request.url.queryParameters['name'] ==
            'Bacolod, Negros Occidental') {
          return http.Response(jsonEncode({'results': []}), 200);
        }

        return http.Response(
          jsonEncode({
            'results': [
              {
                'latitude': 10.6765,
                'longitude': 122.9511,
              },
            ],
          }),
          200,
        );
      }

      if (request.url.host == 'api.open-meteo.com') {
        expect(
          request.url.queryParameters['wind_speed_unit'],
          equals('ms'),
        );
        return http.Response(
          jsonEncode({
            'current': {
              'temperature_2m': 31.2,
              'relative_humidity_2m': 74,
              'apparent_temperature': 35.1,
              'weather_code': 2,
              'cloud_cover': 42,
              'surface_pressure': 1007.4,
              'wind_speed_10m': 3.5,
              'is_day': 1,
            },
            'daily': {
              'sunrise': ['2026-03-28T05:48'],
              'sunset': ['2026-03-28T18:03'],
            },
          }),
          200,
        );
      }

      return http.Response('Not found', 404);
    });

    final provider = WeatherProvider(client: client, weatherApiKey: '');

    await provider.getWeather('Bacolod, Negros Occidental');

    expect(requestedNames, contains('Bacolod, Negros Occidental'));
    expect(requestedNames, contains('Bacolod'));
    expect(provider.error, isNull);
    expect(provider.isLoading, isFalse);
    expect(provider.weatherData, isNotNull);
    expect(provider.weatherData!.description, 'Partly cloudy');
    expect(provider.weatherData!.icon, '03d');
    expect(provider.weatherData!.windSpeed, closeTo(3.5, 0.001));
    expect(provider.weatherData!.pressure, 1007);
    expect(
      provider.weatherData!.sunrise,
      DateTime.parse('2026-03-28T05:48'),
    );
  });

  test('uses OpenWeather when an API key is configured', () async {
    var openWeatherCalls = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'api.openweathermap.org') {
        openWeatherCalls += 1;
        expect(request.url.queryParameters['q'], 'Manila');
        expect(request.url.queryParameters['appid'], 'demo-key');
        expect(request.url.queryParameters['units'], 'metric');

        return http.Response(
          jsonEncode({
            'weather': [
              {
                'description': 'light rain',
                'icon': '10d',
              },
            ],
            'main': {
              'temp': 28.5,
              'feels_like': 32.0,
              'humidity': 81,
              'pressure': 1009,
            },
            'wind': {
              'speed': 4.2,
            },
            'clouds': {
              'all': 88,
            },
            'sys': {
              'sunrise': 1711585680,
              'sunset': 1711629000,
            },
          }),
          200,
        );
      }

      return http.Response('Not found', 404);
    });

    final provider = WeatherProvider(client: client, weatherApiKey: 'demo-key');

    await provider.getWeather('Manila');

    expect(openWeatherCalls, 1);
    expect(provider.error, isNull);
    expect(provider.weatherData, isNotNull);
    expect(provider.weatherData!.description, 'light rain');
    expect(provider.weatherData!.icon, '10d');
    expect(provider.weatherData!.windSpeed, closeTo(4.2, 0.001));
  });

  test('returns a useful error when no weather match is found', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'geocoding-api.open-meteo.com') {
        return http.Response(jsonEncode({'results': []}), 200);
      }

      return http.Response('Not found', 404);
    });

    final provider = WeatherProvider(client: client, weatherApiKey: '');

    await provider.getWeather('Nowhere Farm');

    expect(provider.weatherData, isNull);
    expect(
      provider.error,
      'Unable to find a weather match for "Nowhere Farm".',
    );
  });
}
