import 'package:flutter/foundation.dart';

@immutable
class DefSup {
  final String id;
  final String type;
  final String name;
  final String description;
  final double cost;

  const DefSup({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.cost,
  });

  factory DefSup.fromMap(Map<String, dynamic> map) {
    return DefSup(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      cost: double.tryParse(map['cost']?.toString() ?? '') ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'description': description,
      'cost': cost,
    };
  }
}
