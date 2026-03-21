import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';

class ScrWeather extends StatefulWidget {
  const ScrWeather({super.key});

  @override
  State<ScrWeather> createState() => _ScrWeatherState();
}

class _ScrWeatherState extends State<ScrWeather> {
  final FocusNode _focusNode = FocusNode();
  String _currentLocation = 'Philippines';

  Future<void> _refreshWeather() async {
    await Provider.of<WeatherProvider>(context, listen: false)
        .getWeather(_currentLocation);
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Navigator.pop(context);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appSettings =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final farmProvider = Provider.of<FarmProvider>(context, listen: false);
      final weatherProvider =
          Provider.of<WeatherProvider>(context, listen: false);

      String location = 'Philippines';
      if (farmProvider.selectedFarm != null) {
        location =
            '${farmProvider.selectedFarm!.city}, ${farmProvider.selectedFarm!.province}';
      }

      if (mounted) {
        setState(() {
          _currentLocation = location;
        });
      }

      if (appSettings.weatherAutoRefresh) {
        weatherProvider.getWeather(location);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final theme = Theme.of(context);
    const accentColor = Color(0xFFB4F5A4);
    final hasData =
        !weatherProvider.isLoading && weatherProvider.weatherData != null;
    final reduceMotion = appSettings.reducedMotion;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: accentColor),
        title: const Text('Weather Intelligence',
            style: TextStyle(color: accentColor, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: accentColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _refreshWeather,
            icon: const Icon(Icons.refresh_rounded, color: accentColor),
            tooltip: 'Refresh weather',
          ),
        ],
      ),
      body: Focus(
        focusNode: _focusNode,
        child: AnimatedContainer(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: hasData
                  ? [
                      accentColor.withValues(alpha: 0.32),
                      accentColor.withValues(alpha: 0.16),
                      theme.colorScheme.surface
                    ]
                  : [theme.colorScheme.surface, theme.colorScheme.surface],
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildBodyContent(
                weatherProvider,
                accentColor,
                appSettings.weatherAutoRefresh,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(
    WeatherProvider provider,
    Color accentColor,
    bool autoRefreshEnabled,
  ) {
    if (provider.isLoading) {
      return _buildLoadingIndicator(accentColor);
    }

    if (provider.weatherData != null) {
      return _buildWeatherDetails(provider.weatherData!, accentColor);
    }

    if (provider.error != null) {
      return _buildErrorMessage(provider.error, accentColor);
    }

    return _buildEmptyMessage(accentColor, autoRefreshEnabled);
  }

  Widget _buildWeatherDetails(Weather weather, Color accentColor) {
    final iconUrl = 'https://openweathermap.org/img/wn/${weather.icon}@4x.png';
    final moodText = _describeWeatherMood(weather);
    final nextUpdate = DateFormat('h:mm a')
        .format(DateTime.now().add(const Duration(minutes: 15)));
    final humidityProgress = weather.humidity / 100;
    final cloudProgress = weather.cloudiness / 100;
    final windProgress = (weather.windSpeed / 20).clamp(0.0, 1.0);
    final windKmh = weather.windSpeed * 3.6;

    return Column(
      key: const ValueKey('weather-content'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_currentLocation,
            style: TextStyle(
                color: accentColor.withValues(alpha: 0.95),
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text("Updated ${DateFormat('MMM dd, h:mm a').format(DateTime.now())}",
            style: TextStyle(
                color: accentColor.withValues(alpha: 0.7),
                fontSize: 12,
                letterSpacing: 0.5)),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          key: const ValueKey('temperature'),
          tween: Tween(begin: 0.0, end: weather.temp),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Text('${value.toStringAsFixed(1)}°C',
                style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: accentColor));
          },
        ),
        const SizedBox(height: 10),
        Text(weather.description.toUpperCase(),
            style: TextStyle(
                color: accentColor.withValues(alpha: 0.9),
                letterSpacing: 2,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        TweenAnimationBuilder<double>(
          key: const ValueKey('icon-scale'),
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Image.network(iconUrl,
              width: 120,
              height: 120,
              color: accentColor,
              colorBlendMode: BlendMode.modulate),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
                'Feels Like',
                '${weather.feelsLike.toStringAsFixed(1)}°C',
                Icons.thermostat,
                accentColor),
            _buildMetricCard('Humidity', '${weather.humidity}%',
                Icons.water_drop, accentColor),
            _buildMetricCard(
                'Wind',
                '${(weather.windSpeed * 3.6).toStringAsFixed(1)} km/h',
                Icons.air,
                accentColor),
            _buildMetricCard('Pressure', '${weather.pressure} hPa', Icons.speed,
                accentColor),
            _buildMetricCard('Cloud Cover', '${weather.cloudiness}%',
                Icons.cloud, accentColor),
            if (weather.sunrise != null)
              _buildMetricCard(
                  'Sunrise',
                  DateFormat('h:mm a').format(weather.sunrise!),
                  Icons.wb_sunny,
                  accentColor),
            if (weather.sunset != null)
              _buildMetricCard(
                  'Sunset',
                  DateFormat('h:mm a').format(weather.sunset!),
                  Icons.nights_stay,
                  accentColor),
          ],
        ),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 950),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 12),
                child: child,
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressMeter('Humidity comfort', '${weather.humidity}%',
                  humidityProgress, accentColor),
              _buildProgressMeter('Cloud cover', '${weather.cloudiness}%',
                  cloudProgress, accentColor),
              _buildProgressMeter(
                  'Wind strength',
                  '${windKmh.toStringAsFixed(1)} km/h',
                  windProgress,
                  accentColor),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.eco_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      moodText,
                      style: TextStyle(
                          color: accentColor.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Next refresh ~ $nextUpdate',
                style: TextStyle(
                    color: accentColor.withValues(alpha: 0.6), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color accentColor) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: accentColor.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildProgressMeter(
      String label, String value, double progress, Color accentColor) {
    final clamped = progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: accentColor.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 5,
              color: accentColor,
              backgroundColor: accentColor.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  String _describeWeatherMood(Weather weather) {
    if (weather.temp >= 32) {
      return 'Heat persists—hydrate crews and keep shades ready.';
    }
    if (weather.cloudiness > 70) {
      return 'Cloud cover thickens; expect lingering dampness.';
    }
    if (weather.windSpeed > 9) {
      return 'Gusty winds—secure loose gear before fieldwork.';
    }
    return 'Skies look steady. Keep monitoring the next update.';
  }

  Widget _buildLoadingIndicator(Color accentColor) {
    return Column(
      key: const ValueKey('weather-loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
        const SizedBox(height: 12),
        Text('Fetching the latest weather report...',
            style: TextStyle(color: accentColor.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _buildErrorMessage(String? error, Color accentColor) {
    return Column(
      key: const ValueKey('weather-error'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: accentColor, size: 64),
        const SizedBox(height: 10),
        Text(error ?? 'Unable to fetch weather data for this location.',
            textAlign: TextAlign.center,
            style: TextStyle(color: accentColor.withValues(alpha: 0.85))),
      ],
    );
  }

  Widget _buildEmptyMessage(Color accentColor, bool autoRefreshEnabled) {
    final message = autoRefreshEnabled
        ? 'Weather data is waiting for the first sync.'
        : 'Weather auto refresh is off. Tap refresh to load the latest report.';

    return Column(
      key: const ValueKey('weather-empty'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_sync_outlined, color: accentColor, size: 64),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: accentColor.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}
