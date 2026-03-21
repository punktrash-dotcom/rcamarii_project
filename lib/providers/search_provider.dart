import 'package:flutter/foundation.dart';

class SearchProvider with ChangeNotifier {
  String? _selectedItemId;

  String? get selectedItemId => _selectedItemId;

  void executeSearch(String itemId) {
    _selectedItemId = itemId;
    notifyListeners();
    // Reset after a short delay to allow the UI to react
    Future.delayed(const Duration(milliseconds: 500), () {
      _selectedItemId = null;
      notifyListeners();
    });
  }
}
