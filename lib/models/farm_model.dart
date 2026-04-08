import 'package:flutter/foundation.dart';

import '../utils/app_text_normalizer.dart';

@immutable
class Farm {
  final String? id;
  final String name;
  final String type;
  final double area;
  final String city;
  final String province;
  final DateTime date;
  final String owner;
  final int ratoonCount;
  final int seasonNumber;

  const Farm({
    this.id,
    required this.name,
    required this.type,
    required this.area,
    required this.city,
    required this.province,
    required this.date,
    required this.owner,
    this.ratoonCount = 0,
    this.seasonNumber = 1,
  });

  Farm copyWith({
    String? id,
    String? name,
    String? type,
    double? area,
    String? city,
    String? province,
    DateTime? date,
    String? owner,
    int? ratoonCount,
    int? seasonNumber,
  }) {
    return Farm(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      area: area ?? this.area,
      city: city ?? this.city,
      province: province ?? this.province,
      date: date ?? this.date,
      owner: owner ?? this.owner,
      ratoonCount: ratoonCount ?? this.ratoonCount,
      seasonNumber: seasonNumber ?? this.seasonNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Farm &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          area == other.area &&
          city == other.city &&
          province == other.province &&
          date == other.date &&
          owner == other.owner &&
          ratoonCount == other.ratoonCount &&
          seasonNumber == other.seasonNumber;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      area.hashCode ^
      city.hashCode ^
      province.hashCode ^
      date.hashCode ^
      owner.hashCode ^
      ratoonCount.hashCode ^
      seasonNumber.hashCode;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': int.tryParse(id!),
      'name': AppTextNormalizer.titleCase(name),
      'type': AppTextNormalizer.titleCase(type),
      'area': area,
      'city': AppTextNormalizer.titleCase(city),
      'province': AppTextNormalizer.titleCase(province),
      'date': date.toIso8601String(),
      'owner': AppTextNormalizer.titleCase(owner),
      'RatoonCount': ratoonCount,
      'SeasonNumber': seasonNumber,
    };
  }

  factory Farm.fromMap(Map<String, dynamic> map) {
    return Farm(
      id: map['id'].toString(),
      name: (map['name'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      area: (map['area'] as num).toDouble(),
      city: (map['city'] ?? '').toString(),
      province: (map['province'] ?? '').toString(),
      date: DateTime.parse((map['date'] ?? '').toString()),
      owner: (map['owner'] ?? '').toString(),
      ratoonCount: (map['RatoonCount'] as num?)?.toInt() ?? 0,
      seasonNumber: (map['SeasonNumber'] as num?)?.toInt() ?? 1,
    );
  }
}
