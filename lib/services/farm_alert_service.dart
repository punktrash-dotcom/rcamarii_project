import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../models/farm_model.dart';
import '../models/schedule_alert_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import 'app_properties_store.dart';
import 'farm_operations_service.dart';
import 'farming_advice_service.dart';

class FarmAlertService {
  FarmAlertService._();

  static final FarmAlertService instance = FarmAlertService._();

  static const String _channelId = 'farm_alerts';
  static const String _channelName = 'Farm Alerts';
  static const String _channelDescription =
      'Operational alerts and recommendations for farm work windows.';
  static const String _androidSoundName = 'farm_alert';
  static const int _notificationId = 41001;
  static const String _lastDigestKey = 'farm_alerts.last_digest';
  static const String _lastSentAtKey = 'farm_alerts.last_sent_at';
  static const String _latestAlarmPayloadKey = 'farm_alerts.latest_payload';
  static const String _pendingAlarmOpenKey = 'farm_alerts.pending_open';
  static const String _mutedDateKey = 'farm_alerts.muted_date';
  static const String _alertSoundAssetPath = 'lib/assets/audio/funny_farm.wav';
  static const Duration _repeatWindow = Duration(hours: 12);

  final AppPropertiesStore _store = AppPropertiesStore.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _syncInProgress = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (response) async {
        await _handleNotificationTap(response.payload);
      },
    );

    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      await _handleNotificationTap(launchDetails?.notificationResponse?.payload);
    }

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_androidSoundName),
      ),
    );

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macOsPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    await macOsPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
  }

  Future<void> syncFromContext(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_syncInProgress) {
      return;
    }

    _syncInProgress = true;

    try {
      final appSettings =
          Provider.of<AppSettingsProvider?>(context, listen: false);
      final farmProvider = Provider.of<FarmProvider?>(context, listen: false);
      final appAudio = Provider.of<AppAudioProvider?>(context, listen: false);

      if (appSettings == null || farmProvider == null) {
        return;
      }

      await initialize();

      await appSettings.ready;
      if (!appSettings.farmAlertsEnabled) {
        return;
      }
      if (await isMutedForToday()) {
        return;
      }

      if (farmProvider.farms.isEmpty && !farmProvider.isLoading) {
        await farmProvider.refreshFarms();
      }

      final farms = List<Farm>.from(farmProvider.farms);
      if (farms.isEmpty) {
        return;
      }

      final alerts = await _buildAlerts(
        farms,
        weatherAutoRefresh: appSettings.weatherAutoRefresh,
      );
      if (alerts.isEmpty) {
        return;
      }

      final digest = _buildDigest(alerts);
      final lastDigest = await _store.getString(_lastDigestKey) ?? '';
      final lastSentRaw = await _store.getString(_lastSentAtKey);
      final lastSentAt =
          lastSentRaw == null ? null : DateTime.tryParse(lastSentRaw);
      final now = DateTime.now();
      final shouldNotify = force ||
          digest != lastDigest ||
          lastSentAt == null ||
          now.difference(lastSentAt) >= _repeatWindow;

      if (!shouldNotify) {
        return;
      }

      await _showNotification(alerts);
      if (appSettings.audioSoundsEnabled) {
        await appAudio?.playAsset(
          assetPath: _alertSoundAssetPath,
          enabled: true,
        );
      }

      await _store.setString(_lastDigestKey, digest);
      await _store.setString(_lastSentAtKey, now.toIso8601String());
    } finally {
      _syncInProgress = false;
    }
  }

  Future<FarmAlertCardData?> consumePendingAlarmCard() async {
    await initialize();
    final pending = await _store.getBool(_pendingAlarmOpenKey) ?? false;
    final payload = await latestAlarmCard();
    if (pending) {
      await _store.setBool(_pendingAlarmOpenKey, false);
    }
    return pending ? payload : null;
  }

  Future<FarmAlertCardData?> latestAlarmCard() async {
    await initialize();
    final raw = await _store.getString(_latestAlarmPayloadKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return FarmAlertCardData.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> hasAlarmCard() async {
    return (await latestAlarmCard()) != null;
  }

  Future<bool> isMutedForToday() async {
    final stored = await _store.getString(_mutedDateKey);
    final today = _dateOnly(DateTime.now()).toIso8601String();
    return stored == today;
  }

  Future<void> muteAlertsForToday() async {
    final today = _dateOnly(DateTime.now()).toIso8601String();
    await _store.setString(_mutedDateKey, today);
    await _store.setBool(_pendingAlarmOpenKey, false);
    await _notifications.cancel(_notificationId);
  }

  Future<void> clearPendingAlarmCard() async {
    await _store.setBool(_pendingAlarmOpenKey, false);
  }

  Future<List<_FarmAlertRecommendation>> _buildAlerts(
    List<Farm> farms, {
    required bool weatherAutoRefresh,
  }) async {
    final sortedFarms = List<Farm>.from(farms)
      ..sort((left, right) => left.name.compareTo(right.name));
    final weatherByLocation = <String, Weather?>{};

    if (weatherAutoRefresh) {
      final uniqueLocations = sortedFarms
          .map(_locationForFarm)
          .where((location) => location.isNotEmpty)
          .toSet()
          .toList(growable: false);

      for (final location in uniqueLocations) {
        weatherByLocation[location] = await _fetchWeather(location);
      }
    }

    final results = <_FarmAlertRecommendation>[];
    for (final farm in sortedFarms) {
      final ageInDays = FarmOperationsService.cropAgeInDays(farm.date);
      final operationalAlerts = _dedupeScheduleAlerts([
        ...FarmingAdviceService.getAdviceForCrop(
          farm.type.trim().toLowerCase(),
          ageInDays,
        ),
        ...FarmOperationsService.inputAlertsForCrop(farm.type, ageInDays),
      ]);

      for (final alert in operationalAlerts.take(2)) {
        results.add(
          _FarmAlertRecommendation(
            farmId: farm.id ?? farm.name,
            farmName: farm.name,
            cropType: farm.type,
            title: alert.title,
            message: alert.message,
            priority: _priorityForAlert(alert, ageInDays),
          ),
        );
      }

      final weatherAlert = _buildWeatherAlert(
        farm,
        ageInDays,
        weatherByLocation[_locationForFarm(farm)],
      );
      if (weatherAlert != null) {
        results.add(weatherAlert);
      }

      final daysUntilHarvest = FarmOperationsService.daysUntilHarvest(farm);
      if (daysUntilHarvest >= 0 && daysUntilHarvest <= 21) {
        results.add(
          _FarmAlertRecommendation(
            farmId: farm.id ?? farm.name,
            farmName: farm.name,
            cropType: farm.type,
            title: 'Harvest readiness',
            message:
                'Harvest is within $daysUntilHarvest days. Confirm labor, trucking, and field access before the cutting window tightens.',
            priority: 94,
          ),
        );
      }
    }

    results.sort((left, right) {
      final priorityCompare = right.priority.compareTo(left.priority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      final farmCompare = left.farmName.compareTo(right.farmName);
      if (farmCompare != 0) {
        return farmCompare;
      }
      return left.title.compareTo(right.title);
    });

    return _dedupeRecommendations(results).take(5).toList(growable: false);
  }

  Future<Weather?> _fetchWeather(String location) async {
    try {
      final provider = WeatherProvider();
      await provider.getWeather(location);
      return provider.weatherData;
    } catch (_) {
      return null;
    }
  }

  String _locationForFarm(Farm farm) {
    final parts = [
      farm.city.trim(),
      farm.province.trim(),
    ].where((part) => part.isNotEmpty).toList(growable: false);
    return parts.join(', ');
  }

  List<ScheduleAlert> _dedupeScheduleAlerts(List<ScheduleAlert> alerts) {
    final seen = <String>{};
    final results = <ScheduleAlert>[];
    for (final alert in alerts) {
      final key = '${alert.title}|${alert.startDay}|${alert.endDay}';
      if (seen.add(key)) {
        results.add(alert);
      }
    }
    return results;
  }

  int _priorityForAlert(ScheduleAlert alert, int ageInDays) {
    final insideWindow = ageInDays >= alert.startDay && ageInDays <= alert.endDay;
    final base = insideWindow ? 80 : 60;
    if (alert.title.toLowerCase().contains('harvest')) {
      return base + 10;
    }
    if (alert.title.toLowerCase().contains('fertilizer') ||
        alert.title.toLowerCase().contains('nitrogen') ||
        alert.title.toLowerCase().contains('herbicide')) {
      return base + 8;
    }
    return base;
  }

  _FarmAlertRecommendation? _buildWeatherAlert(
    Farm farm,
    int ageInDays,
    Weather? weather,
  ) {
    if (weather == null) {
      return null;
    }

    final crop = farm.type.toLowerCase();
    final description = weather.description.toLowerCase();
    final rainRisk = description.contains('rain') ||
        description.contains('shower') ||
        description.contains('drizzle') ||
        description.contains('storm') ||
        description.contains('thunder') ||
        weather.cloudiness >= 70 ||
        weather.humidity >= 85;

    if (rainRisk) {
      final message = switch (true) {
        _ when crop.contains('sugar') && ageInDays >= 20 && ageInDays <= 120 =>
          'Rain risk is elevated. Delay herbicide or foliar work until leaves dry, protect fertilizer bands from runoff, and keep furrow drainage open.',
        _ when crop.contains('sugar') && ageInDays >= 250 =>
          'Rain risk is elevated during ripening. Avoid late Nitrogen, protect haul roads, and confirm cutting only when trucks can enter safely.',
        _ when crop.contains('rice') =>
          'Rain risk is elevated. Hold sprays that need dry leaf contact, reinforce drainage, and inspect standing water before the next field pass.',
        _ when crop.contains('corn') =>
          'Rain risk is elevated. Delay foliar or herbicide application, open drainage, and inspect stalk stability after the weather shift.',
        _ =>
          'Weather pressure is building. Delay spray work that needs dry coverage and inspect drainage before crews re-enter the field.',
      };

      return _FarmAlertRecommendation(
        farmId: farm.id ?? farm.name,
        farmName: farm.name,
        cropType: farm.type,
        title: 'Rain and disease risk',
        message: message,
        priority: 98,
      );
    }

    final irrigationNeed = FarmOperationsService.irrigationNeed(
      farm.type,
      ageInDays,
      temperatureC: weather.temp,
      humidity: weather.humidity,
    );
    if (irrigationNeed >= 0.78) {
      return _FarmAlertRecommendation(
        farmId: farm.id ?? farm.name,
        farmName: farm.name,
        cropType: farm.type,
        title: 'Irrigation attention',
        message:
            'Water demand is high under the current weather. Confirm the next irrigation cycle and field moisture before stress affects growth.',
        priority: 88,
      );
    }

    return null;
  }

  List<_FarmAlertRecommendation> _dedupeRecommendations(
    List<_FarmAlertRecommendation> alerts,
  ) {
    final seen = <String>{};
    final results = <_FarmAlertRecommendation>[];
    for (final alert in alerts) {
      final key = '${alert.farmId}|${alert.title}|${alert.message}';
      if (seen.add(key)) {
        results.add(alert);
      }
    }
    return results;
  }

  String _buildDigest(List<_FarmAlertRecommendation> alerts) {
    return jsonEncode(
      alerts
          .map(
            (alert) => <String, String>{
              'farmId': alert.farmId,
              'title': alert.title,
              'message': alert.message,
            },
          )
          .toList(growable: false),
    );
  }

  Future<void> _showNotification(
    List<_FarmAlertRecommendation> alerts,
  ) async {
    final payload = FarmAlertCardData._fromRecommendations(alerts);
    final title = alerts.length == 1
        ? '${alerts.first.farmName}: ${alerts.first.title}'
        : '${alerts.length} farm alerts need attention';
    final lines = alerts
        .take(3)
        .map((alert) => '${alert.farmName}: ${alert.title}')
        .toList(growable: false);
    final body = lines.join('\n');

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(_androidSoundName),
      styleInformation: BigTextStyleInformation(
        payload.detail,
        summaryText: title,
      ),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _store.setString(_latestAlarmPayloadKey, jsonEncode(payload.toJson()));

    await _notifications.show(
      _notificationId,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(payload.toJson()),
    );
  }

  Future<void> _handleNotificationTap(String? payload) async {
    if (payload != null && payload.trim().isNotEmpty) {
      await _store.setString(_latestAlarmPayloadKey, payload);
    }
    await _store.setBool(_pendingAlarmOpenKey, true);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _FarmAlertRecommendation {
  const _FarmAlertRecommendation({
    required this.farmId,
    required this.farmName,
    required this.cropType,
    required this.title,
    required this.message,
    required this.priority,
  });

  final String farmId;
  final String farmName;
  final String cropType;
  final String title;
  final String message;
  final int priority;
}

class FarmAlertCardData {
  const FarmAlertCardData({
    required this.title,
    required this.summary,
    required this.detail,
    required this.items,
    required this.createdAt,
  });

  factory FarmAlertCardData._fromRecommendations(
    List<_FarmAlertRecommendation> alerts,
  ) {
    final primary = alerts.first;
    final title = alerts.length == 1
        ? '${primary.farmName}: ${primary.title}'
        : '${alerts.length} farm alarms need attention';
    final summary = alerts.length == 1
        ? primary.message
        : 'Open these alerts and review the recommended field actions for today.';
    final detail = alerts
        .take(5)
        .map((alert) => '${alert.farmName}: ${alert.title}\n${alert.message}')
        .join('\n\n');
    return FarmAlertCardData(
      title: title,
      summary: summary,
      detail: detail,
      items: alerts
          .map(
            (alert) => FarmAlertItem(
              farmName: alert.farmName,
              cropType: alert.cropType,
              title: alert.title,
              message: alert.message,
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.now(),
    );
  }

  factory FarmAlertCardData.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return FarmAlertCardData(
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(FarmAlertItem.fromJson)
          .toList(growable: false),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String title;
  final String summary;
  final String detail;
  final List<FarmAlertItem> items;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'summary': summary,
      'detail': detail,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class FarmAlertItem {
  const FarmAlertItem({
    required this.farmName,
    required this.cropType,
    required this.title,
    required this.message,
  });

  factory FarmAlertItem.fromJson(Map<String, dynamic> json) {
    return FarmAlertItem(
      farmName: (json['farmName'] ?? '').toString(),
      cropType: (json['cropType'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }

  final String farmName;
  final String cropType;
  final String title;
  final String message;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'farmName': farmName,
      'cropType': cropType,
      'title': title,
      'message': message,
    };
  }
}
