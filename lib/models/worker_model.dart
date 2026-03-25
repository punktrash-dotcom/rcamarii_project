class Worker {
  final int? id;
  final String name;
  final String address;
  final String position;
  final String cellphoneNumber;
  final String? note;

  Worker({
    this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.cellphoneNumber,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'EmployeeID': id,
      'Name': name,
      'Address': address,
      'Position': position,
      'CellphoneNumber': cellphoneNumber,
      'Note': note,
    };
  }

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      id: map['EmployeeID'],
      name: map['Name'] ?? '',
      address: map['Address'] ?? '',
      position: map['Position'] ?? '',
      cellphoneNumber: map['CellphoneNumber'] ?? '',
      note: map['Note'] as String?,
    );
  }
}
