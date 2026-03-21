import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/ftracker_model.dart';
import '../services/database_helper.dart';
import '../services/backup_service.dart';
import '../utils/validation_utils.dart';
import 'dart:io';

class FtrackerProvider with ChangeNotifier {
  List<Ftracker> _records = [];
  bool _isLoading = false;
  String? _error;

  List<Ftracker> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<String> get uniqueCategories {
    final categories = _records.map((r) => r.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// Implementation of TRANSREC logical function
  /// Records a transaction into the Ftracker database automatically.
  Ftracker buildRecord({
    required String dDate,
    required String dType,
    double dAmount = 0.0,
    String category = 'Farm',
    String? name,
    String? note,
  }) {
    final formattedType = ValidationUtils.toTitleCase(dType);
    final normalizedCategory =
        category.trim().isEmpty ? 'Farm' : category.trim();
    final normalizedNote =
        (note?.trim().isNotEmpty ?? false) ? note!.trim() : null;
    final normalizedName =
        _resolveRecordName(name, normalizedCategory, normalizedNote, dType);

    DateTime parsedDate;
    try {
      parsedDate = DateFormat('yyyy-MM-dd').parse(dDate);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return Ftracker(
      date: parsedDate,
      type: formattedType,
      category: normalizedCategory,
      name: normalizedName,
      amount: dAmount,
      note: normalizedNote,
    );
  }

  Future<void> transRec({
    required String dDate,
    required String dType,
    double dAmount = 0.0,
    String category = 'Farm',
    String? name,
    String? note,
  }) async {
    final newRecord = buildRecord(
      dDate: dDate,
      dType: dType,
      dAmount: dAmount,
      category: category,
      name: name,
      note: note,
    );

    await addFtrackerRecord(newRecord);
  }

  String _resolveRecordName(
    String? name,
    String category,
    String? note,
    String type,
  ) {
    final candidates = [name, note, category, type];
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Unspecified';
  }

  Future<void> loadFtrackerRecords() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query('Ftracker');
      _records = data.map((row) => Ftracker.fromMap(row)).toList();
    } catch (e) {
      _error = 'Failed to load Ftracker records.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFtrackerRecord(Ftracker record) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('Ftracker', record.toMap());
    final newRecord = Ftracker(
      transid: id,
      date: record.date,
      type: record.type,
      category: record.category,
      name: record.name,
      amount: record.amount,
      note: record.note,
    );
    _records = List.from(_records)..add(newRecord);
    notifyListeners();
  }

  Future<void> updateFtrackerRecord(Ftracker record) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'Ftracker',
      record.toMap(),
      where: 'TransID = ?',
      whereArgs: [record.transid],
    );
    final index = _records.indexWhere((r) => r.transid == record.transid);
    if (index != -1) {
      _records = List.from(_records);
      _records[index] = record;
      notifyListeners();
    }
  }

  Future<void> deleteFtrackerRecord(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Ftracker', where: 'TransID = ?', whereArgs: [id]);
    _records = _records.where((r) => r.transid != id).toList();
    notifyListeners();
  }

  Future<void> restoreBackup(File file) async {
    _isLoading = true;
    notifyListeners();
    try {
      await BackupService.restoreData(file);
      await loadFtrackerRecords();
    } catch (e) {
      _error = 'Failed to restore backup.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
