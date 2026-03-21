import 'package:flutter/foundation.dart';
import '../models/activity_model.dart';
import '../services/database_helper.dart';
import '../services/transaction_log_service.dart';

class ActivityProvider with ChangeNotifier {
  List<Activity> _activities = [];
  bool _isLoading = false;

  List<Activity> get activities => _activities;
  bool get isLoading => _isLoading;

  Future<void> loadActivities() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query('Activities');
      _activities = data.map((row) => Activity.fromMap(row)).toList();
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addActivity(Activity activity) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('Activities', activity.toMap());
    _activities.add(activity);
    notifyListeners();
    TransactionLogService.instance.log('Activity added',
        details:
            '${activity.name} @ ${activity.farm} • ${activity.labor} • ₱${activity.total.toStringAsFixed(2)}');
  }

  Future<void> updateActivity(Activity activity) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'Activities',
      activity.toMap(),
      where: 'jobId = ?',
      whereArgs: [activity.jobId],
    );
    final index = _activities.indexWhere((a) => a.jobId == activity.jobId);
    if (index != -1) {
      _activities[index] = activity;
      notifyListeners();
      TransactionLogService.instance.log('Activity updated',
          details: '${activity.jobId} • ${activity.name} • ${activity.farm}');
    }
  }

  Future<void> deleteActivity(String jobId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Activities', where: 'jobId = ?', whereArgs: [jobId]);
    _activities.removeWhere((a) => a.jobId == jobId);
    notifyListeners();
    TransactionLogService.instance
        .log('Activity deleted', details: 'jobId=$jobId');
  }

  Activity? getActivityById(String jobId) {
    try {
      return _activities.firstWhere((a) => a.jobId == jobId);
    } catch (e) {
      return null;
    }
  }
}
