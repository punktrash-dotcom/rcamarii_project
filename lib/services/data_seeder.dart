// ignore_for_file: avoid_print

import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'app_properties_store.dart';
import 'database_helper.dart';
import 'knowledge_qa_service.dart';

class DataSeeder {
  static const int _seedVersion = 1;
  static const String _seedVersionKey = 'data_seeder.seed_version';

  // Static lists to hold CSV data for immediate use by providers after loading.
  static List<Map<String, dynamic>> workDefsCsvData = [];
  static List<Map<String, dynamic>> supplyPriceCsvData = [];
  static List<Map<String, dynamic>> equipmentCsvData = [];
  static List<Map<String, dynamic>> ftrackerCsvData = [];
  static List<Map<String, dynamic>> sugarcaneMasterQaCsvData = [];
  static Future<void>? _seedFuture;

  static Future<void> ensureSeeded() {
    return _seedFuture ??= _ensureSeedDataReady();
  }

  static void resetForFactorySettings() {
    _seedFuture = null;
  }

  static Future<void> _ensureSeedDataReady() async {
    await _loadCsvCaches();

    final currentVersion =
        await AppPropertiesStore.instance.getInt(_seedVersionKey) ?? 0;
    if (currentVersion >= _seedVersion) {
      print(
          '--- LOADDATA: Seed version is current. Skipping database refresh. ---');
      return;
    }

    await _refreshSeedDataInDatabase();
    await AppPropertiesStore.instance.setInt(_seedVersionKey, _seedVersion);
  }

  static Future<void> _loadCsvCaches() async {
    if (workDefsCsvData.isEmpty) {
      workDefsCsvData = await _loadCsvAsMap('lib/assets/workdefs.csv');
    }
    if (supplyPriceCsvData.isEmpty) {
      supplyPriceCsvData = await _loadCsvAsMap('lib/assets/supply_price.csv');
      for (var item in supplyPriceCsvData) {
        if (item['Cost'] != null) {
          final rawCost = item['Cost']
              .toString()
              .replaceAll('P', '')
              .replaceAll(',', '')
              .trim();
          item['Cost'] = double.tryParse(rawCost) ?? 0.0;
        }
        item['type'] = item['Type'];
        item['name'] = item['Name'];
        item['description'] = item['Description'];
      }
    }
    if (equipmentCsvData.isEmpty) {
      equipmentCsvData = await _loadCsvAsMap('lib/assets/equipment.csv');
    }
    if (sugarcaneMasterQaCsvData.isEmpty) {
      final rawData =
          await rootBundle.loadString('lib/assets/sugarcane_master_ph.csv');
      final listData = const CsvToListConverter().convert(rawData);
      sugarcaneMasterQaCsvData = [];

      for (var i = 1; i < listData.length; i++) {
        if (listData[i].isEmpty) continue;

        final topic = listData[i][0]?.toString().trim() ?? '';
        final question = listData[i][1]?.toString().trim() ?? '';
        final answer = listData[i][2]?.toString().trim() ?? '';
        final tags = listData[i].length > 3
            ? listData[i][3]?.toString().trim() ?? ''
            : '';
        final lang = listData[i].length > 4
            ? listData[i][4]?.toString().trim() ?? ''
            : '';

        if (question.isEmpty || answer.isEmpty) {
          continue;
        }

        sugarcaneMasterQaCsvData.add({
          'topic': topic,
          'question': question,
          'answer': answer,
          'tags': tags,
          'lang': lang,
          'category': KnowledgeQaService.inferCategory(
            topic: topic,
            tags: tags,
          ),
        });
      }
    }
  }

