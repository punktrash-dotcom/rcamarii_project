import 'package:flutter/foundation.dart';

@immutable
class Supply {
  final String id;
  final String name;
  final String description;
  final int quantity;
  final double cost;
  final double total;

  const Supply({
    required this.id,
    required this.name,
    required this.description,
    required this.quantity,
    required this.cost,
    required this.total,
  });

  static int _readInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // fromMap constructor for database interaction
  factory Supply.fromMap(Map<String, dynamic> map) {
    return Supply(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      quantity: _readInt(map['quantity']),
      cost: _readDouble(map['cost']),
      total: _readDouble(map['total']),
    );
  }

  // toMap method for database interaction
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'quantity': quantity,
      'cost': cost,
      'total': total,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supply && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
