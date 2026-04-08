import 'package:flutter/foundation.dart';

import '../utils/app_text_normalizer.dart';

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
      type: (map['type'] ?? map['Type'])?.toString() ?? '',
      name: (map['name'] ?? map['Name'])?.toString() ?? '',
      description: (map['description'] ?? map['Description'])?.toString() ?? '',
      cost: double.tryParse((map['cost'] ?? map['Cost'])?.toString() ?? '') ??
          0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': AppTextNormalizer.titleCase(type),
      'name': AppTextNormalizer.titleCase(name),
      'description': AppTextNormalizer.sentenceCase(description),
      'Cost': cost,
    };
  }
}
