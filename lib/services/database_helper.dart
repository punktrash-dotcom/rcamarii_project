// ignore_for_file: avoid_print

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = 'RcamariiFarm.db';
  static const _databaseVersion =
      42; // Incremented for Activities note relaxation

  // Table Names Constants
  static const tableFarms = 'Farms';
  static const tableActivities = 'Activities';
  static const tableSupplies = 'Supplies';
  static const tableFtracker = 'Ftracker';
  static const tableDeliveries = 'Deliveries';
  static const tableSugarcaneProfits = 'SugarcaneProfits';
  static const tableEquipment = 'Equipment';
  static const tableWorkers = 'Employees';
  static const tableEquipmentDefs = 'EquipmentDefs';
  static const tableDefSup = 'DefSup';
  static const tableWorkDefs = 'WorkDefs';
  static const tableCategories = 'Categories';
  static const tableQaTable = 'qa_table';
  static const tableQaCategoryIcons = 'qa_category_icons';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print(
        '--- DATABASE HELPER: Upgrading database from v$oldVersion to v$newVersion... ---');
    if (newVersion <= oldVersion) return;

    if (oldVersion < 37) {
      // Legacy upgrades still require a reset because earlier versions relied
      // on destructive schema refreshes for structural changes.
      await _dropAllTables(db);
      await _createTables(db);
      return;
    }

    if (oldVersion < 38) {
      await _ensureFtrackerSchema(db);
    }

    if (oldVersion < 39) {
      await _createSugarcaneProfitsTable(db);
    }

    if (oldVersion < 40) {
      await _createQaTable(db);
      await _createQaCategoryIconsTable(db);
    }

    if (oldVersion < 41) {
      await _ensureActivitiesSchema(db);
    }

    if (oldVersion < 42) {
      await _ensureActivitiesSchema(db);
    }
  }

  Future _onOpen(Database db) async {
    // Migration safety check for Ftracker
    await _ensureFtrackerSchema(db);
    await _ensureActivitiesSchema(db);
    await _createSugarcaneProfitsTable(db);
    await _createQaTable(db);
    await _createQaCategoryIconsTable(db);
  }

  Future<void> _dropAllTables(Database db) async {
    final tables = [
      tableFtracker,
      tableSugarcaneProfits,
      tableQaTable,
      tableQaCategoryIcons,
      tableCategories,
      tableDefSup,
      tableWorkDefs,
      tableFarms,
      tableEquipment,
      tableEquipmentDefs,
      tableActivities,
      tableSupplies,
      tableDeliveries,
      tableWorkers,
      'WorkersDB'
    ];
    for (var table in tables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    print('   -> All tables dropped for restructuring.');
  }

  // --- Table Creation Methods ---

  Future<void> _createFarmsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableFarms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        area REAL NOT NULL,
        city TEXT NOT NULL,
        province TEXT NOT NULL,
        date TEXT NOT NULL,
        owner TEXT NOT NULL
      );
    ''');
    print("   -> Table '$tableFarms' created.");
  }

  Future<void> _createActivitiesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableActivities (
        jobId TEXT PRIMARY KEY,
        tag TEXT NOT NULL,
        date TEXT NOT NULL,
        farm TEXT NOT NULL,
        name TEXT NOT NULL,
        labor TEXT NOT NULL,
        assetUsed TEXT NOT NULL,
        costType TEXT NOT NULL,
        duration REAL NOT NULL,
        cost REAL,
        total REAL,
        worker TEXT NOT NULL,
        note TEXT
      );
    ''');
    print("   -> Table '$tableActivities' created.");
  }

  Future<void> _createSuppliesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableSupplies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        quantity INTEGER NOT NULL,
        cost REAL NOT NULL,
        total REAL NOT NULL
      );
    ''');
    print("   -> Table '$tableSupplies' created.");
  }

  Future<void> _createFtrackerTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableFtracker(
        TransID INTEGER PRIMARY KEY AUTOINCREMENT,
        Date TEXT NOT NULL,
        Type TEXT NOT NULL,
        Category TEXT NOT NULL,
        Name TEXT NOT NULL,
        Amount REAL NOT NULL,
        Note TEXT
        );
    ''');
    print("   -> Table '$tableFtracker' created.");
  }

  Future<void> _ensureFtrackerSchema(Database db) async {
    await _ensureFtrackerNameColumn(db);
    await _relaxFtrackerNoteConstraint(db);
  }

  Future<void> _ensureActivitiesSchema(Database db) async {
    await _relaxActivitiesCostTotalConstraints(db);
    await _relaxActivitiesNoteConstraint(db);
  }

  bool _columnIsNotNull(Map<String, Object?> column) {
    final rawValue = column['notnull'] ?? 0;
    if (rawValue is int) return rawValue == 1;
    return (int.tryParse(rawValue.toString()) ?? 0) == 1;
  }

  Future<void> _ensureFtrackerNameColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableFtracker)');
    if (columns.isEmpty) return;

    Map<String, Object?>? nameColumn;
    for (final col in columns) {
      final name = (col['name'] ?? '').toString().toLowerCase();
      if (name == 'name') {
        nameColumn = col;
        break;
      }
    }

    final hasNameColumn = nameColumn != null;
    final nameIsNotNull = hasNameColumn && _columnIsNotNull(nameColumn);
    if (hasNameColumn && nameIsNotNull) return;

    final nameSelectExpression = hasNameColumn
        ? "COALESCE(NULLIF(TRIM(Name), ''), NULLIF(TRIM(Note), ''), NULLIF(TRIM(Category), ''), NULLIF(TRIM(Type), ''), 'Unspecified')"
        : "COALESCE(NULLIF(TRIM(Note), ''), NULLIF(TRIM(Category), ''), NULLIF(TRIM(Type), ''), 'Unspecified')";

    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE ${tableFtracker}_name_fixed(
          TransID INTEGER PRIMARY KEY AUTOINCREMENT,
          Date TEXT NOT NULL,
          Type TEXT NOT NULL,
          Category TEXT NOT NULL,
          Name TEXT NOT NULL,
          Amount REAL NOT NULL,
          Note TEXT
        );
      ''');

      await txn.execute('''
        INSERT INTO ${tableFtracker}_name_fixed (TransID, Date, Type, Category, Name, Amount, Note)
        SELECT TransID, Date, Type, Category, $nameSelectExpression, Amount, Note
        FROM $tableFtracker;
      ''');

      await txn.execute('DROP TABLE $tableFtracker;');
      await txn.execute(
          'ALTER TABLE ${tableFtracker}_name_fixed RENAME TO $tableFtracker;');
    });

    print("   -> Migrated '$tableFtracker': ensured required 'Name' column.");
  }

  Future<void> _relaxFtrackerNoteConstraint(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableFtracker)');
    if (columns.isEmpty) return;

    Map<String, Object?>? noteColumn;
    for (final col in columns) {
      final name = (col['name'] ?? '').toString().toLowerCase();
      if (name == 'note') {
        noteColumn = col;
        break;
      }
    }

    if (noteColumn == null) return;
    final isNotNull = _columnIsNotNull(noteColumn);
    if (!isNotNull) return;

    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE ${tableFtracker}_note_relaxed(
          TransID INTEGER PRIMARY KEY AUTOINCREMENT,
          Date TEXT NOT NULL,
          Type TEXT NOT NULL,
          Category TEXT NOT NULL,
          Name TEXT NOT NULL,
          Amount REAL NOT NULL,
          Note TEXT
        );
      ''');

      await txn.execute('''
        INSERT INTO ${tableFtracker}_note_relaxed (TransID, Date, Type, Category, Name, Amount, Note)
        SELECT TransID, Date, Type, Category, Name, Amount, Note
        FROM $tableFtracker;
      ''');

      await txn.execute('DROP TABLE $tableFtracker;');
      await txn.execute(
          'ALTER TABLE ${tableFtracker}_note_relaxed RENAME TO $tableFtracker;');
    });

    print(
        "   -> Migrated '$tableFtracker': relaxed 'Note' column to allow NULL values.");
  }

  Future<void> _relaxActivitiesCostTotalConstraints(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableActivities)');
    if (columns.isEmpty) return;

    Map<String, Object?>? costColumn;
    Map<String, Object?>? totalColumn;
    for (final col in columns) {
      final name = (col['name'] ?? '').toString().toLowerCase();
      if (name == 'cost') {
        costColumn = col;
      } else if (name == 'total') {
        totalColumn = col;
      }
    }

    final costIsNotNull = costColumn != null && _columnIsNotNull(costColumn);
    final totalIsNotNull = totalColumn != null && _columnIsNotNull(totalColumn);
    if (!costIsNotNull && !totalIsNotNull) return;

    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE ${tableActivities}_cost_total_relaxed (
          jobId TEXT PRIMARY KEY,
          tag TEXT NOT NULL,
          date TEXT NOT NULL,
          farm TEXT NOT NULL,
          name TEXT NOT NULL,
          labor TEXT NOT NULL,
          assetUsed TEXT NOT NULL,
          costType TEXT NOT NULL,
        duration REAL NOT NULL,
        cost REAL,
        total REAL,
        worker TEXT NOT NULL,
        note TEXT
      );
      ''');

      await txn.execute('''
        INSERT INTO ${tableActivities}_cost_total_relaxed (
          jobId, tag, date, farm, name, labor, assetUsed,
          costType, duration, cost, total, worker, note
        )
        SELECT
          jobId, tag, date, farm, name, labor, assetUsed,
          costType, duration, cost, total, worker, note
        FROM $tableActivities;
      ''');

      await txn.execute('DROP TABLE $tableActivities;');
      await txn.execute('''
        ALTER TABLE ${tableActivities}_cost_total_relaxed
        RENAME TO $tableActivities;
      ''');
    });

    print(
        "   -> Migrated '$tableActivities': relaxed 'cost' and 'total' columns.");
  }

  Future<void> _relaxActivitiesNoteConstraint(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableActivities)');
    if (columns.isEmpty) return;

    Map<String, Object?>? noteColumn;
    for (final col in columns) {
      final name = (col['name'] ?? '').toString().toLowerCase();
      if (name == 'note') {
        noteColumn = col;
        break;
      }
    }

    if (noteColumn == null) return;
    final noteIsNotNull = _columnIsNotNull(noteColumn);
    if (!noteIsNotNull) return;

    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE ${tableActivities}_note_relaxed (
          jobId TEXT PRIMARY KEY,
          tag TEXT NOT NULL,
          date TEXT NOT NULL,
          farm TEXT NOT NULL,
          name TEXT NOT NULL,
          labor TEXT NOT NULL,
          assetUsed TEXT NOT NULL,
          costType TEXT NOT NULL,
          duration REAL NOT NULL,
          cost REAL,
          total REAL,
          worker TEXT NOT NULL,
          note TEXT
        );
      ''');

      await txn.execute('''
        INSERT INTO ${tableActivities}_note_relaxed (
          jobId, tag, date, farm, name, labor, assetUsed,
          costType, duration, cost, total, worker, note
        )
        SELECT
          jobId, tag, date, farm, name, labor, assetUsed,
          costType, duration, cost, total, worker,
          NULLIF(TRIM(note), '')
        FROM $tableActivities;
      ''');

      await txn.execute('DROP TABLE $tableActivities;');
      await txn.execute('''
        ALTER TABLE ${tableActivities}_note_relaxed
        RENAME TO $tableActivities;
      ''');
    });

    print(
        "   -> Migrated '$tableActivities': relaxed 'note' column to allow NULL values.");
  }

  Future<void> _createDeliveriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableDeliveries(
        DelID INTEGER PRIMARY KEY AUTOINCREMENT,
        Date TEXT NOT NULL,
        Type TEXT NOT NULL,
        Name TEXT NOT NULL,
        TicketNo TEXT,
        Cost REAL,
        Quantity REAL,
        Total REAL NOT NULL,
        Note TEXT
      )
    ''');
    print("   -> Table '$tableDeliveries' created with updated schema.");
  }

  Future<void> _createSugarcaneProfitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSugarcaneProfits(
        ProfitID INTEGER PRIMARY KEY AUTOINCREMENT,
        DeliveryID INTEGER UNIQUE,
        SourceType TEXT NOT NULL,
        SourceLabel TEXT NOT NULL,
        SourceStatus TEXT NOT NULL,
        FarmName TEXT NOT NULL,
        DeliveryDate TEXT NOT NULL,
        NetTonsCane REAL NOT NULL,
        LkgPerTc REAL NOT NULL,
        PlanterShare REAL NOT NULL,
        SugarPricePerLkg REAL NOT NULL,
        MolassesKg REAL NOT NULL,
        MolassesPricePerKg REAL NOT NULL,
        ProductionCosts REAL NOT NULL,
        SugarProceeds REAL NOT NULL,
        MolassesProceeds REAL NOT NULL,
        TotalRevenue REAL NOT NULL,
        NetProfit REAL NOT NULL,
        Note TEXT,
        CreatedAt TEXT NOT NULL
      )
    ''');
    print("   -> Table '$tableSugarcaneProfits' created.");
  }

  Future<void> _createEquipmentTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableEquipment (
        EqID INTEGER PRIMARY KEY AUTOINCREMENT,
        Type TEXT NOT NULL,
        Name TEXT NOT NULL,
        Quantity INTEGER NOT NULL,
        Cost REAL NOT NULL,
        Total REAL NOT NULL,
        Note TEXT
      );
    ''');
    print("   -> Table 'Equipment' created.");
  }

  Future<void> _createEmployeesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableWorkers (
        EmployeeID INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Address TEXT,
        Position TEXT,
        Note TEXT
      );
    ''');
    print("   -> Table '$tableWorkers' created.");
  }

  Future<void> _createEquipmentDefsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableEquipmentDefs (
        EquipID INTEGER PRIMARY KEY AUTOINCREMENT,
        Type TEXT NOT NULL,
        Name TEXT NOT NULL UNIQUE,
        Description TEXT,
        FilipinoName TEXT,
        Cost REAL,
        Note TEXT
      );
    ''');
    print("   -> Table '$tableEquipmentDefs' created.");
  }

  Future<void> _createDefSupTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableDefSup (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        Cost REAL
      )
    ''');
    print("   -> Table '$tableDefSup' created.");
  }

  Future<void> _createWorkDefsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableWorkDefs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        ModeOfWork TEXT,
        Cost REAL
      )
    ''');
    print("   -> Table '$tableWorkDefs' created.");
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableCategories (
        Name TEXT PRIMARY KEY,
        IconCodepoint INTEGER NOT NULL
      )
    ''');
    print("   -> Table '$tableCategories' created.");
  }

  Future<void> _createQaTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableQaTable (
        QaID INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT NOT NULL,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        tags TEXT,
        lang TEXT NOT NULL,
        category TEXT NOT NULL
      )
    ''');
    print("   -> Table '$tableQaTable' created.");
  }

  Future<void> _createQaCategoryIconsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableQaCategoryIcons (
        Category TEXT PRIMARY KEY,
        IconCodepoint INTEGER NOT NULL
      )
    ''');
    print("   -> Table '$tableQaCategoryIcons' created.");
  }

  Future<void> _createTables(Database db) async {
    await _createFarmsTable(db);
    await _createActivitiesTable(db);
    await _createSuppliesTable(db);
    await _createFtrackerTable(db);
    await _createDeliveriesTable(db);
    await _createSugarcaneProfitsTable(db);
    await _createEquipmentTable(db);
    await _createEmployeesTable(db);
    await _createEquipmentDefsTable(db);
    await _createDefSupTable(db);
    await _createWorkDefsTable(db);
    await _createCategoriesTable(db);
    await _createQaTable(db);
    await _createQaCategoryIconsTable(db);
  }

  // Helper methods
  Future<int> insert(String table, Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table, row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAllRows(String table) async {
    Database db = await instance.database;
    return await db.query(table);
  }

  Future<int> update(
      String table, String idColumn, Map<String, dynamic> row) async {
    Database db = await instance.database;
    dynamic id = row[idColumn];
    return await db.update(table, row, where: '$idColumn = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, String idColumn, int id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$idColumn = ?', whereArgs: [id]);
  }

  Future<int> clearTable(String table) async {
    Database db = await instance.database;
    return await db.delete(table);
  }

  Future<void> batchInsert(
      String table, List<Map<String, dynamic>> rows) async {
    Database db = await instance.database;
    Batch batch = db.batch();
    for (var row in rows) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> query(String table,
      {String? where, List<dynamic>? whereArgs}) async {
    Database db = await instance.database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await instance.database;
    return db.transaction(action);
  }
}
