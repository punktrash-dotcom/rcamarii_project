import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ftracker_model.dart';

const allCategoriesFilter = 'All Categories';

TransactionReportSnapshot buildTransactionReport(
  List<Ftracker> records, {
  DateTimeRange? dateRange,
  String categoryFilter = allCategoriesFilter,
}) {
  final filteredRecords = records.where((record) {
    final matchesCategory = categoryFilter == allCategoriesFilter ||
        record.category == categoryFilter;
    final matchesDate = dateRange == null ||
        (!record.date.isBefore(_startOfDay(dateRange.start)) &&
            !record.date.isAfter(_endOfDay(dateRange.end)));
    return matchesCategory && matchesDate;
  }).toList()
    ..sort((a, b) {
      final dateComparison = b.date.compareTo(a.date);
      if (dateComparison != 0) return dateComparison;
      return (b.transid ?? 0).compareTo(a.transid ?? 0);
    });

  final totalRevenue = filteredRecords
      .where(isIncomeRecord)
      .fold<double>(0.0, (sum, item) => sum + item.amount);
  final totalExpenses = filteredRecords
      .where(isExpenseRecord)
      .fold<double>(0.0, (sum, item) => sum + item.amount);

  return TransactionReportSnapshot(
    records: filteredRecords,
    totalRevenue: totalRevenue,
    totalExpenses: totalExpenses,
    trendPoints: _buildTrendPoints(filteredRecords, dateRange),
    categoryComparisons: _buildCategoryComparisons(filteredRecords),
    revenueCategories: _buildCategorySummaries(filteredRecords, income: true),
    expenseCategories: _buildCategorySummaries(filteredRecords, income: false),
  );
}

bool isIncomeRecord(Ftracker record) {
  final normalizedType = record.type.toLowerCase().trim();
  return normalizedType.contains('income') ||
      normalizedType.contains('revenue');
}

bool isExpenseRecord(Ftracker record) {
  final normalizedType = record.type.toLowerCase().trim();
  return normalizedType.contains('expens');
}

class TransactionReportSnapshot {
  const TransactionReportSnapshot({
    required this.records,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.trendPoints,
    required this.categoryComparisons,
    required this.revenueCategories,
    required this.expenseCategories,
  });

  final List<Ftracker> records;
  final double totalRevenue;
  final double totalExpenses;
  final List<TrendPoint> trendPoints;
  final List<CategoryComparison> categoryComparisons;
  final List<CategorySummary> revenueCategories;
  final List<CategorySummary> expenseCategories;

  double get netBalance => totalRevenue - totalExpenses;
  int get transactionCount => records.length;
}

class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.revenue,
    required this.expenses,
  });

  final String label;
  final double revenue;
  final double expenses;
}

class CategoryComparison {
  const CategoryComparison({
    required this.category,
    required this.revenue,
    required this.expenses,
    required this.transactionCount,
  });

  final String category;
  final double revenue;
  final double expenses;
  final int transactionCount;

  double get net => revenue - expenses;
  double get volume => revenue + expenses;
}

class CategorySummary {
  const CategorySummary({
    required this.category,
    required this.amount,
    required this.transactionCount,
  });

  final String category;
  final double amount;
  final int transactionCount;
}

enum _TrendGrouping { daily, weekly, monthly }

List<TrendPoint> _buildTrendPoints(
  List<Ftracker> records,
  DateTimeRange? dateRange,
) {
  if (records.isEmpty) {
    return const [];
  }

  final earliestRecord = records
      .map((record) => record.date)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final latestRecord = records
      .map((record) => record.date)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final start = dateRange != null
      ? _startOfDay(dateRange.start)
      : _startOfDay(earliestRecord);
  final end =
      dateRange != null ? _endOfDay(dateRange.end) : _endOfDay(latestRecord);
  final spanDays = end.difference(start).inDays + 1;
  final grouping = spanDays <= 14
      ? _TrendGrouping.daily
      : spanDays <= 120
          ? _TrendGrouping.weekly
          : _TrendGrouping.monthly;

  final bucketMap = <DateTime, _BucketTotals>{};
  for (final record in records) {
    final bucket = _bucketStart(record.date, grouping);
    final totals = bucketMap.putIfAbsent(bucket, () => const _BucketTotals());
    bucketMap[bucket] = _BucketTotals(
      revenue: totals.revenue + (isIncomeRecord(record) ? record.amount : 0.0),
      expenses:
          totals.expenses + (isExpenseRecord(record) ? record.amount : 0.0),
    );
  }

  final buckets = <DateTime>[];
  var cursor = _bucketStart(start, grouping);
  final lastBucket = _bucketStart(end, grouping);
  while (!cursor.isAfter(lastBucket)) {
    buckets.add(cursor);
    cursor = _nextBucket(cursor, grouping);
  }

  return buckets.map((bucket) {
    final totals = bucketMap[bucket] ?? const _BucketTotals();
    return TrendPoint(
      label: _bucketLabel(bucket, grouping),
      revenue: totals.revenue,
      expenses: totals.expenses,
    );
  }).toList();
}

