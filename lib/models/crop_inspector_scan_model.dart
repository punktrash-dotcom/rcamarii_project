import 'dart:convert';

import 'package:flutter/foundation.dart';

enum CropInspectorEngine { tflite, heuristic }

enum CropInspectorSyncStatus { localOnly, pending, synced, failed }

String cropInspectorEngineValue(CropInspectorEngine engine) => switch (engine) {
      CropInspectorEngine.tflite => 'tflite',
      CropInspectorEngine.heuristic => 'heuristic',
    };

CropInspectorEngine cropInspectorEngineFromValue(String value) {
  return CropInspectorEngine.values.firstWhere(
    (engine) => cropInspectorEngineValue(engine) == value,
    orElse: () => CropInspectorEngine.heuristic,
  );
}

String cropInspectorSyncStatusValue(CropInspectorSyncStatus status) =>
    switch (status) {
      CropInspectorSyncStatus.localOnly => 'local_only',
      CropInspectorSyncStatus.pending => 'pending',
      CropInspectorSyncStatus.synced => 'synced',
      CropInspectorSyncStatus.failed => 'failed',
    };

CropInspectorSyncStatus cropInspectorSyncStatusFromValue(String value) {
  return CropInspectorSyncStatus.values.firstWhere(
    (status) => cropInspectorSyncStatusValue(status) == value,
    orElse: () => CropInspectorSyncStatus.localOnly,
  );
}

@immutable
class CropInspectorPrediction {
  const CropInspectorPrediction({
    required this.key,
    required this.title,
    required this.category,
    required this.score,
    required this.summary,
    required this.recommendations,
  });

  final String key;
  final String title;
  final String category;
  final double score;
  final String summary;
  final List<String> recommendations;

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'category': category,
      'score': score,
      'summary': summary,
      'recommendations': recommendations,
    };
  }

  factory CropInspectorPrediction.fromJson(Map<String, dynamic> json) {
    return CropInspectorPrediction(
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      summary: (json['summary'] ?? '').toString(),
      recommendations: ((json['recommendations'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

@immutable
class CropInspectorDiagnosis {
  const CropInspectorDiagnosis({
    required this.farmName,
    required this.cropType,
    required this.imagePath,
    required this.ageInDays,
    required this.engine,
    required this.primaryPrediction,
    required this.predictions,
    required this.summary,
    required this.confidence,
    required this.confidenceLabel,
    required this.findings,
    required this.recommendations,
    required this.captureTips,
    required this.analyzedAt,
    this.engineDetail,
  });

  final String farmName;
  final String cropType;
  final String imagePath;
  final int ageInDays;
  final CropInspectorEngine engine;
  final CropInspectorPrediction primaryPrediction;
  final List<CropInspectorPrediction> predictions;
  final String summary;
  final double confidence;
  final String confidenceLabel;
  final List<String> findings;
  final List<String> recommendations;
  final List<String> captureTips;
  final DateTime analyzedAt;
  final String? engineDetail;

  String get primaryLabel => primaryPrediction.title;
  String get primaryCategory => primaryPrediction.category;

  Map<String, dynamic> toJson() {
    return {
      'farmName': farmName,
      'cropType': cropType,
      'imagePath': imagePath,
      'ageInDays': ageInDays,
      'engine': cropInspectorEngineValue(engine),
      'primaryPrediction': primaryPrediction.toJson(),
      'predictions': predictions.map((prediction) => prediction.toJson()).toList(),
      'summary': summary,
      'confidence': confidence,
      'confidenceLabel': confidenceLabel,
      'findings': findings,
      'recommendations': recommendations,
      'captureTips': captureTips,
      'analyzedAt': analyzedAt.toIso8601String(),
      'engineDetail': engineDetail,
    };
  }

  String encode() => jsonEncode(toJson());

  factory CropInspectorDiagnosis.fromJson(Map<String, dynamic> json) {
    return CropInspectorDiagnosis(
      farmName: (json['farmName'] ?? '').toString(),
      cropType: (json['cropType'] ?? '').toString(),
      imagePath: (json['imagePath'] ?? '').toString(),
      ageInDays: (json['ageInDays'] as num?)?.toInt() ?? 0,
      engine: cropInspectorEngineFromValue((json['engine'] ?? '').toString()),
      primaryPrediction: CropInspectorPrediction.fromJson(
        Map<String, dynamic>.from(
          (json['primaryPrediction'] as Map<dynamic, dynamic>?) ?? const {},
        ),
      ),
      predictions: ((json['predictions'] as List<dynamic>?) ?? const [])
          .map(
            (item) => CropInspectorPrediction.fromJson(
              Map<String, dynamic>.from(
                (item as Map<dynamic, dynamic>?) ?? const {},
              ),
            ),
          )
          .toList(growable: false),
      summary: (json['summary'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      confidenceLabel: (json['confidenceLabel'] ?? '').toString(),
      findings: ((json['findings'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      recommendations: ((json['recommendations'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      captureTips: ((json['captureTips'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      analyzedAt: DateTime.tryParse((json['analyzedAt'] ?? '').toString()) ??
          DateTime.now(),
      engineDetail: json['engineDetail']?.toString(),
    );
  }

  factory CropInspectorDiagnosis.decode(String source) {
    return CropInspectorDiagnosis.fromJson(
      Map<String, dynamic>.from(jsonDecode(source) as Map),
    );
  }
}

@immutable
class CropInspectorScanRecord {
  const CropInspectorScanRecord({
    this.id,
    required this.diagnosis,
    required this.syncStatus,
    required this.createdAt,
    this.syncedAt,
    this.syncError,
  });

  final int? id;
  final CropInspectorDiagnosis diagnosis;
  final CropInspectorSyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String? syncError;

  CropInspectorScanRecord copyWith({
    int? id,
    CropInspectorDiagnosis? diagnosis,
    CropInspectorSyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? syncedAt,
    String? syncError,
    bool clearSyncError = false,
  }) {
    return CropInspectorScanRecord(
      id: id ?? this.id,
      diagnosis: diagnosis ?? this.diagnosis,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      syncError: clearSyncError ? null : syncError ?? this.syncError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'ScanID': id,
      'FarmName': diagnosis.farmName,
      'CropType': diagnosis.cropType,
      'ImagePath': diagnosis.imagePath,
      'Engine': cropInspectorEngineValue(diagnosis.engine),
      'PrimaryLabel': diagnosis.primaryLabel,
      'PrimaryCategory': diagnosis.primaryCategory,
      'Confidence': diagnosis.confidence,
      'ConfidenceLabel': diagnosis.confidenceLabel,
      'Summary': diagnosis.summary,
      'DiagnosisJson': diagnosis.encode(),
      'SyncStatus': cropInspectorSyncStatusValue(syncStatus),
      'SyncError': syncError,
      'CreatedAt': createdAt.toIso8601String(),
      'SyncedAt': syncedAt?.toIso8601String(),
    };
  }

  factory CropInspectorScanRecord.fromMap(Map<String, dynamic> map) {
    return CropInspectorScanRecord(
      id: (map['ScanID'] as num?)?.toInt(),
      diagnosis: CropInspectorDiagnosis.decode(
        (map['DiagnosisJson'] ?? '{}').toString(),
      ),
      syncStatus:
          cropInspectorSyncStatusFromValue((map['SyncStatus'] ?? '').toString()),
      createdAt: DateTime.tryParse((map['CreatedAt'] ?? '').toString()) ??
          DateTime.now(),
      syncedAt: DateTime.tryParse((map['SyncedAt'] ?? '').toString()),
      syncError: map['SyncError']?.toString(),
    );
  }
}
