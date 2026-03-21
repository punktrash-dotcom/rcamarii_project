import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/delivery_model.dart';
import '../services/database_helper.dart';
import 'ftracker_provider.dart';

class DeliveryProvider with ChangeNotifier {
  List<Delivery> _deliveries = [];
  bool _isLoading = false;

  List<Delivery> get deliveries => _deliveries;
  List<Delivery> get sugarcaneDeliveries {
    final sugarcane = _deliveries
        .where((delivery) => delivery.type.toLowerCase().trim() == 'sugarcane')
        .toList();
    sugarcane.sort((a, b) => b.date.compareTo(a.date));
    return sugarcane;
  }

  bool get isLoading => _isLoading;

  Future<void> loadDeliveries() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query(DatabaseHelper.tableDeliveries);
      _deliveries = data.map((row) => Delivery.fromMap(row)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading deliveries: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addDelivery(
    Delivery delivery,
    FtrackerProvider ftracker, {
    bool createFinancialRecord = true,
  }) async {
    final trackerRecord = createFinancialRecord
        ? ftracker.buildRecord(
            dDate: DateFormat('yyyy-MM-dd').format(delivery.date),
            dType: 'Expenses',
            dAmount: delivery.total,
            category: delivery.type,
            name: delivery.name,
            note: (delivery.note?.trim().isNotEmpty ?? false)
                ? delivery.note!.trim()
                : 'Delivery: ${delivery.name} (${delivery.type})',
          )
        : null;

    await DatabaseHelper.instance.runInTransaction((txn) async {
      await txn.insert(DatabaseHelper.tableDeliveries, delivery.toMap());

      if (trackerRecord != null) {
        await txn.insert(DatabaseHelper.tableFtracker, trackerRecord.toMap());
      }
    });

    await loadDeliveries();
    if (trackerRecord != null) {
      await ftracker.loadFtrackerRecords();
    }
  }

  Future<void> deleteDelivery(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      DatabaseHelper.tableDeliveries,
      where: 'DelID = ?',
      whereArgs: [id],
    );
    _deliveries.removeWhere((d) => d.delId == id);
    notifyListeners();
  }
}
