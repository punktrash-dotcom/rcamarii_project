class Worker {
  final int? id;
  final String name;
  final String address;
  final String position;
  final String? note;

  Worker({
    this.id,
    required this.name,
    required this.address,
    required this.position,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'EmployeeID': id,
      'Name': name,
      'Address': address,
      'Position': position,
      'Note': note,
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      id: map['EmployeeID'],
      name: map['Name'] ?? '',
      address: map['Address'] ?? '',
      position: map['Position'] ?? '',
      note: map['Note'] as String?,
    );
  }
}
