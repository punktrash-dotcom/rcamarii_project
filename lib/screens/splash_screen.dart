import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../services/app_localization_service.dart';
import '../services/data_seeder.dart';
import '../services/database_helper.dart';
import '../services/weekly_price_refresh_service.dart';
import '../themes/app_visuals.dart';
import 'scr_msoft.dart';

const String _kSplashLogoPng = 'lib/assets/images/rcamarii_logo_splash.png';

final _splashBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    AppVisuals.deepGreen,
    const Color(0xFF0C1812),
    AppVisuals.surfaceRaised,
    const Color(0xFF152A1F),
  ],
  stops: const [0.0, 0.35, 0.72, 1.0],
);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minimumLaunchDelay = Duration(milliseconds: 1400);

  late AnimationController _entranceController;
  late AnimationController _ambientController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.08, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );

    _entranceController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce =
          Provider.of<AppSettingsProvider>(context, listen: false).reducedMotion;
      if (!reduce) {
        _ambientController.repeat(reverse: true);
      }
    });

    _initApp();
  }

  Future<void> _initApp() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final launchDelay = Future.delayed(_minimumLaunchDelay);

    await Future.wait([
      appSettings.ready,
      DatabaseHelper.instance.database,
    ]);

    await launchDelay;
    if (!mounted) return;

    const Widget nextScreen = ScrMSoft();

    final transitionDuration = appSettings.reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 900);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a1, a2) => nextScreen,
        transitionsBuilder: (c, anim, a2, child) =>
            appSettings.reducedMotion
                ? child
                : FadeTransition(opacity: anim, child: child),
        transitionDuration: transitionDuration,
      ),
    );

    unawaited(_warmUpData(dataProvider));
  }

  Future<void> _warmUpData(DataProvider dataProvider) async {
    try {
      await DataSeeder.ensureSeeded();
      dataProvider.setWorkDefs(DataSeeder.workDefsCsvData);
      dataProvider.setEquipment(DataSeeder.equipmentCsvData);
      await dataProvider.loadDefSupsFromDb();
      await WeeklyPriceRefreshService.instance.refreshIfDue(dataProvider);
    } catch (_) {}
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion =
        Provider.of<AppSettingsProvider>(context).reducedMotion;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: AppBackdrop(
        isDark: true,
        backgroundGradient: _splashBackground,
        orbTopLeftColor: AppVisuals.primaryGold.withValues(alpha: 0.12),
        orbTopRightColor: AppVisuals.mintAccent.withValues(alpha: 0.08),
        orbBottomLeftColor: AppVisuals.surfaceGreen.withValues(alpha: 0.15),
        orbBottomRightColor: AppVisuals.primaryGoldDim.withValues(alpha: 0.06),
        child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: -80,
                right: -60,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppVisuals.primaryGold.withValues(alpha: 0.07),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _entranceController,
                          _ambientController,
                        ]),
                        builder: (context, child) {
                          final pulse = reduceMotion ? 1.0 : _pulseAnimation.value;
                          final dy = reduceMotion ? 0.0 : _slideAnimation.value;
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Transform.translate(
                              offset: Offset(0, dy),
                              child: Transform.scale(
                                scale: pulse,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _buildLogoHero(context, theme),
                      ),
                      const Spacer(flex: 1),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildBrandBlock(context, theme),
                      ),
                      const Spacer(flex: 2),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildLoadingStrip(reduceMotion),
                      ),
                      SizedBox(height: 20 + bottomPad),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildFooter(context, theme),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildLogoHero(BuildContext context, ThemeData theme) {
    final w = MediaQuery.sizeOf(context).width;
    final logoW = math.min(w * 0.82, 340.0);

    return Semantics(
      label: 'RCAMARii',
      child: Container(
        width: logoW,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: AppVisuals.primaryGold.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 40,
              offset: const Offset(0, 22),
            ),
            BoxShadow(
              color: AppVisuals.primaryGold.withValues(alpha: 0.12),
              blurRadius: 32,
              spreadRadius: -4,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppVisuals.surfaceGreen.withValues(alpha: 0.55),
              AppVisuals.deepGreen.withValues(alpha: 0.92),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset(
            _kSplashLogoPng,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => _logoFallback(theme),
          ),
        ),
      ),
    );
  }

  Widget _logoFallback(ThemeData theme) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      color: AppVisuals.surfaceInset,
      child: Icon(
        Icons.eco_rounded,
        size: 64,
        color: AppVisuals.primaryGold.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildBrandBlock(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppVisuals.lightGold,
              AppVisuals.primaryGold,
              AppVisuals.primaryGoldDim,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'RCAMARii',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppVisuals.textForest,
              height: 1.05,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Field intelligence for farms, crews, logistics, supplies, and profit.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppVisuals.textMuted,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _SplashChip(
              icon: Icons.eco_rounded,
              label: context.tr('Farm'),
            ),
            _SplashChip(
              icon: Icons.local_shipping_rounded,
              label: context.tr('Logistics'),
            ),
            _SplashChip(
              icon: Icons.calculate_rounded,
              label: context.tr('Profit'),
            ),
            _SplashChip(
              icon: Icons.auto_awesome_rounded,
              label: context.tr('Copilot'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingStrip(bool reduceMotion) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              backgroundColor: AppVisuals.textForest.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppVisuals.primaryGold.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
        if (!reduceMotion) ...[
          const SizedBox(height: 10),
          _ShimmerDots(
            color: AppVisuals.primaryGold.withValues(alpha: 0.5),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        Text(
          context.tr('RCAMARii is tuning your farm command center'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppVisuals.textForest.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('FIELD INTELLIGENCE BY NOMAD TECHNOLOGIES'),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppVisuals.textForest.withValues(alpha: 0.28),
            letterSpacing: 2.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Simple animated dots for loading (only when motion is allowed).
class _ShimmerDots extends StatefulWidget {
  final Color color;

  const _ShimmerDots({required this.color});

  @override
  State<_ShimmerDots> createState() => _ShimmerDotsState();
}

class _ShimmerDotsState extends State<_ShimmerDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final t = (_c.value * 2 * math.pi) + i * 0.9;
            final o = 0.25 + 0.55 * (0.5 + 0.5 * math.sin(t));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: o.clamp(0.15, 0.85)),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: o * 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _SplashChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SplashChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppVisuals.textForest.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppVisuals.primaryGold.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppVisuals.primaryGold.withValues(alpha: 0.95)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppVisuals.textForest.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
