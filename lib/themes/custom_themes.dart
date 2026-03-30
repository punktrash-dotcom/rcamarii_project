import 'package:flutter/material.dart';

import 'app_visuals.dart';

/// Feature-specific overlays that stay aligned with the shared brand palette.
class CustomThemes {
  static ThemeData tracker(ThemeData base) {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppVisuals.brandRed,
      onPrimary: AppVisuals.softWhite,
      secondary: AppVisuals.brandGreen,
      onSecondary: AppVisuals.softWhite,
      tertiary: AppVisuals.brandBlue,
      onTertiary: AppVisuals.deepAnthracite,
      surface: AppVisuals.deepAnthracite,
      onSurface: AppVisuals.softWhite,
      surfaceContainerHighest: AppVisuals.surfaceRaised,
      onSurfaceVariant: const Color(0xFFCBD5E1),
      error: AppVisuals.statsError,
      onError: AppVisuals.softWhite,
      outline: AppVisuals.brandBlue.withValues(alpha: 0.24),
      shadow: Colors.black,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppVisuals.deepAnthracite,
      canvasColor: AppVisuals.deepAnthracite,
      shadowColor: Colors.black87,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onPrimary),
        foregroundColor: scheme.onPrimary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppVisuals.surfaceInset,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }

  static ThemeData delivery(ThemeData base) {
    const cream = AppVisuals.dawnMist;
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppVisuals.brandRed,
      onPrimary: AppVisuals.softWhite,
      secondary: AppVisuals.brandGreen,
      onSecondary: AppVisuals.softWhite,
      tertiary: AppVisuals.brandBlue,
      onTertiary: AppVisuals.deepAnthracite,
      surface: AppVisuals.softWhite,
      onSurface: AppVisuals.textForest,
      surfaceContainerHighest: cream,
      onSurfaceVariant: AppVisuals.textForestMuted,
      error: AppVisuals.statsError,
      onError: Colors.white,
      outline: AppVisuals.panelEdge,
      shadow: const Color(0x26141D16),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerHighest,
      canvasColor: scheme.surface,
      cardColor: scheme.surface,
      shadowColor: Colors.black26,
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: AppVisuals.softWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.tertiary, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge: TextStyle(color: scheme.onSurface),
        bodyMedium: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
