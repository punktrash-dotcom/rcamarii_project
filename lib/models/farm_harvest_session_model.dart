import 'package:flutter/foundation.dart';

@immutable
class FarmHarvestSession {
  const FarmHarvestSession({
    this.sessionId,
    required this.farmId,
    required this.farmName,
    required this.cropType,
    required this.seasonNumber,
    required this.ratoonCount,
    required this.status,
    required this.isEarlyStart,
    required this.startedAt,
    this.completedAt,
    this.note,
  });

  final int? sessionId;
  final String farmId;
  final String farmName;
  final String cropType;
  final int seasonNumber;
  final int ratoonCount;
  final String status;
  final bool isEarlyStart;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? note;

  bool get isCompleted => status.toLowerCase() == 'completed';

  FarmHarvestSession copyWith({
    int? sessionId,
    String? farmId,
    String? farmName,
    String? cropType,
    int? seasonNumber,
    int? ratoonCount,
    String? status,
    bool? isEarlyStart,
    DateTime? startedAt,
    DateTime? completedAt,
    String? note,
  }) {
    return FarmHarvestSession(
      sessionId: sessionId ?? this.sessionId,
      farmId: farmId ?? this.farmId,
      farmName: farmName ?? this.farmName,
      cropType: cropType ?? this.cropType,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      ratoonCount: ratoonCount ?? this.ratoonCount,
      status: status ?? this.status,
      isEarlyStart: isEarlyStart ?? this.isEarlyStart,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }

  factory FarmHarvestSession.fromMap(Map<String, dynamic> map) {
    return FarmHarvestSession(
      sessionId: map['HarvestSessionID'] as int?,
      farmId: (map['FarmID'] ?? '').toString(),
      farmName: (map['FarmName'] ?? '').toString(),
      cropType: (map['CropType'] ?? '').toString(),
      seasonNumber: (map['SeasonNumber'] as num?)?.toInt() ?? 1,
      ratoonCount: (map['RatoonCount'] as num?)?.toInt() ?? 0,
      status: (map['Status'] ?? '').toString(),
      isEarlyStart: ((map['IsEarlyStart'] as num?) ?? 0) == 1,
      startedAt: DateTime.parse((map['StartedAt'] ?? '').toString()),
      completedAt: (map['CompletedAt'] as String?)?.trim().isNotEmpty == true
          ? DateTime.parse((map['CompletedAt'] ?? '').toString())
          : null,
      note: map['Note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (sessionId != null) 'HarvestSessionID': sessionId,
      'FarmID': farmId,
      'FarmName': farmName,
      'CropType': cropType,
      'SeasonNumber': seasonNumber,
      'RatoonCount': ratoonCount,
      'Status': status,
      'IsEarlyStart': isEarlyStart ? 1 : 0,
      'StartedAt': startedAt.toIso8601String(),
      'CompletedAt': completedAt?.toIso8601String(),
      'Note': note,
    };
  }
}
