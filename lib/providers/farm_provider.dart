import 'package:flutter/foundation.dart';
import '../models/farm_model.dart';
import '../services/database_helper.dart';
import '../services/transaction_log_service.dart';

class FarmProvider extends ChangeNotifier {
  List<Farm> _farms = [];
  Farm? _selectedFarm;
  bool _isLoading = false;
  bool _isShowingActivities = false;

  Map<String, List<Farm>> get groupedFarms {
    final Map<String, List<Farm>> map = {};
    for (var farm in _farms) {
      if (!map.containsKey(farm.type)) {
        map[farm.type] = [];
      }
      map[farm.type]!.add(farm);
    }
    return map;
  }

  List<String> get uniqueFarmTypes {
    return _farms.map((farm) => farm.type).toSet().toList();
  }

  List<Farm> get farms => _farms;
  Farm? get selectedFarm => _selectedFarm;
  bool get isLoading => _isLoading;
  bool get isShowingActivities => _isShowingActivities;

  void showFarmActivities() {
    _isShowingActivities = true;
    notifyListeners();
  }

  void showFarmDetails() {
    _isShowingActivities = false;
    notifyListeners();
  }

  Future<void> refreshFarms() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query('Farms');
      _farms = data.map((row) => Farm.fromMap(row)).toList();
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    if (_farms.isNotEmpty && _selectedFarm == null) {
      _selectedFarm = _farms.first;
    }
  }

  void handleFarmSelection(Farm farm) {
    _selectedFarm = farm;
    notifyListeners();
  }

  Future<void> addFarm(Farm farm) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('Farms', farm.toMap());
    final newFarm = Farm(
      id: id.toString(),
      name: farm.name,
      type: farm.type,
      area: farm.area,
      city: farm.city,
      province: farm.province,
      date: farm.date,
      owner: farm.owner,
    );
    _farms.add(newFarm);
    _selectedFarm = newFarm;
    notifyListeners();
    TransactionLogService.instance.log('Farm added',
        details: '${farm.name} (${farm.type}) • ${farm.area} ha');
  }

  Future<void> updateFarm(Farm farm) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'Farms',
      farm.toMap(),
      where: 'id = ?',
      whereArgs: [farm.id],
    );
    final index = _farms.indexWhere((f) => f.id == farm.id);
    if (index != -1) {
      _farms[index] = farm;
      if (_selectedFarm?.id == farm.id) {
        _selectedFarm = farm;
      }
      notifyListeners();
      TransactionLogService.instance.log('Farm updated',
          details: '${farm.name} (${farm.type}) • id=${farm.id}');
    }
  }

  Future<void> deleteFarm(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Farms', where: 'id = ?', whereArgs: [id]);
    _farms.removeWhere((f) => f.id == id);
    if (_selectedFarm?.id == id) {
      _selectedFarm = _farms.isNotEmpty ? _farms.first : null;
    }
    notifyListeners();
    TransactionLogService.instance.log('Farm deleted', details: 'id=$id');
  }
}
