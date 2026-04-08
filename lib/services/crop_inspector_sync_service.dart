import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/crop_inspector_scan_model.dart';
import 'app_properties_store.dart';
import 'crop_inspector_history_service.dart';

class CropInspectorSyncService {
  CropInspectorSyncService._();

  static final CropInspectorSyncService instance =
      CropInspectorSyncService._();

  static const String backendEnabledKey =
      'crop_inspector.backend_enabled';
  static const String backendUrlKey = 'crop_inspector.backend_url';

  final AppPropertiesStore _store = AppPropertiesStore.instance;
  final CropInspectorHistoryService _history = CropInspectorHistoryService.instance;

  Future<bool> isBackendEnabled() async {
    return await _store.getBool(backendEnabledKey) ?? false;
  }

  Future<String> backendUrl() async {
    return (await _store.getString(backendUrlKey))?.trim() ?? '';
  }

  Future<void> setBackendEnabled(bool value) {
    return _store.setBool(backendEnabledKey, value);
  }

  Future<void> setBackendUrl(String value) {
    return _store.setString(backendUrlKey, value.trim());
  }

  Future<bool> canSync() async {
    final enabled = await isBackendEnabled();
    final url = await backendUrl();
    return enabled && url.isNotEmpty;
  }

  Future<void> syncRecord(CropInspectorScanRecord record) async {
    final url = await backendUrl();
    if (url.isEmpty) {
      if (record.id != null) {
        await _history.updateSyncState(
          record.id!,
          syncStatus: CropInspectorSyncStatus.localOnly,
        );
      }
      return;
    }

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.fields['scan'] = jsonEncode(record.toMap());

    final imageFile = File(record.diagnosis.imagePath);
    if (await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw HttpException(
        'Crop inspector sync failed (${response.statusCode}): $body',
      );
    }

    if (record.id != null) {
      await _history.updateSyncState(
        record.id!,
        syncStatus: CropInspectorSyncStatus.synced,
        syncedAt: DateTime.now(),
      );
    }
  }

  Future<int> syncPendingRecords() async {
    if (!await canSync()) {
      return 0;
    }

    final records = await _history.fetchPendingScans();
    var syncedCount = 0;
    for (final record in records) {
      try {
        await syncRecord(record);
        syncedCount++;
      } catch (error) {
        if (record.id != null) {
          await _history.updateSyncState(
            record.id!,
            syncStatus: CropInspectorSyncStatus.failed,
            syncError: error.toString(),
          );
        }
      }
    }
    return syncedCount;
  }
}
