import 'package:flutter/foundation.dart' hide Category;
import '../models/def_sup_model.dart';
import '../models/work_def_model.dart';
import '../services/database_helper.dart';

class DataProvider with ChangeNotifier {
  List<WorkDef> _workDefs = [];
  List<DefSup> _defSups = [];
  List<Map<String, dynamic>> _equipmentDefs = [];

  List<WorkDef> get workDefs => _workDefs;
  List<DefSup> get defSups => _defSups;
  List<Map<String, dynamic>> get equipmentDefs => _equipmentDefs;

  void setWorkDefs(List<Map<String, dynamic>> data) {
    _workDefs = data.map((d) => WorkDef.fromMap(d)).toList();
    notifyListeners();
  }

  void setDefSups(List<Map<String, dynamic>> data) {
    _defSups = data.map((d) => DefSup.fromMap(d)).toList();
    notifyListeners();
  }

  Future<void> loadDefSupsFromDb() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query('DefSup');
    _defSups = data.map((d) => DefSup.fromMap(d)).toList();
    notifyListeners();
  }

  void setEquipment(List<Map<String, dynamic>> data) {
    _equipmentDefs = data;
    notifyListeners();
  }

  Future<bool> addDefSup(DefSup defSup) async {
    final db = await DatabaseHelper.instance.database;
    final existing =
        await db.query('DefSup', where: 'name = ?', whereArgs: [defSup.name]);
    if (existing.isNotEmpty) {
      return false;
    }

    final map = defSup.toMap();
    final parsedId = int.tryParse(defSup.id);
    if (parsedId == null || parsedId <= 0) {
      map.remove('id');
    } else {
      map['id'] = parsedId;
    }

    final id = await db.insert('DefSup', map);
    final newDef = DefSup(
      id: id.toString(),
      name: defSup.name,
      type: defSup.type,
      description: defSup.description,
      cost: defSup.cost,
    );
    _defSups.add(newDef);
    notifyListeners();
    return true;
  }

  Future<bool> addEquipmentDef(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await db
        .query('EquipmentDefs', where: 'Name = ?', whereArgs: [data['Name']]);
    if (existing.isNotEmpty) {
      return false;
    }

    final map = Map<String, dynamic>.from(data);
    if (map['EquipID'] == '' ||
        map['EquipID'] == '0' ||
        map['EquipID'] == null) {
      map.remove('EquipID');
    }

    final id = await db.insert('EquipmentDefs', map);
    map['EquipID'] = id;
    _equipmentDefs.add(map);
    notifyListeners();
    return true;
  }

  Future<bool> addWorkDef(WorkDef workDef) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await db
        .query('WorkDefs', where: 'Name = ?', whereArgs: [workDef.name]);
    if (existing.isNotEmpty) {
      return false;
    }

    final map = workDef.toMap();
    // Remove ID if it's empty to let SQLite auto-increment handle it
    if (workDef.id == '' || workDef.id == '0') {
      map.remove('id');
    }

    final id = await db.insert('WorkDefs', map);

    final newWorkDef = WorkDef(
      id: id.toString(),
      name: workDef.name,
      type: workDef.type,
      modeOfWork: workDef.modeOfWork,
      cost: workDef.cost,
    );

    _workDefs.add(newWorkDef);
    notifyListeners();
    return true;
  }

  Future<bool> updateWorkDef(WorkDef workDef) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query(
      'WorkDefs',
      where: 'name = ? AND id != ?',
      whereArgs: [workDef.name, workDef.id],
    );
    if (existing.isNotEmpty) {
      return false;
    }

    await db.update(
      'WorkDefs',
      workDef.toMap(),
      where: 'id = ?',
      whereArgs: [workDef.id],
    );

    final index = _workDefs.indexWhere((def) => def.id == workDef.id);
    if (index != -1) {
      _workDefs[index] = workDef;
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<void> deleteWorkDef(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('WorkDefs', where: 'id = ?', whereArgs: [id]);
    _workDefs.removeWhere((def) => def.id == id);
    notifyListeners();
  }
}
