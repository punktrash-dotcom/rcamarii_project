import 'dart:io';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Import all providers
import 'providers/activity_provider.dart';
import 'providers/data_provider.dart';
import 'providers/equipment_provider.dart';
import 'providers/farm_provider.dart';
import 'providers/supplies_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/search_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/worker_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/app_audio_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/guideline_language_provider.dart';
import 'providers/sugarcane_profit_provider.dart';

import 'screens/splash_screen.dart';
import 'services/app_properties_store.dart';
import 'services/app_localization_service.dart';
import 'services/app_route_observer.dart';
import 'themes/app_visuals.dart';
import 'utils/app_layout_utils.dart';
import 'providers/ftracker_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/voice_command_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);

  // Database initialization for Desktop
  if (Platform.isAndroid || Platform.isIOS) {
    // Standard mobile path
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await AppPropertiesStore.instance.ready;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => FarmProvider()),
        ChangeNotifierProvider(create: (_) => SuppliesProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => EquipmentProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => WorkerProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
        ChangeNotifierProvider(create: (_) => SugarcaneProfitProvider()),
        ChangeNotifierProvider(create: (_) => VoiceCommandProvider()),
        ChangeNotifierProvider(create: (_) => FtrackerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => GuidelineLanguageProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProxyProvider<AppSettingsProvider, AppAudioProvider>(
          create: (_) => AppAudioProvider(),
          update: (_, appSettings, appAudio) {
            final provider = appAudio ?? AppAudioProvider();
            provider.updateVolume(appSettings.audioSoundsVolume);
            return provider;
          },
        ),
      ],
      child: Consumer3<ThemeProvider, GuidelineLanguageProvider,
          AppSettingsProvider>(
        builder:
            (context, themeProvider, languageProvider, appSettings, child) {
          final bool isDark = themeProvider.darkTheme;
          final bool reduceMotion = appSettings.reducedMotion;
          return MaterialApp(
            title: 'RCAMARii',
            debugShowCheckedModeBanner: false,
            navigatorObservers: [appRouteObserver],
            theme: AppVisuals.theme(
              isDark: isDark,
              reduceMotion: reduceMotion,
            ),
            themeAnimationDuration:
                reduceMotion ? Duration.zero : kThemeAnimationDuration,
            locale: AppLocalizationService.materialLocale(
              languageProvider.selectedLanguage,
            ),
            supportedLocales: const [
              Locale('en'),
              Locale('fil'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              if (child == null) {
                return const SizedBox.shrink();
              }

              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  disableAnimations: reduceMotion,
                  textScaler: AppLayoutUtils.clampedTextScaler(mediaQuery),
                ),
                child: child,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
