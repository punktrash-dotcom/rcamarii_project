import 'package:flutter/foundation.dart';

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

  const Farm({
    this.id,
    required this.name,
    required this.type,
    required this.area,
    required this.city,
    required this.province,
    required this.date,
    required this.owner,
  });

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
          owner == other.owner;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      area.hashCode ^
      city.hashCode ^
      province.hashCode ^
      date.hashCode ^
      owner.hashCode;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': int.tryParse(id!),
      'name': name,
      'type': type,
      'area': area,
      'city': city,
      'province': province,
      'date': date.toIso8601String(),
      'owner': owner,
    };
  }

  factory Farm.fromMap(Map<String, dynamic> map) {
    return Farm(
      id: map['id'].toString(),
      name: map['name'],
      type: map['type'],
      area: map['area'],
      city: map['city'],
      province: map['province'],
      date: DateTime.parse(map['date']),
      owner: map['owner'],
    );
  }
}
