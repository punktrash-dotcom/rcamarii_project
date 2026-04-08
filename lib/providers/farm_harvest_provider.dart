import 'package:flutter/foundation.dart';

import '../models/farm_harvest_entry_model.dart';
import '../models/farm_harvest_session_model.dart';
import '../models/farm_model.dart';
import '../services/database_helper.dart';

class FarmHarvestProvider extends ChangeNotifier {
  List<FarmHarvestSession> _sessions = <FarmHarvestSession>[];
  List<FarmHarvestEntry> _entries = <FarmHarvestEntry>[];
  bool _isLoading = false;
  String? _error;

  List<FarmHarvestSession> get sessions => _sessions;
  List<FarmHarvestEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FarmHarvestSession? get activeSession {
    for (final session in _sessions) {
      if (!session.isCompleted) {
        return session;
      }
    }
    return null;
  }

  List<FarmHarvestSession> get completedSessions =>
      _sessions.where((session) => session.isCompleted).toList(growable: false);

  List<FarmHarvestEntry> entriesForSession(
    int sessionId, {
    bool includeInactive = false,
  }) {
    final filtered = _entries.where((entry) {
      if (entry.sessionId != sessionId) {
        return false;
      }
      return includeInactive || entry.isActive;
    }).toList()
      ..sort((left, right) {
        final dateCompare = right.entryDate.compareTo(left.entryDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
        final createdCompare = right.createdAt.compareTo(left.createdAt);
        if (createdCompare != 0) {
          return createdCompare;
        }
        return (right.entryId ?? 0).compareTo(left.entryId ?? 0);
      });
    return filtered;
  }

  Future<void> loadForFarm(Farm farm) async {
    final farmId = farm.id;
    if (farmId == null || farmId.isEmpty) {
      _sessions = <FarmHarvestSession>[];
      _entries = <FarmHarvestEntry>[];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final sessionRows = await db.query(
        DatabaseHelper.tableFarmHarvestSessions,
        where: 'FarmID = ?',
        whereArgs: <Object?>[farmId],
        orderBy: 'SeasonNumber DESC, StartedAt DESC, HarvestSessionID DESC',
      );

      _sessions = sessionRows.map(FarmHarvestSession.fromMap).toList();

      final sessionIds = _sessions
          .map((session) => session.sessionId)
          .whereType<int>()
          .toList(growable: false);
      if (sessionIds.isEmpty) {
        _entries = <FarmHarvestEntry>[];
      } else {
        final placeholders =
            List<String>.filled(sessionIds.length, '?').join(', ');
        final entryRows = await db.rawQuery(
          '''
          SELECT *
          FROM ${DatabaseHelper.tableFarmHarvestEntries}
          WHERE SessionID IN ($placeholders)
          ORDER BY EntryDate DESC, CreatedAt DESC, HarvestEntryID DESC
          ''',
          sessionIds,
        );
        _entries = entryRows.map(FarmHarvestEntry.fromMap).toList();
      }
    } catch (error) {
      _error = 'Failed to load harvest board.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FarmHarvestSession> startHarvest(
    Farm farm, {
    required bool isEarlyStart,
  }) async {
    final farmId = farm.id;
    if (farmId == null || farmId.isEmpty) {
      throw StateError('Farm must be saved before starting harvest.');
    }

    final existingActive = activeSession;
    if (existingActive != null) {
      return existingActive;
    }

    final session = FarmHarvestSession(
      farmId: farmId,
      farmName: farm.name,
      cropType: farm.type,
      seasonNumber: farm.seasonNumber,
      ratoonCount: farm.ratoonCount,
      status: 'ongoing',
      isEarlyStart: isEarlyStart,
      startedAt: DateTime.now(),
    );

    final db = await DatabaseHelper.instance.database;
    await db.insert(
      DatabaseHelper.tableFarmHarvestSessions,
      session.toMap(),
    );
    await loadForFarm(farm);
    return activeSession ?? session;
  }

  Future<void> addEntry(Farm farm, FarmHarvestEntry entry) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(DatabaseHelper.tableFarmHarvestEntries, entry.toMap());
    await loadForFarm(farm);
  }

  Future<void> updateEntry(Farm farm, FarmHarvestEntry entry) async {
    final entryId = entry.entryId;
    if (entryId == null) {
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseHelper.tableFarmHarvestEntries,
      entry.toMap(),
      where: 'HarvestEntryID = ?',
      whereArgs: <Object?>[entryId],
    );
    await loadForFarm(farm);
  }

  Future<void> setEntryActive(
    Farm farm,
    FarmHarvestEntry entry, {
    required bool isActive,
  }) async {
    final entryId = entry.entryId;
    if (entryId == null) {
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseHelper.tableFarmHarvestEntries,
      <String, Object?>{
        'IsActive': isActive ? 1 : 0,
        'UpdatedAt': DateTime.now().toIso8601String(),
      },
      where: 'HarvestEntryID = ?',
      whereArgs: <Object?>[entryId],
    );
    await loadForFarm(farm);
  }

  Future<void> undoLastEntry(Farm farm, int sessionId) async {
    for (final entry in entriesForSession(sessionId)) {
      if (entry.isActive) {
        await setEntryActive(farm, entry, isActive: false);
        return;
      }
    }
  }

  Future<void> redoLastEntry(Farm farm, int sessionId) async {
    for (final entry in entriesForSession(sessionId, includeInactive: true)) {
      if (!entry.isActive) {
        await setEntryActive(farm, entry, isActive: true);
        return;
      }
    }
  }

  Future<void> finishHarvest(Farm farm, FarmHarvestSession session) async {
    final sessionId = session.sessionId;
    if (sessionId == null) {
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseHelper.tableFarmHarvestSessions,
      <String, Object?>{
        'Status': 'completed',
        'CompletedAt': DateTime.now().toIso8601String(),
      },
      where: 'HarvestSessionID = ?',
      whereArgs: <Object?>[sessionId],
    );
    await loadForFarm(farm);
  }

  Future<void> restartHarvest(Farm farm, FarmHarvestSession session) async {
    final sessionId = session.sessionId;
    if (sessionId == null) {
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseHelper.tableFarmHarvestEntries,
        where: 'SessionID = ?',
        whereArgs: <Object?>[sessionId],
      );
      await txn.update(
        DatabaseHelper.tableFarmHarvestSessions,
        <String, Object?>{
          'Status': 'ongoing',
          'CompletedAt': null,
          'StartedAt': DateTime.now().toIso8601String(),
        },
        where: 'HarvestSessionID = ?',
        whereArgs: <Object?>[sessionId],
      );
    });
    await loadForFarm(farm);
  }

  Future<void> updateEarlyStart(
    Farm farm,
    FarmHarvestSession session, {
    required bool isEarlyStart,
  }) async {
    final sessionId = session.sessionId;
    if (sessionId == null) {
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.update(
      DatabaseHelper.tableFarmHarvestSessions,
      <String, Object?>{
        'IsEarlyStart': isEarlyStart ? 1 : 0,
      },
      where: 'HarvestSessionID = ?',
      whereArgs: <Object?>[sessionId],
    );
    await loadForFarm(farm);
  }

  Future<void> clearFarmHistory(Farm farm) async {
    final farmId = farm.id;
    if (farmId == null || farmId.isEmpty) {
      return;
    }
    final db = await DatabaseHelper.instance.database;
    final sessionIds = _sessions
        .map((session) => session.sessionId)
        .whereType<int>()
        .toList(growable: false);
    await db.transaction((txn) async {
      if (sessionIds.isNotEmpty) {
        final placeholders =
            List<String>.filled(sessionIds.length, '?').join(', ');
        await txn.rawDelete(
          '''
          DELETE FROM ${DatabaseHelper.tableFarmHarvestEntries}
          WHERE SessionID IN ($placeholders)
          ''',
          sessionIds,
        );
      }
      await txn.delete(
        DatabaseHelper.tableFarmHarvestSessions,
        where: 'FarmID = ?',
        whereArgs: <Object?>[farmId],
      );
    });
    await loadForFarm(farm);
  }
}
