import 'package:flutter/foundation.dart';

import '../utils/app_text_normalizer.dart';

@immutable
class Delivery {
  final int? delId;
  final DateTime date;
  final String type;
  final String name;
  final String? ticketNo;
  final double? cost;
  final double quantity;
  final double total;
  final String? note;

  const Delivery({
    this.delId,
    required this.date,
    required this.type,
    required this.name,
    this.ticketNo,
    this.cost,
    required this.quantity,
    required this.total,
    this.note,
  });

  factory Delivery.fromMap(Map<String, dynamic> map) {
    return Delivery(
      delId: map['DelID'] as int?,
      date: DateTime.parse(map['Date'] as String),
      type: map['Type'] as String,
      name: map['Name'] as String,
      ticketNo: map['TicketNo'] as String?,
      cost: map['Cost'] == null ? null : (map['Cost'] as num).toDouble(),
      quantity: (map['Quantity'] as num).toDouble(),
      total: (map['Total'] as num).toDouble(),
      note: map['Note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (delId != null) 'DelID': delId,
      'Date': date.toIso8601String(),
      'Type': AppTextNormalizer.titleCase(type),
      'Name': AppTextNormalizer.titleCase(name),
      'TicketNo': ticketNo,
      'Cost': cost,
      'Quantity': quantity,
      'Total': total,
      'Note': AppTextNormalizer.nullableSentenceCase(note),
    };
  }
}
