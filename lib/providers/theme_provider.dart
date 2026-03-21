import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const themeStatusKey = 'THEME_STATUS';
  bool _darkTheme = false;

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
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(themeStatusKey, isDark);
  }

  Future<void> _initTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _darkTheme = prefs.getBool(themeStatusKey) ?? false;

    // Safety check: ensure notifyListeners() is called after the build frame
    Future.microtask(() => notifyListeners());
  }
}
