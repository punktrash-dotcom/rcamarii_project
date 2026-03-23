import 'package:flutter/material.dart';

/// Ramari Farm & Finance — deep red + forest green + light blue + white.
class AppVisuals {
  static const Color brandRed = Color(0xFF8E0A1E);
  static const Color brandGreen = Color(0xFF2E6F40);
  static const Color brandBlue = Color(0xFFADD8E6);
  static const Color brandWhite = Color(0xFFFFFFFF);

  static const Color primaryGold = brandGreen;
  static const Color primaryGoldDim = Color(0xFF245A33);
  static const Color lightGold = brandBlue;
  static const Color deepGreen = Color(0xFF0A120E);
  static const Color surfaceGreen = Color(0xFF132018);
  static const Color surfaceRaised = Color(0xFF1E2E24);
  static const Color surfaceInset = Color(0xFF0D1612);
  static const Color growthGreen = brandBlue;
  static const Color mintAccent = brandRed;
  static const Color softWhite = brandWhite;
  /// Primary body / title text (forest green on light & mist surfaces).
  static const Color textForest = Color(0xFF0F1E16);
  static const Color textForestMuted = Color(0xFF3D5248);
  static const Color textMuted = Color(0xFF5A6B62);
  static const Color mutedGold = Color(0xCC8E0A1E);
  static const Color accentChartBlue = brandBlue;

  static const Color midnightCharcoal = deepGreen;
  static const Color forestEmerald = surfaceGreen;
  static const Color harvestGold = primaryGold;
  static const Color warmOffWhite = softWhite;
  static const Color deepAnthracite = Color(0xFF1A2820);

  /// Hub / dashboard tile gradients.
  static const List<List<Color>> actionDeckGradients = [
    [Color(0xFFF2FBFF), Color(0xFFDDEFF7)],
    [Color(0xFFF3FAF6), Color(0xFFDBEEE2)],
    [Color(0xFFF7F4F4), Color(0xFFF2E2E5)],
    [Color(0xFFF2FBFF), Color(0xFFE4F3F9)],
    [Color(0xFFF3FAF6), Color(0xFFE0F1E7)],
    [Color(0xFFF7F4F4), Color(0xFFF1E5E7)],
  ];

  static ThemeData theme({
    required bool isDark,
    bool reduceMotion = false,
  }) {
    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: brandGreen,
            onPrimary: brandWhite,
            secondary: brandRed,
            onSecondary: brandWhite,
            tertiary: brandBlue,
            onTertiary: textForest,
            error: Color(0xFFC62828),
            onError: brandWhite,
            surface: deepGreen,
            onSurface: brandWhite,
            surfaceContainerHighest: surfaceRaised,
            onSurfaceVariant: Color(0xFFCFE0D7),
            outline: Color(0xFF3E6B4B),
            shadow: Colors.black,
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: brandGreen,
            onPrimary: brandWhite,
            secondary: brandRed,
            onSecondary: brandWhite,
            tertiary: brandBlue,
            onTertiary: textForest,
            error: Color(0xFFC62828),
            onError: brandWhite,
            surface: brandWhite,
            onSurface: textForest,
            surfaceContainerHighest: Color(0xFFF0F8FB),
            onSurfaceVariant: textForestMuted,
            outline: Color(0xFFB7C8BF),
            shadow: Color(0x26141D16),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? deepGreen : scheme.surface,
      canvasColor: scheme.surface,
      fontFamily: 'NotoSans',
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: scheme.outline.withValues(alpha: 0.42),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        titleLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13.5,
          height: 1.6,
        ),
        bodySmall: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          fontSize: 12,
          height: 1.5,
          letterSpacing: 0.3,
        ),
        labelLarge: TextStyle(
          color: scheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        hintStyle:
            TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 2.0),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.45),
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.15),
        circularTrackColor: scheme.primary.withValues(alpha: 0.15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.95),
        indicatorColor: scheme.primary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.4,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 8,
          shadowColor: scheme.primary.withValues(alpha: 0.3),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(100, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.primary, width: 1.5),
          minimumSize: const Size(100, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: reduceMotion
              ? const _NoAnimationPageTransitionsBuilder()
              : const ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: reduceMotion
              ? const _NoAnimationPageTransitionsBuilder()
              : const CupertinoPageTransitionsBuilder(),
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
          deepGreen,
          Color(0xFF0B1A20),
          Color(0xFF1A0B12),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        brandWhite,
        Color(0xFFE9F6FB),
        Color(0xFFDCEFF7),
      ],
    );
  }

  static BoxDecoration frostedPanel(
    ColorScheme scheme, {
    double radius = 32,
    bool lifted = true,
    Color? colorOverride,
  }) {
    final base = colorOverride ?? scheme.surface.withValues(alpha: 0.92);
    return BoxDecoration(
      color: base,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: scheme.brightness == Brightness.dark
            ? brandBlue.withValues(alpha: 0.14)
            : scheme.outline.withValues(alpha: 0.55),
        width: 1.2,
      ),
      boxShadow: lifted ? neoShadows(scheme) : const [],
    );
  }

  /// “Lifted” card stack: deep drop shadow + gold rim glow + top highlight.
  static List<BoxShadow> neoShadows(ColorScheme scheme) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.55),
        blurRadius: 32,
        offset: const Offset(0, 16),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: brandBlue.withValues(alpha: 0.07),
        blurRadius: 28,
        offset: const Offset(0, 8),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: brandRed.withValues(alpha: 0.06),
        blurRadius: 26,
        offset: const Offset(0, 8),
        spreadRadius: -6,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.06),
        blurRadius: 0,
        offset: const Offset(-1, -1),
        spreadRadius: -1,
      ),
    ];
  }

  static List<BoxShadow> shadow3d(ColorScheme scheme) => neoShadows(scheme);
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
        (isDark ? AppVisuals.brandBlue : AppVisuals.brandGreen);
    final accentB = orbTopRightColor ??
        (isDark ? AppVisuals.brandRed : AppVisuals.brandBlue);
    final accentC = orbBottomLeftColor ??
        AppVisuals.brandGreen.withValues(alpha: isDark ? 0.1 : 0.08);
    final accentD = orbBottomRightColor ??
        AppVisuals.brandBlue.withValues(alpha: isDark ? 0.08 : 0.1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppVisuals.deepGreen : AppVisuals.brandWhite,
        gradient: backgroundGradient ?? AppVisuals.shellBackground(isDark),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -150,
            left: -100,
            child: _Orb(
              size: 400,
              color: accentA.withValues(alpha: isDark ? 0.12 : 0.1),
            ),
          ),
          Positioned(
            top: 200,
            right: -120,
            child: _Orb(
              size: 350,
              color: accentB.withValues(alpha: isDark ? 0.1 : 0.08),
            ),
          ),
          Positioned(
            bottom: -150,
            left: 50,
            child: _Orb(
              size: 450,
              color: accentC,
            ),
          ),
          Positioned(
            bottom: 100,
            right: -80,
            child: _Orb(
              size: 250,
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
