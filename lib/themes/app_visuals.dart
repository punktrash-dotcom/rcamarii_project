import 'package:flutter/material.dart';

class AppVisuals {
  static const Color midnightCharcoal = Color(0xFF121212);
  static const Color deepAnthracite = Color(0xFF2D3436);
  static const Color forestEmerald = Color(0xFF1A4D2E);
  static const Color deepSpaceBlue = Color(0xFF0F3057);
  static const Color warmOffWhite = Color(0xFFF8F6F3);
  static const Color harvestGold = Color(0xFFEAC435);
  static const Color electricLime = Color(0xFFDFFF00);
  static const Color cream = Color(0xFFF5F0E7);
  static const Color clay = Color(0xFFC9B8A0);
  static const Color ink = Color(0xFF172017);
  static const Color mist = Color(0xFFE3EADF);

  static ThemeData theme({
    required bool isDark,
    bool reduceMotion = false,
  }) {
    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: forestEmerald,
            onPrimary: warmOffWhite,
            secondary: deepSpaceBlue,
            onSecondary: warmOffWhite,
            tertiary: harvestGold,
            onTertiary: midnightCharcoal,
            error: harvestGold,
            onError: midnightCharcoal,
            surface: midnightCharcoal,
            onSurface: warmOffWhite,
            surfaceContainerHighest: deepAnthracite,
            onSurfaceVariant: Color(0xFFD2D0CC),
            outline: Color(0xFF495355),
            shadow: Color(0xFF050505),
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: forestEmerald,
            onPrimary: Colors.white,
            secondary: deepSpaceBlue,
            onSecondary: Colors.white,
            tertiary: harvestGold,
            onTertiary: ink,
            error: Color(0xFFB24A3F),
            onError: Colors.white,
            surface: cream,
            onSurface: ink,
            surfaceContainerHighest: Color(0xFFF0E9DD),
            onSurfaceVariant: Color(0xFF576152),
            outline: Color(0xFFD5CBBB),
            shadow: Color(0x26141D16),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? midnightCharcoal : cream,
      canvasColor: scheme.surface,
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: scheme.outline.withValues(alpha: 0.42),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: -0.8,
        ),
        displayMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        titleLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12.5,
          height: 1.55,
        ),
        bodySmall: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          height: 1.45,
          letterSpacing: 0.2,
        ),
        labelLarge: TextStyle(
          color: scheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        hintStyle:
            TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.74)),
        helperStyle:
            TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.9)),
        prefixStyle: TextStyle(color: scheme.onSurface),
        suffixStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.68)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: scheme.onSurface),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: scheme.onSurface),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.74),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: scheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                BorderSide(color: scheme.outline.withValues(alpha: 0.68)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: scheme.primary, width: 1.6),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(96, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.9)),
          minimumSize: const Size(90, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? deepAnthracite : ink,
        contentTextStyle:
            TextStyle(color: isDark ? warmOffWhite : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: reduceMotion
              ? const _NoAnimationPageTransitionsBuilder()
              : const ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: reduceMotion
              ? const _NoAnimationPageTransitionsBuilder()
              : const CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: reduceMotion
              ? const _NoAnimationPageTransitionsBuilder()
              : const FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: reduceMotion
              ? const _NoAnimationPageTransitionsBuilder()
              : const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: reduceMotion
              ? const _NoAnimationPageTransitionsBuilder()
              : const FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: reduceMotion
              ? const _NoAnimationPageTransitionsBuilder()
              : const ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static LinearGradient shellBackground(bool isDark) {
    if (isDark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0D1110),
          midnightCharcoal,
          Color(0xFF161C1E),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF6F1E8),
        Color(0xFFF0E7DA),
        Color(0xFFEAE5D8),
      ],
    );
  }

  static BoxDecoration frostedPanel(
    ColorScheme scheme, {
    double radius = 28,
    bool lifted = true,
    Color? colorOverride,
  }) {
    return BoxDecoration(
      color: colorOverride ?? scheme.surface.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
      boxShadow: lifted
          ? [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ]
          : const [],
    );
  }

  static List<BoxShadow> softGlow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.24),
        blurRadius: 28,
        spreadRadius: -8,
        offset: const Offset(0, 16),
      ),
    ];
  }
}

class AppBackdrop extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final Gradient? backgroundGradient;
  final Color? orbTopLeftColor;
  final Color? orbTopRightColor;
  final Color? orbBottomLeftColor;
  final Color? orbBottomRightColor;

  const AppBackdrop({
    super.key,
    required this.child,
    required this.isDark,
    this.backgroundGradient,
    this.orbTopLeftColor,
    this.orbTopRightColor,
    this.orbBottomLeftColor,
    this.orbBottomRightColor,
  });

  @override
  Widget build(BuildContext context) {
    final accentA = orbTopLeftColor ??
        (isDark ? AppVisuals.forestEmerald : AppVisuals.harvestGold);
    final accentB = orbTopRightColor ??
        (isDark ? AppVisuals.deepSpaceBlue : AppVisuals.deepAnthracite);
    final accentC = orbBottomLeftColor ??
        AppVisuals.harvestGold.withValues(alpha: isDark ? 0.12 : 0.08);
    final accentD = orbBottomRightColor ??
        AppVisuals.clay.withValues(alpha: isDark ? 0.08 : 0.1);

    return Container(
      decoration: BoxDecoration(
        gradient: backgroundGradient ?? AppVisuals.shellBackground(isDark),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            left: -70,
            child: _Orb(
              size: 260,
              color: accentA.withValues(alpha: isDark ? 0.18 : 0.14),
            ),
          ),
          Positioned(
            top: 120,
            right: -90,
            child: _Orb(
              size: 220,
              color: accentB.withValues(alpha: isDark ? 0.16 : 0.12),
            ),
          ),
          Positioned(
            bottom: -120,
            left: 20,
            child: _Orb(
              size: 280,
              color: accentC,
            ),
          ),
          Positioned(
            bottom: 90,
            right: -50,
            child: _Orb(
              size: 160,
              color: accentD,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class FrostedPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool lifted;
  final Color? color;

  const FrostedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.lifted = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: AppVisuals.frostedPanel(
        scheme,
        radius: radius,
        lifted: lifted,
        colorOverride: color,
      ),
      child: child,
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
