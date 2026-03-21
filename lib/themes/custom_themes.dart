import 'package:flutter/material.dart';

class CustomThemes {
  static ThemeData tracker(ThemeData base) {
    const primary = Color(0xFF18F2FF);
    const secondary = Color(0xFF67FFB8);
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.black,
      secondary: secondary,
      onSecondary: Colors.black,
      surface: const Color(0xFF040E1A),
      onSurface: Colors.white,
      surfaceContainerHighest: const Color(0xFF01070F),
      onSurfaceVariant: Colors.white70,
      error: Colors.redAccent,
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerHighest,
      canvasColor: scheme.surface,
      shadowColor: Colors.black87,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF020A16),
        selectedItemColor: scheme.secondary,
        unselectedItemColor: Colors.white60,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 14,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }

  static ThemeData delivery(ThemeData base) {
    const primary = Color(0xFFFC5C65);
    const secondary = Color(0xFFFFC107);
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.black,
      surface: const Color(0xFFFDF5F0),
      onSurface: Colors.black87,
      surfaceContainerHighest: const Color(0xFFFEF7F1),
      onSurfaceVariant: Colors.black87,
      error: Colors.red.shade700,
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerHighest,
      canvasColor: scheme.surface,
      cardColor: Colors.white,
      shadowColor: Colors.black26,
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFFFFF4E5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge: const TextStyle(color: Colors.black87),
        bodyMedium: const TextStyle(color: Colors.black87),
      ),
    );
  }
}
