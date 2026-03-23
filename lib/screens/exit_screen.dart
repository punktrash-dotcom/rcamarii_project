import 'dart:async';
import 'package:flutter/material.dart';

import '../themes/app_visuals.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/app_route_observer.dart';

class ExitScreen extends StatefulWidget {
  const ExitScreen({super.key});

  @override
  State<ExitScreen> createState() => _ExitScreenState();
}

class _ExitScreenState extends State<ExitScreen> with RouteAware {
  bool _isRouteObserverSubscribed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playScreenOpenAudioIfNeeded();
    });
    Timer(const Duration(seconds: 3), () => SystemNavigator.pop());
  }

  Future<void> _playScreenOpenAudioIfNeeded() async {
    if (!mounted) {
      return;
    }
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    await context.read<AppAudioProvider>().playScreenOpenSound(
          screenKey: 'exit',
          style: appSettings.audioSoundStyle,
          enabled: appSettings.audioSoundsEnabled,
        );
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    await context.read<AppAudioProvider>().stopScreenOpenSound(
          screenKey: 'exit',
          style: appSettings.audioSoundStyle,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopScreenOpenAudioIfNeeded());
    super.dispose();
  }

  @override
  void didPushNext() {
    unawaited(_stopScreenOpenAudioIfNeeded());
  }

  @override
  void didPop() {
    unawaited(_stopScreenOpenAudioIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // STRETCHED BACKGROUND IMAGE
          Image.asset(
            'lib/assets/splak_screen.jpg',
            fit: BoxFit.fill, // Stretches to fill the whole screen
          ),
          Container(color: Colors.black.withValues(alpha: 0.28)),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'TERMINATING SESSION',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppVisuals.textForest,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Securing your data and agricultural assets...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppVisuals.textForestMuted,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 60),
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppVisuals.textForest),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
