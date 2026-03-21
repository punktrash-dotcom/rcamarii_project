import 'package:flutter/foundation.dart';

@immutable
class WorkDef {
  final String id;
  final String name;
  final String type;
  final String modeOfWork;
  final double cost;

  const WorkDef({
    required this.id,
    required this.name,
    required this.type,
    required this.modeOfWork,
    required this.cost,
  });

  factory WorkDef.fromMap(Map<String, dynamic> map) {
    return WorkDef(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      modeOfWork: map['modeOfWork']?.toString() ?? '',
      cost: double.tryParse(map['cost']?.toString() ?? '') ??
          0.0, // More robust parsing
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'modeOfWork': modeOfWork,
      'cost': cost,
    };
  }
}
