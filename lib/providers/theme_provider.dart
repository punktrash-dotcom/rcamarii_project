import 'package:flutter/material.dart';

import '../services/app_properties_store.dart';

class ThemeProvider with ChangeNotifier {
  static const themeStatusKey = 'THEME_STATUS';
  bool _darkTheme = false;
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  bool get darkTheme => _darkTheme;

  ThemeProvider() {
    _initTheme();
  }

  set darkTheme(bool value) {
    if (_darkTheme == value) return;
    _darkTheme = value;
    _saveTheme(value);
    notifyListeners();
  }

  Future<void> _saveTheme(bool isDark) async {
    await _store.setBool(themeStatusKey, isDark);
  }

  Future<void> reload() async {
    await _initTheme();
  }

  Future<void> _initTheme() async {
    await _store.ready;
    _darkTheme = await _store.getBool(themeStatusKey) ?? false;

    // Safety check: ensure notifyListeners() is called after the build frame
    Future.microtask(() => notifyListeners());
  }
}
