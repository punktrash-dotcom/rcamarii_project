import 'package:flutter/foundation.dart';

import '../models/farm_income_model.dart';
import '../services/database_helper.dart';

class FarmIncomeProvider with ChangeNotifier {
  List<FarmIncome> _records = [];
  bool _isLoading = false;
  String? _error;

  List<FarmIncome> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRecords() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query(
        DatabaseHelper.tableFarmIncome,
        orderBy: 'Date DESC, CreatedAt DESC',
      );
      _records = data.map(FarmIncome.fromMap).toList();
    } catch (e) {
      _error = 'Failed to load farm income records.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
