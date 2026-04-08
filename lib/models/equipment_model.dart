import 'package:flutter/foundation.dart';

import '../utils/app_text_normalizer.dart';

@immutable
class Equipment {
  final String? id;
  final String type;
  final String name;
  final int quantity;
  final double cost;
  final double total;
  final String? note;

  const Equipment({
    this.id,
    required this.type,
    required this.name,
    required this.quantity,
    this.cost = 0.0,
    this.total = 0.0,
    this.note,
  });

  factory Equipment.fromMap(Map<String, dynamic> map) {
    return Equipment(
      id: map['EqID']?.toString(),
      type: map['Type'] as String? ?? '',
      name: map['Name'] as String? ?? '',
      quantity: map['Quantity'] as int? ?? 0,
      cost: (map['Cost'] as num?)?.toDouble() ?? 0.0,
      total: (map['Total'] as num?)?.toDouble() ?? 0.0,
      note: map['Note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'EqID': id,
      'Type': AppTextNormalizer.titleCase(type),
      'Name': AppTextNormalizer.titleCase(name),
      'Quantity': quantity,
      'Cost': cost,
      'Total': total,
      'Note': AppTextNormalizer.nullableSentenceCase(note),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Equipment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          name == other.name &&
          quantity == other.quantity &&
          cost == other.cost &&
          total == other.total &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      name.hashCode ^
      quantity.hashCode ^
      cost.hashCode ^
      total.hashCode ^
      note.hashCode;
}
