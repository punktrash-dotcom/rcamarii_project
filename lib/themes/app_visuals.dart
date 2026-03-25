import 'package:flutter/material.dart';

/// Shared visual system built around the warm Ramari palette:
/// gold, soft yellow, cream, and earth brown.
class AppVisuals {
  static const Color brandRed = Color(0xFFFFC107);
  static const Color brandGreen = Color(0xFFF9E076);
  static const Color brandBlue = Color(0xFF895129);
  static const Color brandWhite = Color(0xFFFFFDD0);

  static const Color dawnMist = Color(0xFFFFFDD0);
  static const Color fieldMist = Color(0xFFFFF6D9);
  static const Color skyMist = Color(0xFFF9E076);
  static const Color blushMist = Color(0xFFFFE8A3);
  static const Color cloudGlass = Color(0xFFFFFCED);

  static const Color primaryGold = brandRed;
  static const Color primaryGoldDim = Color(0xFFE0A800);
  static const Color lightGold = brandGreen;
  static const Color deepGreen = Color(0xFF4A2B15);
  static const Color surfaceGreen = Color(0xFF6A3F21);
  static const Color surfaceRaised = Color(0xFF7B4A27);
  static const Color surfaceInset = Color(0xFF351D0F);
  static const Color growthGreen = Color(0xFFFFE082);
  static const Color mintAccent = Color(0xFFF9E076);
  static const Color softWhite = brandWhite;
  static const Color textForest = Color(0xFF4A2B15);
  static const Color textForestMuted = Color(0xFF7B644F);
  static const Color textMuted = Color(0xFFA28A72);
  static const Color mutedGold = Color(0xCCF9E076);
  static const Color accentChartBlue = brandBlue;

  static const Color midnightCharcoal = deepGreen;
  static const Color forestEmerald = surfaceGreen;
  static const Color harvestGold = primaryGold;
  static const Color warmOffWhite = softWhite;
  static const Color deepAnthracite = Color(0xFF3A220F);

  static const Color panelSoft = fieldMist;
  static const Color panelSoftAlt = Color(0xFFFFF1C2);
  static const Color panelRose = blushMist;
  static const Color panelEdge = Color(0xFFE6D4A0);
  static const Color chartRevenue = brandBlue;
  static const Color chartExpense = primaryGold;
  static const Color chartNet = lightGold;
  static const List<Color> chartPalette = [
    chartNet,
    chartRevenue,
    brandRed,
    brandGreen,
    mintAccent,
    growthGreen,
  ];

  /// Hub / dashboard tile gradients.
  static const List<List<Color>> actionDeckGradients = [
    [cloudGlass, fieldMist, skyMist],
    [cloudGlass, Color(0xFFFFF1B8), mintAccent],
    [cloudGlass, Color(0xFFFFF8E2), blushMist],
    [cloudGlass, Color(0xFFF3E4C9), Color(0xFFE2C495)],
    [cloudGlass, Color(0xFFFFF2BF), Color(0xFFF0D26E)],
    [cloudGlass, fieldMist, Color(0xFFE7CFA0)],
  ];

  static ThemeData theme({
    required bool isDark,
    bool reduceMotion = false,
  }) {
    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: brandRed,
            onPrimary: deepGreen,
            secondary: brandGreen,
            onSecondary: deepGreen,
            tertiary: brandBlue,
            onTertiary: brandWhite,
            error: Color(0xFFD85C6F),
            onError: brandWhite,
            surface: deepGreen,
            onSurface: brandWhite,
            surfaceContainerHighest: surfaceRaised,
            onSurfaceVariant: Color(0xFFF1E3BF),
            outline: Color(0xFFD6B06D),
            shadow: Colors.black,
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: brandRed,
            onPrimary: deepGreen,
            secondary: mintAccent,
            onSecondary: textForest,
            tertiary: brandBlue,
            onTertiary: brandWhite,
            error: brandRed,
            onError: brandWhite,
            surface: dawnMist,
            onSurface: textForest,
            surfaceContainerHighest: cloudGlass,
            onSurfaceVariant: textForestMuted,
            outline: Color(0xFFE5D29A),
            shadow: Color(0x1A4A2B15),
          );

