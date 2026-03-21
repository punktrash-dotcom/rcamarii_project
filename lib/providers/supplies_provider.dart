import 'package:flutter/foundation.dart';

import '../models/supply_model.dart';
import '../services/database_helper.dart';
import '../services/transaction_log_service.dart';

class SuppliesProvider with ChangeNotifier {
  List<Supply> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Supply> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Supply _normalizeSupply(Supply supply) {
    final trimmedId = supply.id.trim();
    if (trimmedId.isNotEmpty) {
      return supply;
    }

    return Supply(
      id: 'SUP-${DateTime.now().millisecondsSinceEpoch}',
      name: supply.name,
      description: supply.description,
      quantity: supply.quantity,
      cost: supply.cost,
      total: supply.total,
    );
  }

  Future<void> loadSupplies() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query(DatabaseHelper.tableSupplies);
      _items = data.map((row) => Supply.fromMap(row)).toList();
    } catch (e) {
      _error = 'Failed to load supplies.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSupply(Supply supply) async {
    final normalizedSupply = _normalizeSupply(supply);
    final db = await DatabaseHelper.instance.database;
    await db.insert(DatabaseHelper.tableSupplies, normalizedSupply.toMap());
    _items.add(normalizedSupply);
    notifyListeners();
    TransactionLogService.instance.log(
      'Supply added',
      details:
          '${normalizedSupply.name} | qty=${normalizedSupply.quantity} | total=PHP ${normalizedSupply.total.toStringAsFixed(2)}',
    );
  }

  Future<void> updateSupply(Supply supply) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseHelper.tableSupplies,
      supply.toMap(),
      where: 'id = ?',
      whereArgs: [supply.id],
    );
    final index = _items.indexWhere((s) => s.id == supply.id);
    if (index != -1) {
      _items[index] = supply;
      notifyListeners();
      TransactionLogService.instance.log(
        'Supply updated',
        details: '${supply.name} | qty=${supply.quantity}',
      );
    }
  }

  Future<void> deleteSupply(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableSupplies, where: 'id = ?', whereArgs: [id]);
    _items.removeWhere((s) => s.id == id);
    notifyListeners();
    TransactionLogService.instance.log('Supply deleted', details: 'id=$id');
  }

  Future<void> resupply(
    String id,
    int additionalQuantity,
    double newCost,
  ) async {
    final index = _items.indexWhere((s) => s.id == id);
    if (index != -1) {
      final oldSupply = _items[index];
      final newQuantity = oldSupply.quantity + additionalQuantity;
      final newTotal = oldSupply.total + (additionalQuantity * newCost);

      final updatedSupply = Supply(
        id: oldSupply.id,
        name: oldSupply.name,
        description: oldSupply.description,
        quantity: newQuantity,
        cost: newCost,
        total: newTotal,
      );
      await updateSupply(updatedSupply);
      TransactionLogService.instance.log(
        'Supply resupplied',
        details:
            '${updatedSupply.name} | +$additionalQuantity units | cost=PHP ${newCost.toStringAsFixed(2)}',
      );
    }
  }
}
