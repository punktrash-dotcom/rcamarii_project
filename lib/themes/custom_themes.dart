import 'package:flutter/material.dart';

import 'app_visuals.dart';

/// Feature-specific overlays that stay on-brand with Ramari (forest + gold + mint).
class CustomThemes {
  static ThemeData tracker(ThemeData base) {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppVisuals.primaryGold,
      onPrimary: AppVisuals.deepGreen,
      secondary: AppVisuals.accentChartBlue,
      onSecondary: AppVisuals.softWhite,
      tertiary: AppVisuals.mintAccent,
      onTertiary: AppVisuals.deepGreen,
      surface: AppVisuals.surfaceGreen,
      onSurface: AppVisuals.softWhite,
      surfaceContainerHighest: AppVisuals.surfaceRaised,
      onSurfaceVariant: const Color(0xFFF1E3BF),
      error: const Color(0xFFFF8A80),
      onError: AppVisuals.softWhite,
      outline: AppVisuals.lightGold.withValues(alpha: 0.3),
      shadow: Colors.black,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppVisuals.deepGreen,
      canvasColor: AppVisuals.surfaceGreen,
      shadowColor: Colors.black87,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
        foregroundColor: scheme.onSurface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppVisuals.surfaceInset,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: scheme.surfaceContainerHighest,
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
      primary: AppVisuals.primaryGoldDim,
      onPrimary: AppVisuals.deepGreen,
      secondary: AppVisuals.accentChartBlue,
      onSecondary: AppVisuals.softWhite,
      tertiary: AppVisuals.mintAccent,
      onTertiary: AppVisuals.deepGreen,
      surface: cream,
      onSurface: AppVisuals.deepGreen,
      surfaceContainerHighest: AppVisuals.fieldMist,
      onSurfaceVariant: AppVisuals.textForestMuted,
      error: const Color(0xFFC62828),
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
        fillColor: AppVisuals.cloudGlass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 6,
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