    final panelColor = isDark
        ? surfaceRaised.withValues(alpha: 0.92)
        : cloudGlass.withValues(alpha: 0.9);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? deepGreen : dawnMist,
      canvasColor: scheme.surface,
      fontFamily: 'NotoSans',
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: scheme.outline.withValues(alpha: 0.38),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          height: 1.02,
          letterSpacing: -1.1,
        ),
        displayMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          height: 1.06,
          letterSpacing: -0.8,
        ),
        displaySmall: TextStyle(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.12,
          letterSpacing: -0.4,
        ),
        headlineMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
        titleLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
        titleMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 15,
          height: 1.58,
        ),
        bodyMedium: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13.5,
          height: 1.58,
        ),
        bodySmall: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.84),
          fontSize: 12,
          height: 1.48,
          letterSpacing: 0.25,
        ),
        labelLarge: TextStyle(
          color: scheme.primary,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.15,
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
          fontWeight: FontWeight.w900,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? surfaceInset.withValues(alpha: 0.88)
            : brandWhite.withValues(alpha: 0.86),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        hintStyle:
            TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.52)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
      ),
      cardTheme: CardThemeData(
        color: panelColor,
        elevation: 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceRaised : panelSoft,
        contentTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? surfaceRaised : cloudGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.32)),
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surfaceRaised : cloudGlass,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outline.withValues(alpha: 0.45),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.32),
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.15),
        circularTrackColor: scheme.primary.withValues(alpha: 0.15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? surfaceGreen.withValues(alpha: 0.96)
            : cloudGlass.withValues(alpha: 0.96),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        shadowColor: scheme.shadow.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: FontWeight.w900,
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: scheme.primary.withValues(alpha: 0.28),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(100, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.45,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: isDark
              ? surfaceGreen.withValues(alpha: 0.74)
              : brandWhite.withValues(alpha: 0.6),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.75)),
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
        backgroundColor: isDark
            ? surfaceGreen.withValues(alpha: 0.88)
            : brandWhite.withValues(alpha: 0.82),
        selectedColor: scheme.primary,
        disabledColor: scheme.outline.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [brandRed, brandGreen],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: brandGreen.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.45,
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
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          deepGreen,
          surfaceGreen,
          Color.alphaBlend(brandBlue.withValues(alpha: 0.12), surfaceInset),
          Color.alphaBlend(brandRed.withValues(alpha: 0.16), deepGreen),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dawnMist,
        fieldMist,
        skyMist,
        blushMist,
      ],
    );
  }

  static BoxDecoration frostedPanel(
    ColorScheme scheme, {
    double radius = 32,
    bool lifted = true,
    Color? colorOverride,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = colorOverride ??
        (isDark
            ? surfaceRaised.withValues(alpha: 0.84)
            : cloudGlass.withValues(alpha: 0.84));
    final top = Color.alphaBlend(
      brandWhite.withValues(alpha: isDark ? 0.08 : 0.62),
      base,
    );
    final mid = Color.alphaBlend(
      brandBlue.withValues(alpha: isDark ? 0.08 : 0.18),
      base,
    );
    final bottom = Color.alphaBlend(
      brandGreen.withValues(alpha: isDark ? 0.16 : 0.08),
      base,
    );

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          top.withValues(alpha: 0.98),
          mid.withValues(alpha: 0.94),
          bottom.withValues(alpha: 0.96),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? brandBlue.withValues(alpha: 0.14)
            : scheme.outline.withValues(alpha: 0.52),
        width: 1.1,
      ),
      boxShadow: lifted ? neoShadows(scheme) : const [],
    );
  }

  /// Lifted card stack with deep shadow, colored atmosphere, and a top rim.
  static List<BoxShadow> neoShadows(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
        blurRadius: isDark ? 34 : 26,
        offset: const Offset(0, 16),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: brandBlue.withValues(alpha: isDark ? 0.1 : 0.12),
        blurRadius: 28,
        offset: const Offset(0, 8),
        spreadRadius: -6,
      ),
      BoxShadow(
        color: brandGreen.withValues(alpha: isDark ? 0.12 : 0.08),
        blurRadius: 20,
        offset: const Offset(0, 6),
        spreadRadius: -8,
      ),
      BoxShadow(
        color: brandWhite.withValues(alpha: isDark ? 0.04 : 0.45),
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
        AppVisuals.brandRed.withValues(alpha: isDark ? 0.08 : 0.06);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppVisuals.deepGreen : AppVisuals.dawnMist,
        gradient: backgroundGradient ?? AppVisuals.shellBackground(isDark),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -150,
            left: -100,
            child: _Orb(
              size: 420,
              color: accentA.withValues(alpha: isDark ? 0.16 : 0.12),
            ),
          ),
          Positioned(
            top: 170,
            right: -120,
            child: _Orb(
              size: 330,
              color: accentB.withValues(alpha: isDark ? 0.12 : 0.09),
            ),
          ),
          Positioned(
            bottom: -160,
            left: 40,
            child: _Orb(
              size: 460,
              color: accentC,
            ),
          ),
          Positioned(
            bottom: 80,
            right: -80,
            child: _Orb(
              size: 270,
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
