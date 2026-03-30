import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/providers/activity_provider.dart';
import 'package:nmd/providers/app_settings_provider.dart';
import 'package:nmd/providers/delivery_provider.dart';
import 'package:nmd/providers/equipment_provider.dart';
import 'package:nmd/providers/farm_provider.dart';
import 'package:nmd/providers/guideline_language_provider.dart';
import 'package:nmd/providers/supplies_provider.dart';
import 'package:nmd/providers/theme_provider.dart';
import 'package:nmd/providers/weather_provider.dart';
import 'package:nmd/screens/scr_msoft.dart';
import 'package:nmd/themes/app_visuals.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'ScrMSoft action deck reflows instead of overflowing on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(1.6),
          ),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<AppSettingsProvider>(
                create: (_) => AppSettingsProvider(),
              ),
              ChangeNotifierProvider<GuidelineLanguageProvider>(
                create: (_) => GuidelineLanguageProvider(),
              ),
              ChangeNotifierProvider<ThemeProvider>(
                create: (_) => ThemeProvider(),
              ),
              ChangeNotifierProvider<FarmProvider>(
                create: (_) => _FakeFarmProvider(),
              ),
              ChangeNotifierProvider<EquipmentProvider>(
                create: (_) => _FakeEquipmentProvider(),
              ),
              ChangeNotifierProvider<ActivityProvider>(
                create: (_) => _FakeActivityProvider(),
              ),
              ChangeNotifierProvider<SuppliesProvider>(
                create: (_) => _FakeSuppliesProvider(),
              ),
              ChangeNotifierProvider<DeliveryProvider>(
                create: (_) => _FakeDeliveryProvider(),
              ),
              ChangeNotifierProvider<WeatherProvider>(
                create: (_) => _FakeWeatherProvider(),
              ),
            ],
            child: MaterialApp(
              theme: AppVisuals.theme(isDark: false),
              home: const ScrMSoft(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Action Deck'), findsOneWidget);
      expect(find.text('Profit Tools'), findsOneWidget);

      final actionDeckLabelLefts = [
        tester.getTopLeft(find.text('Estate')).dx,
        tester.getTopLeft(find.text('Tracker')).dx,
        tester.getTopLeft(find.text('Profit Tools')).dx,
        tester.getTopLeft(find.text('Crew panel')).dx,
      ].map((value) => value.round()).toSet();

      expect(actionDeckLabelLefts.length, 2);
    },
  );
}

class _FakeFarmProvider extends FarmProvider {
  @override
  Future<void> refreshFarms() async {}
}

class _FakeActivityProvider extends ActivityProvider {
  @override
  Future<void> loadActivities() async {}
}

class _FakeEquipmentProvider extends EquipmentProvider {
  @override
  Future<void> loadEquipment() async {}
}

class _FakeSuppliesProvider extends SuppliesProvider {
  @override
  Future<void> loadSupplies() async {}
}

class _FakeDeliveryProvider extends DeliveryProvider {
  @override
  Future<void> loadDeliveries() async {}
}

class _FakeWeatherProvider extends WeatherProvider {
  @override
  Future<void> getWeather(String city) async {}
}
