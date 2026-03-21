import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nmd/models/def_sup_model.dart';
import 'package:nmd/services/database_helper.dart';
import 'package:nmd/services/supply_price_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final result =
      await SupplyPriceSyncService.instance.syncCatalogWithLatestSourcePrices();

  final db = await DatabaseHelper.instance.database;
  final rows = await db.query(DatabaseHelper.tableDefSup);
  final pesticides = rows
      .map((row) => DefSup.fromMap(row))
      .where((item) {
        final type = item.type.trim().toUpperCase();
        return type.contains('PEST') || type.contains('HERB');
      })
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  stdout.writeln('Supply price sync completed.');
  stdout.writeln('Catalog updated: ${result.catalogUpdated}');
  stdout.writeln('Catalog inserted: ${result.catalogInserted}');
  stdout.writeln('Supplies updated: ${result.suppliesUpdated}');
  stdout.writeln('Fertilizer report: ${result.fertilizerReportUrl ?? 'n/a'}');
  stdout.writeln('Pesticide report: ${result.pesticideReportUrl ?? 'n/a'}');
  stdout.writeln('');
  stdout.writeln('Pesticide/Herbicide catalog snapshot:');
  for (final item in pesticides) {
    stdout.writeln(
      '${item.type} | ${item.name} | PHP ${item.cost.toStringAsFixed(2)}',
    );
  }
}
