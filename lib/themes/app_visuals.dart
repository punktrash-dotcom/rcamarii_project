import 'package:flutter/material.dart';

/// Shared visual system built around the app shell blueprint:
/// brand red, farm green, calm info blue, and clean white surfaces.
class AppVisuals {
  // Palette definition.
  static const Color brandRed = Color(0xFF8E0A1E);
  static const Color brandGreen = Color(0xFF2E6F40);
  static const Color brandBlue = Color(0xFFADD8E6);
  static const Color brandWhite = Color(0xFFFFFFFF);

  // Surface roles.
  static const Color dawnMist = Color(0xFFF4F7FB);
  static const Color fieldMist = Color(0xFFFFFFFF);
  static const Color skyMist = Color(0xFFEAF5FA);
  static const Color blushMist = Color(0xFFF8E8EC);
  static const Color cloudGlass = Color(0xFFFFFFFF);

  // Legacy aliases kept for existing UI usage.
  static const Color primaryGold = brandRed;
  static const Color primaryGoldDim = Color(0xFF6F0B1B);
  static const Color lightGold = Color(0xFFD9EBDD);
  static const Color deepGreen = Color(0xFF1F2937);
  static const Color surfaceGreen = Color(0xFF2A3A4D);
  static const Color surfaceRaised = Color(0xFF34485D);
  static const Color surfaceInset = Color(0xFF182330);
  static const Color growthGreen = Color(0xFFDCEBDF);
  static const Color mintAccent = brandGreen;
  static const Color softWhite = brandWhite;
  static const Color textForest = Color(0xFF17212B);
  static const Color textForestMuted = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color mutedGold = Color(0x408E0A1E);
  static const Color accentChartBlue = brandBlue;
  static const Color statsError = Color(0xFFB42339);
  static const Color metricStrongGreen = brandGreen;
  static const Color metricTeal = brandBlue;

  // Semantic + shell support.
  static const Color midnightCharcoal = deepGreen;
  static const Color forestEmerald = brandGreen;
  static const Color harvestGold = primaryGold;
  static const Color warmOffWhite = brandWhite;
  static const Color deepAnthracite = Color(0xFF0F172A);

  static const Color panelSoft = skyMist;
  static const Color panelSoftAlt = Color(0xFFF5FAFC);
  static const Color panelRose = blushMist;
  static const Color panelEdge = Color(0xFFD6DDE6);
  static const Color chartRevenue = brandBlue;
  static const Color chartExpense = brandRed;
  static const Color chartNet = brandGreen;
  static const List<Color> chartPalette = [
    chartNet,
    chartRevenue,
    brandRed,
    brandGreen,
    Color(0xFFC8E4EC),
    Color(0xFFE4EEF7),
  ];

