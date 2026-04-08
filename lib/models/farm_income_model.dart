import 'package:flutter/foundation.dart';

import '../utils/app_text_normalizer.dart';

@immutable
class FarmIncome {
  final int? farmIncomeId;
  final String incomeNo;
  final DateTime date;
  final String incomeType;
  final String assetName;
  final String clientName;
  final double amount;
  final String? note;
  final DateTime createdAt;

  const FarmIncome({
    this.farmIncomeId,
    required this.incomeNo,
    required this.date,
    required this.incomeType,
    required this.assetName,
    required this.clientName,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  factory FarmIncome.fromMap(Map<String, dynamic> map) {
    return FarmIncome(
      farmIncomeId: map['FarmIncomeID'] as int?,
      incomeNo: (map['IncomeNo'] ?? '').toString(),
      date: DateTime.parse(map['Date'] as String),
      incomeType: (map['IncomeType'] ?? '').toString(),
      assetName: (map['AssetName'] ?? '').toString(),
      clientName: (map['ClientName'] ?? '').toString(),
      amount: (map['Amount'] as num).toDouble(),
      note: map['Note'] as String?,
      createdAt: DateTime.parse(map['CreatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (farmIncomeId != null) 'FarmIncomeID': farmIncomeId,
      'IncomeNo': incomeNo,
      'Date': date.toIso8601String(),
      'IncomeType': AppTextNormalizer.titleCase(incomeType),
      'AssetName': AppTextNormalizer.titleCase(assetName),
      'ClientName': AppTextNormalizer.titleCase(clientName),
      'Amount': amount,
      'Note': AppTextNormalizer.nullableSentenceCase(note),
      'CreatedAt': createdAt.toIso8601String(),
    };
  }
}
