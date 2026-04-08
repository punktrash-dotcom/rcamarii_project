import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/worker_model.dart';
import '../services/database_helper.dart';

class WorkerProvider with ChangeNotifier {
  static const _legacyWorkersTable = 'WorkersDB';
  List<Worker> _workers = [];
  List<Worker> get workers => _workers;

  Future<void> loadWorkers() async {
    final db = await DatabaseHelper.instance.database;
    final tableName = await _resolveWorkersTable(db);
    final data = tableName == null
        ? const <Map<String, Object?>>[]
        : await db.query(tableName);
    _workers = data.map((item) => Worker.fromMap(item)).toList();
    notifyListeners();
  }

  Future<void> addWorker(Worker worker) async {
    final db = await DatabaseHelper.instance.database;
    final tableName =
        await _resolveWorkersTable(db) ?? DatabaseHelper.tableWorkers;
    await db.insert(tableName, worker.toMap());
    await loadWorkers();
  }

  Future<void> updateWorker(Worker worker) async {
    final db = await DatabaseHelper.instance.database;
    final tableName =
        await _resolveWorkersTable(db) ?? DatabaseHelper.tableWorkers;
    await db.update(
      tableName,
      worker.toMap(),
      where: 'EmployeeID = ?',
      whereArgs: [worker.id],
    );
    await loadWorkers();
  }

  Future<void> deleteWorker(int id) async {
    final db = await DatabaseHelper.instance.database;
    final tableName =
        await _resolveWorkersTable(db) ?? DatabaseHelper.tableWorkers;
    await db.delete(
      tableName,
      where: 'EmployeeID = ?',
      whereArgs: [id],
    );
    await loadWorkers();
  }

  Future<String?> _resolveWorkersTable(Database db) async {
    final employeesExists = await _tableExists(db, DatabaseHelper.tableWorkers);
    if (employeesExists) {
      return DatabaseHelper.tableWorkers;
    }

    final legacyExists = await _tableExists(db, _legacyWorkersTable);
    if (legacyExists) {
      return _legacyWorkersTable;
    }

    return null;
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name = ?
      LIMIT 1
      ''',
      [tableName],
    );
    return result.isNotEmpty;
  }
}
