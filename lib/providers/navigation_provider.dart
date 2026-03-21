import 'package:flutter/foundation.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  String? _farmIdToFilter;
  String? get farmIdToFilter => _farmIdToFilter;

  void changeTab(int index, {String? farmId}) {
    _currentIndex = index;
    _farmIdToFilter =
        farmId; // Store the farmId to be used by the Activities tab
    notifyListeners();
  }

  // Call this after the Activities tab has used the filter
  void clearFarmFilter() {
    _farmIdToFilter = null;
  }
}
