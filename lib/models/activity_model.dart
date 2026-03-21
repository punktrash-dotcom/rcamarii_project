import 'package:flutter/foundation.dart';

@immutable
class Activity {
  final String jobId;
  final String tag;
  final DateTime date;
  final String farm;
  final String name;
  final String labor;
  final String assetUsed;
  final String costType;
  final double duration;
  final double cost;
  final double total;
  final String worker;
  final String? note;

  const Activity({
    required this.jobId,
    required this.tag,
    required this.date,
    required this.farm,
    required this.name,
    required this.labor,
    required this.assetUsed,
    required this.costType,
    required this.duration,
    required this.cost,
    required this.total,
    this.worker = '',
    this.note,
  });

  static double _readDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // fromMap constructor
  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      jobId: map['jobId'] as String,
      tag: map['tag'] as String,
      date: DateTime.parse(map['date'] as String),
      farm: map['farm'] as String,
      name: map['name'] as String,
      labor: map['labor'] as String,
      assetUsed: map['assetUsed'] as String,
      costType: map['costType'] as String,
      duration: _readDouble(map['duration']),
      cost: _readDouble(map['cost']),
      total: _readDouble(map['total']),
      worker: (map['worker'] ?? '').toString(),
      note: map['note'] as String?,
    );
  }

  // toMap method
  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'tag': tag,
      'date': date.toIso8601String(),
      'farm': farm,
      'name': name,
      'labor': labor,
      'assetUsed': assetUsed,
      'costType': costType,
      'duration': duration,
      'cost': cost,
      'total': total,
      'worker': worker,
      'note': note,
    };
  }
}