  // Dashboard-specific tokens.
  static const List<List<Color>> actionDeckGradients = [
    [fieldMist, skyMist, Color(0xFFDCEBDF)],
    [fieldMist, blushMist, Color(0xFFF2D9DF)],
    [fieldMist, skyMist, Color(0xFFD7EEF5)],
    [fieldMist, Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    [fieldMist, Color(0xFFEAF5FA), Color(0xFFD9EBDD)],
    [fieldMist, Color(0xFFF8E8EC), Color(0xFFEAF5FA)],
  ];

  static Color glass(Color color, {double alpha = 0.68}) =>
      color.withValues(alpha: alpha);

  static List<Color> glassGradient(
    List<Color> colors, {
    double alpha = 0.68,
  }) =>
      colors.map((color) => glass(color, alpha: alpha)).toList();

  static ThemeData theme({
    required bool isDark,
    bool reduceMotion = false,
  }) {
    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: brandRed,
            onPrimary: brandWhite,
            secondary: brandGreen,
            onSecondary: brandWhite,
            tertiary: brandBlue,
            onTertiary: deepAnthracite,
            error: statsError,
            onError: brandWhite,
            surface: deepAnthracite,
            onSurface: brandWhite,
            surfaceContainerHighest: surfaceRaised,
            onSurfaceVariant: Color(0xFFCBD5E1),
            outline: Color(0xFF475569),
            shadow: Colors.black,
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: brandRed,
            onPrimary: brandWhite,
            secondary: brandGreen,
            onSecondary: brandWhite,
            tertiary: brandBlue,
            onTertiary: deepAnthracite,
            error: statsError,
            onError: brandWhite,
            surface: brandWhite,
            onSurface: textForest,
            surfaceContainerHighest: dawnMist,
            onSurfaceVariant: textForestMuted,
            outline: Color(0xFFD6DDE6),
            shadow: Color(0x140F172A),
          );

    final panelColor = isDark ? glass(surfaceRaised, alpha: 0.9) : brandWhite;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? deepAnthracite : dawnMist,
      canvasColor: scheme.surface,
      fontFamily: 'NotoSans',
      splashFactory: NoSplash.splashFactory,
      hoverColor: brandBlue.withValues(alpha: 0.16),
      splashColor: brandBlue.withValues(alpha: 0.12),
      highlightColor: brandBlue.withValues(alpha: 0.1),
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
        backgroundColor: scheme.primary,
        elevation: 0,
        foregroundColor: scheme.onPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceInset.withValues(alpha: 0.92) : brandWhite,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: const TextStyle(color: brandBlue),
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
          borderSide: const BorderSide(color: brandBlue, width: 1.8),
        ),
      ),
      cardTheme: CardThemeData(
        color: panelColor,
        elevation: 0,
        shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.34 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? glass(surfaceRaised, alpha: 0.96) : surfaceGreen,
        contentTextStyle: TextStyle(
          color: isDark ? scheme.onSurface : brandWhite,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDark ? glass(surfaceRaised, alpha: 0.96) : brandWhite,
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
        backgroundColor:
            isDark ? glass(surfaceRaised, alpha: 0.96) : brandWhite,
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
        color: scheme.secondary,
        linearTrackColor: scheme.secondary.withValues(alpha: 0.15),
        circularTrackColor: scheme.secondary.withValues(alpha: 0.15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? surfaceInset.withValues(alpha: 0.94)
            : brandWhite.withValues(alpha: 0.94),
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
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
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: scheme.primary.withValues(alpha: 0.2),
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
          backgroundColor:
              isDark ? surfaceGreen.withValues(alpha: 0.4) : brandWhite,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
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
        backgroundColor: isDark ? surfaceGreen.withValues(alpha: 0.6) : skyMist,
        selectedColor: scheme.tertiary,
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
          color: brandRed,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: brandRed.withValues(alpha: 0.18),
              blurRadius: 12,
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
          deepAnthracite,
          surfaceInset,
          Color.alphaBlend(brandBlue.withValues(alpha: 0.12), surfaceGreen),
          Color.alphaBlend(brandRed.withValues(alpha: 0.14), deepAnthracite),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dawnMist,
        Color(0xFFF9FBFD),
        skyMist,
        Color(0xFFF1F5F9),
      ],
    );
  }

  static double mainTabBackgroundImageOpacity(bool isDark) =>
      isDark ? 0.18 : 0.26;

  static LinearGradient mainTabImageOverlay(bool isDark) {
    if (isDark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          deepGreen.withValues(alpha: 0.48),
          Color.alphaBlend(
            brandBlue.withValues(alpha: 0.18),
            surfaceInset,
          ).withValues(alpha: 0.4),
          Color.alphaBlend(
            brandRed.withValues(alpha: 0.14),
            deepGreen,
          ).withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0.18),
        ],
        stops: const [0.0, 0.36, 0.74, 1.0],
      );
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        softWhite.withValues(alpha: 0.12),
        fieldMist.withValues(alpha: 0.16),
        Color.alphaBlend(
          brandBlue.withValues(alpha: 0.12),
          cloudGlass,
        ).withValues(alpha: 0.16),
        brandGreen.withValues(alpha: 0.12),
      ],
      stops: const [0.0, 0.34, 0.72, 1.0],
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
        (isDark ? glass(surfaceRaised, alpha: 0.84) : brandWhite);
    final top = Color.alphaBlend(
      brandWhite.withValues(alpha: isDark ? 0.06 : 0.78),
      base,
    );
    final mid = Color.alphaBlend(
      brandBlue.withValues(alpha: isDark ? 0.08 : 0.16),
      base,
    );
    final bottom = Color.alphaBlend(
      brandGreen.withValues(alpha: isDark ? 0.1 : 0.08),
      base,
    );

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          top.withValues(alpha: isDark ? 0.92 : 0.98),
          mid.withValues(alpha: isDark ? 0.88 : 0.98),
          bottom.withValues(alpha: isDark ? 0.9 : 0.98),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? brandBlue.withValues(alpha: 0.18)
            : scheme.outline.withValues(alpha: 0.6),
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
        color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.08),
        blurRadius: isDark ? 28 : 18,
        offset: const Offset(0, 12),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: brandBlue.withValues(alpha: isDark ? 0.08 : 0.1),
        blurRadius: 20,
        offset: const Offset(0, 6),
        spreadRadius: -6,
      ),
      BoxShadow(
        color: brandGreen.withValues(alpha: isDark ? 0.08 : 0.06),
        blurRadius: 14,
        offset: const Offset(0, 4),
        spreadRadius: -8,
      ),
      BoxShadow(
        color: brandWhite.withValues(alpha: isDark ? 0.03 : 0.55),
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
  final String? backgroundImageAsset;
  final BoxFit backgroundImageFit;
  final double backgroundImageOpacity;
  final Color? imageScrimColor;
  final Color? orbTopLeftColor;
  final Color? orbTopRightColor;
  final Color? orbBottomLeftColor;
  final Color? orbBottomRightColor;

  const AppBackdrop({
    super.key,
    required this.child,
    required this.isDark,
    this.backgroundGradient,
    this.backgroundImageAsset,
    this.backgroundImageFit = BoxFit.cover,
    this.backgroundImageOpacity = 0.32,
    this.imageScrimColor,
    this.orbTopLeftColor,
    this.orbTopRightColor,
    this.orbBottomLeftColor,
    this.orbBottomRightColor,
  });

  @override
  Widget build(BuildContext context) {
    final accentA = orbTopLeftColor ??
        (isDark ? AppVisuals.brandBlue : AppVisuals.brandBlue);
    final accentB = orbTopRightColor ??
        (isDark ? AppVisuals.brandRed : AppVisuals.brandBlue);
    final accentC = orbBottomLeftColor ??
        AppVisuals.brandGreen.withValues(alpha: isDark ? 0.1 : 0.08);
    final accentD = orbBottomRightColor ??
        AppVisuals.brandRed.withValues(alpha: isDark ? 0.08 : 0.06);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppVisuals.deepAnthracite : AppVisuals.dawnMist,
        gradient: backgroundGradient ?? AppVisuals.shellBackground(isDark),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundImageAsset != null)
            Opacity(
              opacity: backgroundImageOpacity,
              child: Image.asset(
                backgroundImageAsset!,
                fit: backgroundImageFit,
              ),
            ),
          if (backgroundImageAsset != null)
            Container(
              color: imageScrimColor ??
                  (isDark
                      ? Colors.black.withValues(alpha: 0.18)
                      : AppVisuals.softWhite.withValues(alpha: 0.08)),
            ),
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
