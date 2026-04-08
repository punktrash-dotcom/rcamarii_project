import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../utils/app_text_normalizer.dart';

@immutable
class Ftracker {
  final int? transid;
  final DateTime date;
  final String type;
  final String category;
  final String name;
  final double amount;
  final String? note;

  const Ftracker({
    this.transid,
    required this.date,
    required this.type,
    required this.category,
    required this.name,
    required this.amount,
    this.note,
  });

  static String _resolveName(Map<String, dynamic> map) {
    final candidates = [
      map['Name'],
      map['Note'],
      map['Category'],
      map['Type'],
    ];

    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return 'Unspecified';
  }

  factory Ftracker.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['Date'] as String);
    } catch (e) {
      try {
        parsedDate = DateFormat('MM/dd/yyyy').parse(map['Date'] as String);
      } catch (e) {
        try {
          parsedDate = DateFormat.yMMMd().parse(map['Date'] as String);
        } catch (e) {
          parsedDate = DateTime.now();
        }
      }
    }
    return Ftracker(
      transid: map['TransID'],
      date: parsedDate,
      type: map['Type'] as String,
      category: map['Category'] as String,
      name: _resolveName(map),
      amount: (map['Amount'] as num).toDouble(),
      note: map['Note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'TransID': transid,
      'Date': date.toIso8601String(),
      'Type': AppTextNormalizer.titleCase(type),
      'Category': AppTextNormalizer.titleCase(category),
      'Name': AppTextNormalizer.titleCase(name),
      'Amount': amount,
      'Note': AppTextNormalizer.nullableSentenceCase(note),
    };
  }
}
