import 'package:flutter/material.dart';

import '../services/app_properties_store.dart';

class ProfileProvider with ChangeNotifier {
  static const String _nameKey = 'profile_name';
  static const String _imageKey = 'profile_image';

  String _userName = 'My Wallet';
  String? _imagePath;
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  String get userName => _userName;
  String? get imagePath => _imagePath;

  ProfileProvider() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await _store.ready;
    _userName = await _store.getString(_nameKey) ?? 'My Wallet';
    _imagePath = await _store.getString(_imageKey);
    notifyListeners();
  }

  Future<void> reload() async {
    await _loadProfile();
  }

  Future<void> updateProfile(String name, String? imagePath) async {
    _userName = name;
    _imagePath = imagePath;
    await _store.setString(_nameKey, name);
    if (imagePath != null) {
      await _store.setString(_imageKey, imagePath);
    } else {
      await _store.remove(_imageKey);
    }
    notifyListeners();
  }
}
