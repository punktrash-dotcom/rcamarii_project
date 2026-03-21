import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/models/ftracker_model.dart';

void main() {
  test('fromMap derives a usable name from legacy ledger rows', () {
    final record = Ftracker.fromMap({
      'TransID': 1,
      'Date': '2026-03-15T00:00:00.000',
      'Type': 'Expenses',
      'Category': 'Supplies',
      'Amount': 2500.0,
      'Note': 'Fertilizer',
    });

    expect(record.name, 'Fertilizer');
    expect(record.category, 'Supplies');
    expect(record.note, 'Fertilizer');
  });

  test('toMap persists the updated Ftracker shape', () {
    final record = Ftracker(
      transid: 1,
      date: DateTime(2026, 3, 15),
      type: 'Income',
      category: 'Farm',
      name: 'Batch A',
      amount: 4200,
      note: 'Batch A',
    );

    final map = record.toMap();
    expect(map.containsKey('Farm'), isFalse);
    expect(map['Category'], 'Farm');
    expect(map['Name'], 'Batch A');
  });
}
