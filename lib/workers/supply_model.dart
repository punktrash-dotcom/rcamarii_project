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

  // fromMap constructor for database interaction
  factory Supply.fromMap(Map<String, dynamic> map) {
    return Supply(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      quantity: map['quantity'] as int,
      cost: map['cost'] as double,
      total: map['total'] as double,
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
