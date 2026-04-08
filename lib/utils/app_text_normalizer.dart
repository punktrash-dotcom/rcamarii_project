class AppTextNormalizer {
  AppTextNormalizer._();

  static final RegExp _whitespacePattern = RegExp(r'\s+');
  static final RegExp _wordPattern =
      RegExp(r"[A-Za-z0-9]+(?:['/-][A-Za-z0-9]+)*");

  static String normalizeSpacing(String input) {
    return input.trim().replaceAll(_whitespacePattern, ' ');
  }

  static String titleCase(String input) {
    final normalized = normalizeSpacing(input);
    if (normalized.isEmpty) {
      return '';
    }

    return normalized.replaceAllMapped(_wordPattern, (match) {
      final word = match.group(0) ?? '';
      if (word.isEmpty) {
        return '';
      }

      final separators = RegExp(r"(['/-])");
      return word.split(separators).map((segment) {
        if (segment.isEmpty) {
          return '';
        }
        if (separators.hasMatch(segment)) {
          return segment;
        }
        return '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}';
      }).join();
    });
  }

  static String sentenceCase(String input) {
    final normalized = input
        .trim()
        .split('\n')
        .map(normalizeSpacing)
        .where((line) => line.isNotEmpty)
        .join('\n');
    if (normalized.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    var shouldCapitalize = true;

    for (final rune in normalized.runes) {
      final character = String.fromCharCode(rune);
      if (shouldCapitalize && RegExp(r'[A-Za-z]').hasMatch(character)) {
        buffer.write(character.toUpperCase());
        shouldCapitalize = false;
        continue;
      }

      buffer.write(character.toLowerCase());
      if (character == '.' ||
          character == '!' ||
          character == '?' ||
          character == '\n') {
        shouldCapitalize = true;
      }
    }

    return buffer.toString();
  }

  static String? nullableTitleCase(String? input) {
    if (input == null) {
      return null;
    }
    final normalized = titleCase(input);
    return normalized.isEmpty ? null : normalized;
  }

  static String? nullableSentenceCase(String? input) {
    if (input == null) {
      return null;
    }
    final normalized = sentenceCase(input);
    return normalized.isEmpty ? null : normalized;
  }
}
