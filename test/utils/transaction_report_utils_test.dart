import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/models/ftracker_model.dart';
import 'package:nmd/utils/transaction_report_utils.dart';

void main() {
  final records = [
    Ftracker(
      transid: 1,
      date: DateTime(2026, 3, 10),
      type: 'Income',
      category: 'Farm',
      name: 'Delivery A',
      amount: 12000,
      note: 'Delivery A',
    ),
    Ftracker(
      transid: 2,
      date: DateTime(2026, 3, 11),
      type: 'Expenses',
      category: 'Supplies',
      name: 'Fertilizer',
      amount: 3000,
      note: 'Fertilizer',
    ),
    Ftracker(
      transid: 3,
      date: DateTime(2026, 3, 12),
      type: 'Income',
      category: 'Farm',
      name: 'Delivery B',
      amount: 8000,
      note: 'Delivery B',
    ),
    Ftracker(
      transid: 4,
      date: DateTime(2026, 3, 13),
      type: 'Expenses',
      category: 'Labor',
      name: 'Crew',
      amount: 2500,
      note: 'Crew',
    ),
  ];

  test('buildTransactionReport aggregates revenue, expenses, and categories',
      () {
    final report = buildTransactionReport(records);

    expect(report.totalRevenue, 20000);
    expect(report.totalExpenses, 5500);
    expect(report.netBalance, 14500);
    expect(report.transactionCount, 4);
    expect(report.categoryComparisons.first.category, 'Farm');
    expect(report.expenseCategories.first.category, 'Supplies');
    expect(report.revenueCategories.first.category, 'Farm');
  });

  test('buildTransactionReport applies category and date filters', () {
    final report = buildTransactionReport(
      records,
      categoryFilter: 'Farm',
      dateRange: DateTimeRange(
        start: DateTime(2026, 3, 10),
        end: DateTime(2026, 3, 12),
      ),
    );

    expect(report.transactionCount, 2);
    expect(report.totalRevenue, 20000);
    expect(report.totalExpenses, 0);
    expect(report.records.every((record) => record.category == 'Farm'), isTrue);
  });
}
