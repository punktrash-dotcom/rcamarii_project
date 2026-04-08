import 'package:flutter/foundation.dart';

import '../utils/app_text_normalizer.dart';

@immutable
class FarmHarvestEntry {
  const FarmHarvestEntry({
    this.entryId,
    required this.sessionId,
    required this.entryType,
    required this.label,
    required this.quantityTons,
    required this.amount,
    required this.entryDate,
    this.note,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  final int? entryId;
  final int sessionId;
  final String entryType;
  final String label;
  final double quantityTons;
  final double amount;
  final DateTime entryDate;
  final String? note;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FarmHarvestEntry copyWith({
    int? entryId,
    int? sessionId,
    String? entryType,
    String? label,
    double? quantityTons,
    double? amount,
    DateTime? entryDate,
    String? note,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmHarvestEntry(
      entryId: entryId ?? this.entryId,
      sessionId: sessionId ?? this.sessionId,
      entryType: entryType ?? this.entryType,
      label: label ?? this.label,
      quantityTons: quantityTons ?? this.quantityTons,
      amount: amount ?? this.amount,
      entryDate: entryDate ?? this.entryDate,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FarmHarvestEntry.fromMap(Map<String, dynamic> map) {
    return FarmHarvestEntry(
      entryId: map['HarvestEntryID'] as int?,
      sessionId: (map['SessionID'] as num).toInt(),
      entryType: (map['EntryType'] ?? '').toString(),
      label: (map['Label'] ?? '').toString(),
      quantityTons: (map['QuantityTons'] as num?)?.toDouble() ?? 0,
      amount: (map['Amount'] as num?)?.toDouble() ?? 0,
      entryDate: DateTime.parse((map['EntryDate'] ?? '').toString()),
      note: map['Note'] as String?,
      isActive: ((map['IsActive'] as num?) ?? 0) == 1,
      createdAt: DateTime.parse((map['CreatedAt'] ?? '').toString()),
      updatedAt: (map['UpdatedAt'] as String?)?.trim().isNotEmpty == true
          ? DateTime.parse((map['UpdatedAt'] ?? '').toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (entryId != null) 'HarvestEntryID': entryId,
      'SessionID': sessionId,
      'EntryType': entryType,
      'Label': AppTextNormalizer.titleCase(label),
      'QuantityTons': quantityTons,
      'Amount': amount,
      'EntryDate': entryDate.toIso8601String(),
      'Note': AppTextNormalizer.nullableSentenceCase(note),
      'IsActive': isActive ? 1 : 0,
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt?.toIso8601String(),
    };
  }
}
