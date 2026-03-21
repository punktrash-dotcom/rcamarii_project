import 'dart:developer' as developer;

class TransactionEntry {
  final DateTime timestamp;
  final String action;
  final String details;

  TransactionEntry(this.action, this.details) : timestamp = DateTime.now();

  @override
  String toString() =>
      '${timestamp.toIso8601String()} | $action${details.isNotEmpty ? ' -> $details' : ''}';
}

class TransactionLogService {
  TransactionLogService._();

  static final TransactionLogService instance = TransactionLogService._();

  final List<TransactionEntry> _entries = [];

  List<TransactionEntry> get entries => List.unmodifiable(_entries);

  void log(String action, {String details = ''}) {
    final entry = TransactionEntry(action, details);
    _entries.add(entry);
    developer.log(entry.toString(), name: 'TransactionLog');
  }

  void clear() => _entries.clear();
}
