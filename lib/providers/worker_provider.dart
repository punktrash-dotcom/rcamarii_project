import 'package:flutter/material.dart';
import '../models/worker_model.dart';
import '../services/database_helper.dart';

class WorkerProvider with ChangeNotifier {
  List<Worker> _workers = [];
  List<Worker> get workers => _workers;

  Future<void> loadWorkers() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query('Employees'); // Updated table name
    _workers = data.map((item) => Worker.fromMap(item)).toList();
    notifyListeners();
  }

  Future<void> addWorker(Worker worker) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('Employees', worker.toMap()); // Updated table name
    await loadWorkers();
  }

  Future<void> updateWorker(Worker worker) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'Employees', // Updated table name
      worker.toMap(),
      where: 'EmployeeID = ?',
      whereArgs: [worker.id],
    );
    await loadWorkers();
  }

  Future<void> deleteWorker(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'Employees', // Updated table name
      where: 'EmployeeID = ?',
      whereArgs: [id],
    );
    await loadWorkers();
  }
}
