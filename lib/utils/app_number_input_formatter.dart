import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AppNumberInputFormatter extends TextInputFormatter {
  AppNumberInputFormatter({
    this.allowDecimal = true,
  }) : _wholeNumberFormat = NumberFormat('#,##0');

  final bool allowDecimal;
  final NumberFormat _wholeNumberFormat;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final sanitized = _sanitize(newValue.text);
    if (sanitized.isEmpty) {
      return const TextEditingValue();
    }

    if (!_isValid(sanitized)) {
      return oldValue;
    }

    final formatted = _format(sanitized);
    final selectionIndex = _selectionIndexForFormattedValue(
        formatted, newValue.selection.baseOffset);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }

  String _sanitize(String input) {
    final pattern = allowDecimal ? RegExp(r'[^0-9.]') : RegExp(r'[^0-9]');
    return input.replaceAll(',', '').replaceAll(pattern, '');
  }

  bool _isValid(String sanitized) {
    if (!allowDecimal) {
      return true;
    }
    final dotMatches = '.'.allMatches(sanitized).length;
    return dotMatches <= 1;
  }

  String _format(String sanitized) {
    final segments = sanitized.split('.');
    final rawWhole = segments.first;
    final normalizedWhole = rawWhole.isEmpty
        ? '0'
        : rawWhole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formattedWhole =
        _wholeNumberFormat.format(int.tryParse(normalizedWhole) ?? 0);

    if (!allowDecimal) {
      return formattedWhole;
    }

    if (segments.length == 1) {
      return formattedWhole;
    }

    final decimalPart = segments[1];
    if (sanitized.endsWith('.')) {
      return '$formattedWhole.';
    }
    return '$formattedWhole.$decimalPart';
  }

  int _selectionIndexForFormattedValue(String formatted, int rawSelection) {
    if (rawSelection <= 0) {
      return 0;
    }

    var digitsSeen = 0;
    for (var i = 0; i < formatted.length; i++) {
      final character = formatted[i];
      if (RegExp(r'[0-9.]').hasMatch(character)) {
        digitsSeen++;
      }
      if (digitsSeen >= rawSelection) {
        return i + 1;
      }
    }
    return formatted.length;
  }
}
