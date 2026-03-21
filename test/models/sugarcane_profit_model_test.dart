import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/models/sugarcane_profit_model.dart';

void main() {
  test('fromMap reads a linked sugarcane profit record', () {
    final record = SugarcaneProfit.fromMap({
      'ProfitID': 7,
      'DeliveryID': 42,
      'SourceType': 'delivery',
      'SourceLabel': 'Farm A | Mar 15, 2026 | 120 tons | Recent',
      'SourceStatus': 'recent',
      'FarmName': 'Farm A',
      'DeliveryDate': '2026-03-15T00:00:00.000',
      'NetTonsCane': 120,
      'LkgPerTc': 1.9,
      'PlanterShare': 70,
      'SugarPricePerLkg': 50,
      'MolassesKg': 20,
      'MolassesPricePerKg': 5,
      'ProductionCosts': 1000,
      'SugarProceeds': 7980,
      'MolassesProceeds': 100,
      'TotalRevenue': 8080,
      'NetProfit': 7080,
      'Note': 'Created from logistics',
      'CreatedAt': '2026-03-15T12:00:00.000',
    });

    expect(record.deliveryId, 42);
    expect(record.farmName, 'Farm A');
    expect(record.netProfit, 7080);
  });

  test('toMap preserves manual source records for storage', () {
    final record = SugarcaneProfit(
      sourceType: 'manual',
      sourceLabel: 'Standalone profit record',
      sourceStatus: 'manual',
      farmName: 'Standalone profit record',
      deliveryDate: DateTime(2026, 3, 16),
      netTonsCane: 100,
      lkgPerTc: 2,
      planterShare: 70,
      sugarPricePerLkg: 50,
      productionCosts: 1000,
      sugarProceeds: 7000,
      molassesProceeds: 0,
      totalRevenue: 7000,
      netProfit: 6000,
      createdAt: DateTime(2026, 3, 16, 8),
    );

    final map = record.toMap();

    expect(map['DeliveryID'], isNull);
    expect(map['SourceType'], 'manual');
    expect(map['NetTonsCane'], 100);
  });
}
