import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await databaseFactory.openDatabase(
    r'C:\Users\punkt\OneDrive\Documents\RcamariiFarm.db',
  );

  await db.query(
    'DefSup',
    where: 'UPPER(type) LIKE ? OR UPPER(type) LIKE ?',
    whereArgs: ['%PEST%', '%HERB%'],
    orderBy: 'type ASC, name ASC',
  );

  await db.close();
}
