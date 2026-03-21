import 'package:flutter/foundation.dart';

@immutable
class Equipment {
  final String? id;
  final String type;
  final String name;
  final int quantity;
  final String? note;

  const Equipment({
    this.id,
    required this.type,
    required this.name,
    required this.quantity,
    this.note,
  });

  factory Equipment.fromMap(Map<String, dynamic> map) {
    return Equipment(
      id: map['EqID']?.toString(),
      type: map['Type'] as String,
      name: map['Name'] as String,
      quantity: map['Quantity'] as int,
      note: map['Note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'EqID': id,
      'Type': type,
      'Name': name,
      'Quantity': quantity,
      'Note': note,
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
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      name.hashCode ^
      quantity.hashCode ^
      note.hashCode;
}
