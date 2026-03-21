import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ftracker_model.dart';
import '../models/sugarcane_profit_model.dart';
import '../services/database_helper.dart';

class SugarcaneProfitProvider with ChangeNotifier {
  List<SugarcaneProfit> _records = [];
  bool _isLoading = false;

  List<SugarcaneProfit> get records => _records;
  bool get isLoading => _isLoading;
  Set<int> get linkedDeliveryIds => _records
      .where((record) => record.deliveryId != null)
      .map((record) => record.deliveryId!)
      .toSet();

  Future<void> loadProfitRecords() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query(
        DatabaseHelper.tableSugarcaneProfits,
        orderBy: 'DeliveryDate DESC, CreatedAt DESC',
      );
      _records = data.map((row) => SugarcaneProfit.fromMap(row)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> saveProfitRecord(
    SugarcaneProfit record, {
    Ftracker? trackerRecord,
  }) async {
    final id = await DatabaseHelper.instance.runInTransaction((txn) async {
      final savedId = await txn.insert(
        DatabaseHelper.tableSugarcaneProfits,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (trackerRecord != null) {
        await txn.insert(DatabaseHelper.tableFtracker, trackerRecord.toMap());
      }
      return savedId;
    });
    await loadProfitRecords();
    return id;
  }
}
