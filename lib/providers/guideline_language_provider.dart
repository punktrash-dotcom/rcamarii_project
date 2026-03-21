import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/guideline_localization_service.dart';

class GuidelineLanguageProvider with ChangeNotifier {
  static const String _languageKey = 'guideline_language';

  GuidelineLanguage _selectedLanguage = GuidelineLanguage.english;

  GuidelineLanguage get selectedLanguage => _selectedLanguage;

  GuidelineLanguageProvider() {
    _loadLanguage();
  }

  Future<void> setLanguage(GuidelineLanguage language) async {
    if (_selectedLanguage == language) return;

    _selectedLanguage = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, _toCode(language));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedLanguage = _fromCode(prefs.getString(_languageKey));
    notifyListeners();
  }

  static String _toCode(GuidelineLanguage language) {
    switch (language) {
      case GuidelineLanguage.english:
        return 'en';
      case GuidelineLanguage.tagalog:
        return 'tl';
      case GuidelineLanguage.visayan:
        return 'vis';
    }
  }

  static GuidelineLanguage _fromCode(String? code) {
    switch (code) {
      case 'tl':
        return GuidelineLanguage.tagalog;
      case 'vis':
        return GuidelineLanguage.visayan;
      case 'en':
      default:
        return GuidelineLanguage.english;
    }
  }
}
