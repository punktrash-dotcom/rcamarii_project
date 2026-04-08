import 'package:flutter/foundation.dart';

import '../models/farm_model.dart';
import '../services/app_defaults_service.dart';
import '../services/app_properties_store.dart';
import '../services/database_helper.dart';
import '../services/transaction_log_service.dart';

class FarmProvider extends ChangeNotifier {
  List<Farm> _farms = [];
  Farm? _selectedFarm;
  bool _isLoading = false;
  bool _isShowingActivities = false;
  final AppPropertiesStore _store = AppPropertiesStore.instance;

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
    _persistFarmPanelMode();
    notifyListeners();
  }

  void showFarmDetails() {
    _isShowingActivities = false;
    _persistFarmPanelMode();
    notifyListeners();
  }

  Future<void> refreshFarms() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _store.ready;
      final db = await DatabaseHelper.instance.database;
      final data = await db.query('Farms');
      _farms = data.map((row) => Farm.fromMap(row)).toList();
      _isShowingActivities =
          await _store.getBool(AppDefaultsService.farmDetailsVisibleKey) ??
              false;
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    if (_farms.isEmpty) {
      _selectedFarm = null;
      return;
    }

    final savedFarmId =
        (await _store.getString(AppDefaultsService.selectedFarmIdKey))
                ?.trim() ??
            '';
    Farm? matchingFarm;
    if (savedFarmId.isNotEmpty) {
      for (final farm in _farms) {
        if (farm.id == savedFarmId) {
          matchingFarm = farm;
          break;
        }
      }
    }

    if (matchingFarm != null) {
      _selectedFarm = matchingFarm;
    } else if (_selectedFarm != null) {
      final currentId = _selectedFarm!.id;
      for (final farm in _farms) {
        if (farm.id == currentId) {
          matchingFarm = farm;
          break;
        }
      }
      _selectedFarm = matchingFarm ?? _farms.first;
    } else {
      _selectedFarm = _farms.first;
    }

    _persistSelectedFarm();
    notifyListeners();
  }

  void handleFarmSelection(Farm farm) {
    _selectedFarm = farm;
    _persistSelectedFarm();
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
      ratoonCount: farm.ratoonCount,
      seasonNumber: farm.seasonNumber,
    );
    _farms.add(newFarm);
    _selectedFarm = newFarm;
    final newFarmId = newFarm.id;
    if (newFarmId != null && newFarmId.isNotEmpty) {
      await _store.setString(AppDefaultsService.selectedFarmIdKey, newFarmId);
    }
    notifyListeners();
    TransactionLogService.instance.log('Farm added',
        details: '${farm.name} (${farm.type}) - ${farm.area} ha');
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
      _persistSelectedFarm();
      notifyListeners();
      TransactionLogService.instance.log('Farm updated',
          details: '${farm.name} (${farm.type}) - id=${farm.id}');
    }
  }

  Future<void> advanceToNextSeason(
    Farm farm, {
    DateTime? restartDate,
    bool incrementRatoon = false,
  }) async {
    final now = restartDate ?? DateTime.now();
    final normalizedDate = DateTime(now.year, now.month, now.day);
    await updateFarm(
      farm.copyWith(
        date: normalizedDate,
        seasonNumber: farm.seasonNumber + 1,
        ratoonCount: incrementRatoon ? farm.ratoonCount + 1 : farm.ratoonCount,
      ),
    );
  }

  Future<void> deleteFarm(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Farms', where: 'id = ?', whereArgs: [id]);
    _farms.removeWhere((f) => f.id == id);
    if (_selectedFarm?.id == id) {
      _selectedFarm = _farms.isNotEmpty ? _farms.first : null;
    }
    if (_selectedFarm == null) {
      await _store.remove(AppDefaultsService.selectedFarmIdKey);
    } else {
      final selectedFarmId = _selectedFarm!.id ?? '';
      if (selectedFarmId.isEmpty) {
        await _store.remove(AppDefaultsService.selectedFarmIdKey);
      } else {
        await _store.setString(
          AppDefaultsService.selectedFarmIdKey,
          selectedFarmId,
        );
      }
    }
    notifyListeners();
    TransactionLogService.instance.log('Farm deleted', details: 'id=$id');
  }

  void _persistSelectedFarm() {
    final selectedFarmId = _selectedFarm?.id;
    if (selectedFarmId == null || selectedFarmId.isEmpty) {
      _store.remove(AppDefaultsService.selectedFarmIdKey);
      return;
    }
    _store.setString(AppDefaultsService.selectedFarmIdKey, selectedFarmId);
  }

  void _persistFarmPanelMode() {
    _store.setBool(
      AppDefaultsService.farmDetailsVisibleKey,
      _isShowingActivities,
    );
  }
}
