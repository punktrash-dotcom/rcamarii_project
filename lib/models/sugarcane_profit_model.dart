import 'package:flutter/foundation.dart';

@immutable
class SugarcaneProfit {
  final int? profitId;
  final int? deliveryId;
  final String sourceType;
  final String sourceLabel;
  final String sourceStatus;
  final String farmName;
  final DateTime deliveryDate;
  final double netTonsCane;
  final double lkgPerTc;
  final double planterShare;
  final double sugarPricePerLkg;
  final double molassesKg;
  final double molassesPricePerKg;
  final double productionCosts;
  final double sugarProceeds;
  final double molassesProceeds;
  final double totalRevenue;
  final double netProfit;
  final String? note;
  final DateTime createdAt;

  const SugarcaneProfit({
    this.profitId,
    this.deliveryId,
    required this.sourceType,
    required this.sourceLabel,
    required this.sourceStatus,
    required this.farmName,
    required this.deliveryDate,
    required this.netTonsCane,
    required this.lkgPerTc,
    required this.planterShare,
    required this.sugarPricePerLkg,
    this.molassesKg = 0,
    this.molassesPricePerKg = 0,
    required this.productionCosts,
    required this.sugarProceeds,
    required this.molassesProceeds,
    required this.totalRevenue,
    required this.netProfit,
    this.note,
    required this.createdAt,
  });

  factory SugarcaneProfit.fromMap(Map<String, dynamic> map) {
    return SugarcaneProfit(
      profitId: map['ProfitID'] as int?,
      deliveryId: map['DeliveryID'] as int?,
      sourceType: (map['SourceType'] ?? '').toString(),
      sourceLabel: (map['SourceLabel'] ?? '').toString(),
      sourceStatus: (map['SourceStatus'] ?? '').toString(),
      farmName: (map['FarmName'] ?? '').toString(),
      deliveryDate: DateTime.parse((map['DeliveryDate'] ?? '').toString()),
      netTonsCane: (map['NetTonsCane'] as num).toDouble(),
      lkgPerTc: (map['LkgPerTc'] as num).toDouble(),
      planterShare: (map['PlanterShare'] as num).toDouble(),
      sugarPricePerLkg: (map['SugarPricePerLkg'] as num).toDouble(),
      molassesKg: (map['MolassesKg'] as num).toDouble(),
      molassesPricePerKg: (map['MolassesPricePerKg'] as num).toDouble(),
      productionCosts: (map['ProductionCosts'] as num).toDouble(),
      sugarProceeds: (map['SugarProceeds'] as num).toDouble(),
      molassesProceeds: (map['MolassesProceeds'] as num).toDouble(),
      totalRevenue: (map['TotalRevenue'] as num).toDouble(),
      netProfit: (map['NetProfit'] as num).toDouble(),
      note: map['Note'] as String?,
      createdAt: DateTime.parse((map['CreatedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (profitId != null) 'ProfitID': profitId,
      'DeliveryID': deliveryId,
      'SourceType': sourceType,
      'SourceLabel': sourceLabel,
      'SourceStatus': sourceStatus,
      'FarmName': farmName,
      'DeliveryDate': deliveryDate.toIso8601String(),
      'NetTonsCane': netTonsCane,
      'LkgPerTc': lkgPerTc,
      'PlanterShare': planterShare,
      'SugarPricePerLkg': sugarPricePerLkg,
      'MolassesKg': molassesKg,
      'MolassesPricePerKg': molassesPricePerKg,
      'ProductionCosts': productionCosts,
      'SugarProceeds': sugarProceeds,
      'MolassesProceeds': molassesProceeds,
      'TotalRevenue': totalRevenue,
      'NetProfit': netProfit,
      'Note': note,
      'CreatedAt': createdAt.toIso8601String(),
    };
  }
}
