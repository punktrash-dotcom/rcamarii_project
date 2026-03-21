import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static Future<String> backupData({
    bool includeSettings = false,
    String? targetPath,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> records = await db.query('Ftracker');

    Map<String, dynamic> backupMap = {
      'records': records,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (includeSettings) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      Map<String, dynamic> settings = {};
      for (String key in keys) {
        settings[key] = prefs.get(key);
      }
      backupMap['settings'] = settings;
    }

    String backupPath;
    if (targetPath != null) {
      backupPath = targetPath;
    } else {
      final directory = await getApplicationDocumentsDataDirectory();
      final defaultBackupDir = Directory('${directory.path}/backups');
      if (!await defaultBackupDir.exists()) {
        await defaultBackupDir.create(recursive: true);
      }
      backupPath = defaultBackupDir.path;
    }

    final fileName = 'TrackerBackup.json';
    final file = File('$backupPath/$fileName');
    await file.writeAsString(jsonEncode(backupMap));

    return file.path;
  }

  static Future<List<File>> getBackups() async {
    final directory = await getApplicationDocumentsDataDirectory();
    final backupDir = Directory('${directory.path}/backups');
    if (!await backupDir.exists()) return [];

    return backupDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  }

  static Future<void> restoreData(File file) async {
    final content = await file.readAsString();
    final Map<String, dynamic> backupMap = jsonDecode(content);

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete('Ftracker');
      for (var record in backupMap['records']) {
        final normalizedRecord = Map<String, dynamic>.from(record);
        final existingName = (normalizedRecord['Name'] ?? '').toString().trim();
        final fallbackName = existingName.isNotEmpty
            ? existingName
            : _fallbackFtrackerName(normalizedRecord);
        normalizedRecord['Name'] = fallbackName;
        await txn.insert('Ftracker', normalizedRecord);
      }
    });

    if (backupMap.containsKey('settings')) {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> settings = backupMap['settings'];
      settings.forEach((key, value) {
        if (value is bool) {
          prefs.setBool(key, value);
        } else if (value is int) {
          prefs.setInt(key, value);
        } else if (value is double) {
          prefs.setDouble(key, value);
        } else if (value is String) {
          prefs.setString(key, value);
        }
      });
    }
  }

  static Future<Directory> getApplicationDocumentsDataDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      return Directory.current;
    }
  }

  static String _fallbackFtrackerName(Map<String, dynamic> record) {
    final candidates = [
      record['Note'],
      record['Category'],
      record['Type'],
    ];

    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return 'Unspecified';
  }
}
