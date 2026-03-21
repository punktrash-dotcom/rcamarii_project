class ValidationUtils {
  /// Converts a string to Title Case. e.g., "john doe" -> "John Doe"
  static String toTitleCase(String text) {
    if (text.isEmpty) return '';
    return text
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  /// A generic validator for TextFormFields based on the CHECKDATA rules.
  static String? checkData(
      {required String? value,
      required String fieldName,
      bool canBeBlank = false,
      bool isNumeric = false,
      bool allowZero = false}) {
    if (value == null || value.trim().isEmpty) {
      if (canBeBlank) return null; // Allowed to be blank
      return '$fieldName cannot be empty.';
    }

    if (isNumeric) {
      final number = double.tryParse(value);
      if (number == null) {
        return '$fieldName must be a valid number.';
      }
      if (!allowZero && number == 0) {
        return '$fieldName cannot be zero.';
      }
    }

    // If all checks pass, return null (no error)
    return null;
  }
}
