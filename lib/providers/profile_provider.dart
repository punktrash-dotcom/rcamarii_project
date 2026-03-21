import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider with ChangeNotifier {
  static const String _nameKey = 'profile_name';
  static const String _imageKey = 'profile_image';

  String _userName = 'My Wallet';
  String? _imagePath;

  String get userName => _userName;
  String? get imagePath => _imagePath;

  ProfileProvider() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString(_nameKey) ?? 'My Wallet';
    _imagePath = prefs.getString(_imageKey);
    notifyListeners();
  }

  Future<void> updateProfile(String name, String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    _userName = name;
    _imagePath = imagePath;
    await prefs.setString(_nameKey, name);
    if (imagePath != null) {
      await prefs.setString(_imageKey, imagePath);
    } else {
      await prefs.remove(_imageKey);
    }
    notifyListeners();
  }
}