  /// Loads data from CSVs and seeds it into the database.
  /// This only runs on first launch or when `_seedVersion` is incremented.
  static Future<void> _refreshSeedDataInDatabase() async {
    print('--- LOADDATA: Refreshing definition databases... ---');
    try {
      final db = DatabaseHelper.instance;

      // 1. Handle WorkDefs
      await db.clearTable(DatabaseHelper.tableWorkDefs);
      if (workDefsCsvData.isNotEmpty) {
        // Normalizing WorkDefs CSV fields to match database schema (id vs WorkID)
        final normalizedWorkData = workDefsCsvData.map((w) {
          return {
            'id': w['WorkID'],
            'type': w['Type'],
            'name': w['Name'],
            'ModeOfWork': w['ModeOfWork'],
            'Cost': w['Cost'],
            'description': w['Description'] ?? ''
          };
        }).toList();
        await db.batchInsert(DatabaseHelper.tableWorkDefs, normalizedWorkData);
        print(
            "  -> Populated 'WorkDefs' with ${workDefsCsvData.length} records.");
      }

      // 2. Handle DefSup
      if (supplyPriceCsvData.isNotEmpty) {
        final normalizedSupplyData = supplyPriceCsvData.map((item) {
          return {
            'type': item['type'],
            'name': item['name'],
            'description': item['description'],
            'Cost': item['Cost'],
          };
        }).toList();
        final existingRows = await db.queryAllRows(DatabaseHelper.tableDefSup);
        final existingKeys = existingRows.map((row) {
          final type = row['type']?.toString().trim().toUpperCase() ?? '';
          final name = row['name']?.toString().trim().toUpperCase() ?? '';
          return '$type|$name';
        }).toSet();
        final rowsToInsert = normalizedSupplyData.where((item) {
          final type = item['type']?.toString().trim().toUpperCase() ?? '';
          final name = item['name']?.toString().trim().toUpperCase() ?? '';
          return !existingKeys.contains('$type|$name');
        }).toList();
        if (rowsToInsert.isNotEmpty) {
          await db.batchInsert(DatabaseHelper.tableDefSup, rowsToInsert);
        }
        print(
            "  -> Ensured 'DefSup' has ${supplyPriceCsvData.length} catalog records.");
      }

      // 3. Handle EquipmentDefs
      await db.clearTable(DatabaseHelper.tableEquipmentDefs);
      if (equipmentCsvData.isNotEmpty) {
        // Normalizing Equipment CSV fields to match database schema (EquipID vs EquipID)
        final normalizedEquipData = equipmentCsvData.map((e) {
          return {
            'EquipID': e['EquipID'],
            'Type': e['Type'],
            'Name': e['Name'],
            'Description': e['Description'] ?? '',
            'FilipinoName': e['FilipinoName'] ?? '',
            'Cost': e['Cost'] ?? 0.0,
            'Note': e['Note'] ?? ''
          };
        }).toList();
        await db.batchInsert(
            DatabaseHelper.tableEquipmentDefs, normalizedEquipData);
        print(
            "  -> Populated 'EquipmentDefs' with ${normalizedEquipData.length} records.");
      }

      // 4. Ftracker is intentionally excluded from CSV seeding.
      await db.clearTable(DatabaseHelper.tableQaTable);
      await db.clearTable(DatabaseHelper.tableQaCategoryIcons);

      for (final entry in KnowledgeQaService.categoryIcons.entries) {
        await db.insert(DatabaseHelper.tableQaCategoryIcons, {
          'Category': entry.key,
          'IconCodepoint': entry.value.codePoint,
        });
      }

      for (final row in sugarcaneMasterQaCsvData) {
        await db.insert(DatabaseHelper.tableQaTable, row);
      }
      print(
          "  -> Populated '${DatabaseHelper.tableQaTable}' with ${sugarcaneMasterQaCsvData.length} records.");

      // 5. Ftracker is intentionally excluded from CSV seeding.
      // Keep runtime/user-generated financial records untouched.
      ftrackerCsvData = [];
      print("  -> Skipped 'Ftracker' seeding.");

      print('--- LOADDATA: Database refresh complete. ---');
    } catch (e) {
      print('--- LOADDATA: ERROR during data seeding - $e ---');
    }
  }

  /// A robust helper method to load a CSV file from assets and convert it to a List of Maps.
  static Future<List<Map<String, dynamic>>> _loadCsvAsMap(String path) async {
    try {
      final rawData = await rootBundle.loadString(path);
      List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(rawData);

      if (csvTable.length < 2) return [];

      final headers = csvTable.first.map((h) => h.toString().trim()).toList();
      final List<Map<String, dynamic>> mappedData = [];

      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];

        if (row.isEmpty ||
            (row.length == 1 &&
                (row.first == null || row.first.toString().trim().isEmpty))) {
          continue;
        }

        final rowMap = <String, dynamic>{};
        for (int j = 0; j < headers.length; j++) {
          if (j < row.length && row[j] != null) {
            rowMap[headers[j]] = row[j];
          } else {
            rowMap[headers[j]] = null;
          }
        }
        mappedData.add(rowMap);
      }
      return mappedData;
    } catch (e) {
      print('Error loading CSV from $path: $e');
      return [];
    }
  }
}
