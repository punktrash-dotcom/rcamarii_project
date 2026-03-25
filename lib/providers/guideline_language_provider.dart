import 'package:flutter/material.dart';

import '../services/guideline_localization_service.dart';
import '../services/app_properties_store.dart';

class GuidelineLanguageProvider with ChangeNotifier {
  static const String _languageKey = 'guideline_language';

  GuidelineLanguage _selectedLanguage = GuidelineLanguage.english;
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  GuidelineLanguage get selectedLanguage => _selectedLanguage;

  GuidelineLanguageProvider() {
    _loadLanguage();
  }

  Future<void> setLanguage(GuidelineLanguage language) async {
    if (_selectedLanguage == language) return;

    _selectedLanguage = language;
    notifyListeners();

    await _store.setString(_languageKey, _toCode(language));
  }

  Future<void> reload() async {
    await _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    await _store.ready;
    _selectedLanguage = _fromCode(await _store.getString(_languageKey));
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
