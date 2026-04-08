import '../models/crop_inspector_scan_model.dart';
import 'database_helper.dart';

class CropInspectorHistoryService {
  CropInspectorHistoryService._();

  static final CropInspectorHistoryService instance =
      CropInspectorHistoryService._();

  Future<CropInspectorScanRecord> saveScan(
    CropInspectorDiagnosis diagnosis, {
    required CropInspectorSyncStatus syncStatus,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final record = CropInspectorScanRecord(
      diagnosis: diagnosis,
      syncStatus: syncStatus,
      createdAt: now,
    );
    final id = await db.insert(
      DatabaseHelper.tableCropInspectorScans,
      record.toMap(),
    );
    return record.copyWith(id: id);
  }

  Future<List<CropInspectorScanRecord>> fetchRecentScans({
    int limit = 20,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseHelper.tableCropInspectorScans,
      orderBy: 'CreatedAt DESC',
      limit: limit,
    );
    return rows
        .map((row) => CropInspectorScanRecord.fromMap(row))
        .toList(growable: false);
  }

  Future<List<CropInspectorScanRecord>> fetchPendingScans() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      DatabaseHelper.tableCropInspectorScans,
      where: 'SyncStatus IN (?, ?)',
      whereArgs: [
        cropInspectorSyncStatusValue(CropInspectorSyncStatus.pending),
        cropInspectorSyncStatusValue(CropInspectorSyncStatus.failed),
      ],
      orderBy: 'CreatedAt ASC',
    );
    return rows
        .map((row) => CropInspectorScanRecord.fromMap(row))
        .toList(growable: false);
  }

  Future<void> updateSyncState(
    int id, {
    required CropInspectorSyncStatus syncStatus,
    DateTime? syncedAt,
    String? syncError,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseHelper.tableCropInspectorScans,
      {
        'SyncStatus': cropInspectorSyncStatusValue(syncStatus),
        'SyncedAt': syncedAt?.toIso8601String(),
        'SyncError': syncError,
      },
      where: 'ScanID = ?',
      whereArgs: [id],
    );
  }
}
