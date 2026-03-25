import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class AppPropertiesStore {
  AppPropertiesStore._();

  static const _migrationCompleteKey =
      '__app_properties_store.legacy_migration_complete__';

  static final AppPropertiesStore instance = AppPropertiesStore._();

  Future<void>? _readyFuture;
  Map<String, dynamic>? _memoryStore;

  Future<void> get ready => _readyFuture ??= _initialize();

  @visibleForTesting
  void useMemoryStoreForTesting([
    Map<String, dynamic> initialValues = const <String, dynamic>{},
  ]) {
    _memoryStore = Map<String, dynamic>.from(initialValues);
    _readyFuture = Future<void>.value();
  }

  @visibleForTesting
  void resetTestingOverrides() {
    _memoryStore = null;
    _readyFuture = null;
  }

  Future<void> _initialize() async {
    if (_memoryStore != null) {
      return;
    }

    final db = await DatabaseHelper.instance.database;
    await _migrateLegacyPreferencesIfNeeded(db);
  }

  Future<void> _migrateLegacyPreferencesIfNeeded(Database db) async {
    final migrationComplete =
        (await _getValueInternal(db, _migrationCompleteKey)) as bool? ?? false;
    if (migrationComplete) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (await _containsKeyInternal(db, key)) {
        continue;
      }

      final value = prefs.get(key);
      if (value is bool) {
        await _setValueInternal(db, key, 'bool', value ? 'true' : 'false');
      } else if (value is int) {
        await _setValueInternal(db, key, 'int', value.toString());
      } else if (value is double) {
        await _setValueInternal(db, key, 'double', value.toString());
      } else if (value is String) {
        await _setValueInternal(db, key, 'string', value);
      } else if (value is List<String>) {
        await _setValueInternal(db, key, 'string_list', jsonEncode(value));
      }
    }

    await _setValueInternal(db, _migrationCompleteKey, 'bool', 'true');
  }

  Future<bool> _containsKeyInternal(Database db, String key) async {
    final rows = await db.query(
      DatabaseHelper.tableAppProperties,
      where: 'property_key = ?',
      whereArgs: [key],
    );
    return rows.isNotEmpty;
  }

  Future<dynamic> _getValueInternal(Database db, String key) async {
    final rows = await db.query(
      DatabaseHelper.tableAppProperties,
      where: 'property_key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return _decodeValue(
      row['property_type']?.toString(),
      row['property_value']?.toString(),
    );
  }

  Future<void> _setValueInternal(
    Database db,
    String key,
    String type,
    String? value,
  ) async {
    await db.insert(
      DatabaseHelper.tableAppProperties,
      {
        'property_key': key,
        'property_type': type,
        'property_value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> containsKey(String key) async {
    await ready;
    if (_memoryStore != null) {
      return _memoryStore!.containsKey(key);
    }

    final db = await DatabaseHelper.instance.database;
    return _containsKeyInternal(db, key);
  }

  Future<String?> getString(String key) async {
    final value = await get(key);
    return value is String ? value : null;
  }

  Future<bool?> getBool(String key) async {
    final value = await get(key);
    return value is bool ? value : null;
  }

  Future<int?> getInt(String key) async {
    final value = await get(key);
    return value is int ? value : null;
  }

  Future<double?> getDouble(String key) async {
    final value = await get(key);
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  Future<List<String>?> getStringList(String key) async {
    final value = await get(key);
    return value is List<String> ? value : null;
  }

  Future<dynamic> get(String key) async {
    await ready;
    if (_memoryStore != null) {
      return _memoryStore![key];
    }

    final db = await DatabaseHelper.instance.database;
    return _getValueInternal(db, key);
  }

  Future<Map<String, dynamic>> exportAll() async {
    await ready;
    if (_memoryStore != null) {
      return Map<String, dynamic>.from(_memoryStore!);
    }

    final rows = await DatabaseHelper.instance.queryAllRows(
      DatabaseHelper.tableAppProperties,
    );
    final values = <String, dynamic>{};
    for (final row in rows) {
      final key = row['property_key']?.toString();
      if (key == null || key.isEmpty) {
        continue;
      }
      values[key] = _decodeValue(
        row['property_type']?.toString(),
        row['property_value']?.toString(),
      );
    }
    return values;
  }

  Future<Set<String>> getKeys() async {
    final values = await exportAll();
    return values.keys.toSet();
  }

  Future<void> importAll(Map<String, dynamic> values) async {
    await ready;
    for (final entry in values.entries) {
      final value = entry.value;
      if (value is bool) {
        await setBool(entry.key, value);
      } else if (value is int) {
        await setInt(entry.key, value);
      } else if (value is double) {
        await setDouble(entry.key, value);
      } else if (value is String) {
        await setString(entry.key, value);
      } else if (value is List<String>) {
        await setStringList(entry.key, value);
      } else if (value is List) {
        await setStringList(
          entry.key,
          value.map((item) => item.toString()).toList(),
        );
      }
    }
  }

  Future<void> setString(String key, String value) async {
    await _setValue(key, 'string', value);
  }

  Future<void> setBool(String key, bool value) async {
    await _setValue(key, 'bool', value ? 'true' : 'false');
  }

  Future<void> setInt(String key, int value) async {
    await _setValue(key, 'int', value.toString());
  }

  Future<void> setDouble(String key, double value) async {
    await _setValue(key, 'double', value.toString());
  }

  Future<void> setStringList(String key, List<String> value) async {
    await _setValue(key, 'string_list', jsonEncode(value));
  }

  Future<void> remove(String key) async {
    await ready;
    if (_memoryStore != null) {
      _memoryStore!.remove(key);
      return;
    }

    final db = await DatabaseHelper.instance.database;
    await db.delete(
      DatabaseHelper.tableAppProperties,
      where: 'property_key = ?',
      whereArgs: [key],
    );
  }

  Future<void> clear() async {
    await ready;
    if (_memoryStore != null) {
      _memoryStore!.clear();
      return;
    }

    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableAppProperties);
  }

  Future<void> _setValue(
    String key,
    String type,
    String? value,
  ) async {
    await ready;
    final decodedValue = _decodeValue(type, value);
    if (_memoryStore != null) {
      _memoryStore![key] = decodedValue;
      return;
    }

    final db = await DatabaseHelper.instance.database;
    await _setValueInternal(db, key, type, value);
  }

  dynamic _decodeValue(String? type, String? value) {
    switch (type) {
      case 'bool':
        return value == 'true';
      case 'int':
        return int.tryParse(value ?? '');
      case 'double':
        return double.tryParse(value ?? '');
      case 'string_list':
        if (value == null || value.isEmpty) {
          return <String>[];
        }
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
        return <String>[];
      case 'string':
      default:
        return value;
    }
  }
}
