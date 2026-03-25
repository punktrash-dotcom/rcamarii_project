import 'package:flutter/foundation.dart';

@immutable
class ProduceDelivery {
  final int? produceDeliveryId;
  final int? deliveryRefId;
  final String deliveryNo;
  final DateTime date;
  final String crop;
  final String farmName;
  final double totalSacks;
  final double grossWeight;
  final double deductionsPercent;
  final double maintainerSharePercent;
  final double harvesterSharePercent;
  final double priceOfProduce;
  final double grossSales;
  final double totalDeductions;
  final double averageWeightPerSack;
  final double netProfit;
  final bool includeOverallExpenses;
  final double prePlantingExpenses;
  final double postPlantingExpenses;
  final double overallFarmExpenses;
  final double finalProfit;
  final String? note;
  final DateTime createdAt;

  const ProduceDelivery({
    this.produceDeliveryId,
    this.deliveryRefId,
    required this.deliveryNo,
    required this.date,
    required this.crop,
    required this.farmName,
    required this.totalSacks,
    required this.grossWeight,
    required this.deductionsPercent,
    required this.maintainerSharePercent,
    required this.harvesterSharePercent,
    required this.priceOfProduce,
    required this.grossSales,
    required this.totalDeductions,
    required this.averageWeightPerSack,
    required this.netProfit,
    required this.includeOverallExpenses,
    required this.prePlantingExpenses,
    required this.overallFarmExpenses,
    required this.postPlantingExpenses,
    required this.finalProfit,
    this.note,
    required this.createdAt,
  });

  factory ProduceDelivery.fromMap(Map<String, dynamic> map) {
    return ProduceDelivery(
      produceDeliveryId: map['ProduceDeliveryID'] as int?,
      deliveryRefId: map['DeliveryRefID'] as int?,
      deliveryNo: (map['DeliveryNo'] ?? '').toString(),
      date: DateTime.parse(map['Date'] as String),
      crop: (map['Crop'] ?? '').toString(),
      farmName: (map['FarmName'] ?? '').toString(),
      totalSacks: (map['TotalSacks'] as num).toDouble(),
      grossWeight: (map['GrossWeight'] as num).toDouble(),
      deductionsPercent: (map['DeductionsPercent'] as num).toDouble(),
      maintainerSharePercent: (map['MaintainerSharePercent'] as num).toDouble(),
      harvesterSharePercent: (map['HarvesterSharePercent'] as num).toDouble(),
      priceOfProduce: (map['PriceOfProduce'] as num).toDouble(),
      grossSales: (map['GrossSales'] as num).toDouble(),
      totalDeductions: (map['TotalDeductions'] as num).toDouble(),
      averageWeightPerSack: (map['AverageWeightPerSack'] as num).toDouble(),
      netProfit: (map['NetProfit'] as num).toDouble(),
      includeOverallExpenses:
          ((map['IncludeOverallExpenses'] as num?) ?? 0) == 1,
      prePlantingExpenses:
          (map['PrePlantingExpenses'] as num?)?.toDouble() ?? 0,
      overallFarmExpenses: (map['OverallFarmExpenses'] as num).toDouble(),
      postPlantingExpenses:
          (map['PostPlantingExpenses'] as num?)?.toDouble() ?? 0,
      finalProfit: (map['FinalProfit'] as num).toDouble(),
      note: map['Note'] as String?,
      createdAt: DateTime.parse(map['CreatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (produceDeliveryId != null) 'ProduceDeliveryID': produceDeliveryId,
      'DeliveryRefID': deliveryRefId,
      'DeliveryNo': deliveryNo,
      'Date': date.toIso8601String(),
      'Crop': crop,
      'FarmName': farmName,
      'TotalSacks': totalSacks,
      'GrossWeight': grossWeight,
      'DeductionsPercent': deductionsPercent,
      'MaintainerSharePercent': maintainerSharePercent,
      'HarvesterSharePercent': harvesterSharePercent,
      'PriceOfProduce': priceOfProduce,
      'GrossSales': grossSales,
      'TotalDeductions': totalDeductions,
      'AverageWeightPerSack': averageWeightPerSack,
      'NetProfit': netProfit,
      'IncludeOverallExpenses': includeOverallExpenses ? 1 : 0,
      'PrePlantingExpenses': prePlantingExpenses,
      'OverallFarmExpenses': overallFarmExpenses,
      'PostPlantingExpenses': postPlantingExpenses,
      'FinalProfit': finalProfit,
      'Note': note,
      'CreatedAt': createdAt.toIso8601String(),
    };
  }
}
