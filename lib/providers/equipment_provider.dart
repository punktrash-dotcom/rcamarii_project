import 'package:flutter/foundation.dart';
import '../models/equipment_model.dart';
import '../services/database_helper.dart';

class EquipmentProvider with ChangeNotifier {
  List<Equipment> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Equipment> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEquipment() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query('Equipment');
      _items = data.map((row) => Equipment.fromMap(row)).toList();
    } catch (e) {
      _error = 'Failed to load equipment.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addEquipment(Equipment equipment) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('Equipment', equipment.toMap());
    final newEquipment = Equipment(
      id: id.toString(),
      type: equipment.type,
      name: equipment.name,
      quantity: equipment.quantity,
      cost: equipment.cost,
      total: equipment.total,
      note: equipment.note,
    );
    _items.add(newEquipment);
    notifyListeners();
  }

  Future<void> updateEquipment(Equipment equipment) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'Equipment',
      equipment.toMap(),
      where: 'EqID = ?',
      whereArgs: [equipment.id],
    );
    final index = _items.indexWhere((e) => e.id == equipment.id);
    if (index != -1) {
      _items[index] = equipment;
      notifyListeners();
    }
  }

  Future<void> deleteEquipment(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Equipment', where: 'EqID = ?', whereArgs: [id]);
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> addQuantity(String id, int quantity) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1) {
      final equipment = _items[index];
      final newQuantity = equipment.quantity + quantity;
      final updatedEquipment = Equipment(
        id: equipment.id,
        type: equipment.type,
        name: equipment.name,
        quantity: newQuantity,
        cost: equipment.cost,
        total: equipment.cost * newQuantity,
        note: equipment.note,
      );
      await updateEquipment(updatedEquipment);
    }
  }

  Future<void> incrementQuantity(String id) async {
    await addQuantity(id, 1);
  }
}
