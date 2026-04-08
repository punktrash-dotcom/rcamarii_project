import 'package:flutter/foundation.dart';

import '../utils/app_text_normalizer.dart';

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
      id: map['id']?.toString() ?? map['WorkID']?.toString() ?? '',
      name: (map['name'] ?? map['Name'])?.toString() ?? '',
      type: (map['type'] ?? map['Type'])?.toString() ?? '',
      modeOfWork: (map['modeOfWork'] ?? map['ModeOfWork'])?.toString() ?? '',
      cost: double.tryParse((map['cost'] ?? map['Cost'])?.toString() ?? '') ??
          0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': AppTextNormalizer.titleCase(name),
      'type': AppTextNormalizer.titleCase(type),
      'ModeOfWork': AppTextNormalizer.titleCase(modeOfWork),
      'Cost': cost,
    };
  }
}