List<CategoryComparison> _buildCategoryComparisons(List<Ftracker> records) {
  final summary = <String, _CategoryComparisonAccumulator>{};
  for (final record in records) {
    final category =
        record.category.trim().isEmpty ? 'Uncategorized' : record.category;
    final current = summary.putIfAbsent(
      category,
      () => const _CategoryComparisonAccumulator(),
    );
    summary[category] = _CategoryComparisonAccumulator(
      revenue: current.revenue + (isIncomeRecord(record) ? record.amount : 0.0),
      expenses:
          current.expenses + (isExpenseRecord(record) ? record.amount : 0.0),
      transactionCount: current.transactionCount + 1,
    );
  }

  final comparisons = summary.entries
      .map(
        (entry) => CategoryComparison(
          category: entry.key,
          revenue: entry.value.revenue,
          expenses: entry.value.expenses,
          transactionCount: entry.value.transactionCount,
        ),
      )
      .toList()
    ..sort((a, b) {
      final volumeComparison = b.volume.compareTo(a.volume);
      if (volumeComparison != 0) return volumeComparison;
      return a.category.compareTo(b.category);
    });
  return comparisons;
}

List<CategorySummary> _buildCategorySummaries(
  List<Ftracker> records, {
  required bool income,
}) {
  final summary = <String, _CategoryAccumulator>{};
  final filtered = records.where(income ? isIncomeRecord : isExpenseRecord);
  for (final record in filtered) {
    final category =
        record.category.trim().isEmpty ? 'Uncategorized' : record.category;
    final current =
        summary.putIfAbsent(category, () => const _CategoryAccumulator());
    summary[category] = _CategoryAccumulator(
      amount: current.amount + record.amount,
      transactionCount: current.transactionCount + 1,
    );
  }

  final categorySummaries = summary.entries
      .map(
        (entry) => CategorySummary(
          category: entry.key,
          amount: entry.value.amount,
          transactionCount: entry.value.transactionCount,
        ),
      )
      .toList()
    ..sort((a, b) {
      final amountComparison = b.amount.compareTo(a.amount);
      if (amountComparison != 0) return amountComparison;
      return a.category.compareTo(b.category);
    });
  return categorySummaries;
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _endOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

DateTime _bucketStart(DateTime value, _TrendGrouping grouping) {
  switch (grouping) {
    case _TrendGrouping.daily:
      return _startOfDay(value);
    case _TrendGrouping.weekly:
      final normalized = _startOfDay(value);
      return normalized.subtract(Duration(days: normalized.weekday - 1));
    case _TrendGrouping.monthly:
      return DateTime(value.year, value.month);
  }
}

DateTime _nextBucket(DateTime value, _TrendGrouping grouping) {
  switch (grouping) {
    case _TrendGrouping.daily:
      return value.add(const Duration(days: 1));
    case _TrendGrouping.weekly:
      return value.add(const Duration(days: 7));
    case _TrendGrouping.monthly:
      return DateTime(value.year, value.month + 1);
  }
}

String _bucketLabel(DateTime value, _TrendGrouping grouping) {
  switch (grouping) {
    case _TrendGrouping.daily:
      return DateFormat('MMM d').format(value);
    case _TrendGrouping.weekly:
      return DateFormat('MMM d').format(value);
    case _TrendGrouping.monthly:
      return DateFormat('MMM').format(value);
  }
}

class _BucketTotals {
  const _BucketTotals({
    this.revenue = 0.0,
    this.expenses = 0.0,
  });

  final double revenue;
  final double expenses;
}

class _CategoryComparisonAccumulator {
  const _CategoryComparisonAccumulator({
    this.revenue = 0.0,
    this.expenses = 0.0,
    this.transactionCount = 0,
  });

  final double revenue;
  final double expenses;
  final int transactionCount;
}

class _CategoryAccumulator {
  const _CategoryAccumulator({
    this.amount = 0.0,
    this.transactionCount = 0,
  });

  final double amount;
  final int transactionCount;
}
