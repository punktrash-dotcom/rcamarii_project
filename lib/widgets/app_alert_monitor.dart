import 'dart:async';

import 'package:flutter/material.dart';

import '../services/farm_alert_service.dart';

class AppAlertMonitor extends StatefulWidget {
  const AppAlertMonitor({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppAlertMonitor> createState() => _AppAlertMonitorState();
}

class _AppAlertMonitorState extends State<AppAlertMonitor>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(FarmAlertService.instance.syncFromContext(context));
      _timer = Timer.periodic(const Duration(minutes: 30), (_) {
        if (!mounted) {
          return;
        }
        unawaited(FarmAlertService.instance.syncFromContext(context));
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(FarmAlertService.instance.syncFromContext(context));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
