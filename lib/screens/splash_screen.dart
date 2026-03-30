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
import '../widgets/user_access_dialogs.dart';
import 'scr_msoft.dart';

const String _kOfficialLogoAsset = 'lib/assets/images/logo2.png';

final _splashBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    AppVisuals.dawnMist,
    AppVisuals.fieldMist,
    Color.alphaBlend(
      AppVisuals.mintAccent.withValues(alpha: 0.32),
      AppVisuals.cloudGlass,
    ),
    Color.alphaBlend(
      AppVisuals.skyMist.withValues(alpha: 0.28),
      AppVisuals.dawnMist,
    ),
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
  static const Duration _minimumLaunchDelay = Duration(milliseconds: 450);

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
      final reduce = Provider.of<AppSettingsProvider>(context, listen: false)
          .reducedMotion;
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
    var completedSetupThisLaunch = false;

    await Future.wait([
      appSettings.ready,
      DatabaseHelper.instance.database,
    ]);

    await launchDelay;
    if (!mounted) return;

    if (!appSettings.hasCompletedUserSetup) {
      final setupResult = await showFirstRunSetupDialog(context);
      if (!mounted || setupResult == null) return;

      await appSettings.completeUserSetup(
        userName: setupResult.userName,
        appLockEnabled: setupResult.appLockEnabled,
        password: setupResult.password,
      );
      completedSetupThisLaunch = true;
    }

    if (!mounted) return;

    if (!completedSetupThisLaunch && appSettings.requiresAppPassword) {
      final unlocked = await showPasswordVerificationDialog(
        context,
        expectedPassword: appSettings.appPassword,
        title: 'Unlock RCAMARii',
        message: 'Enter your password to continue to the dashboard.',
        allowCancel: false,
      );
      if (!mounted || !unlocked) return;
    }

    const Widget nextScreen = ScrMSoft();

    final transitionDuration = appSettings.reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 900);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a1, a2) => nextScreen,
        transitionsBuilder: (c, anim, a2, child) => appSettings.reducedMotion
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
        isDark: false,
        backgroundGradient: _splashBackground,
        orbTopLeftColor: AppVisuals.brandRed.withValues(alpha: 0.12),
        orbTopRightColor: AppVisuals.mintAccent.withValues(alpha: 0.14),
        orbBottomLeftColor: AppVisuals.brandBlue.withValues(alpha: 0.1),
        orbBottomRightColor: AppVisuals.lightGold.withValues(alpha: 0.08),
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
                        AppVisuals.brandRed.withValues(alpha: 0.08),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _entranceController,
                            _ambientController,
                          ]),
                          builder: (context, child) {
                            final pulse =
                                reduceMotion ? 1.0 : _pulseAnimation.value;
                            final dy =
                                reduceMotion ? 0.0 : _slideAnimation.value;
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
                        const SizedBox(height: 28),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildBrandBlock(context, theme),
                        ),
                        const SizedBox(height: 28),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildLoadingStrip(reduceMotion),
                        ),
                        const Spacer(),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildFooter(context, theme),
                        ),
                        SizedBox(height: 12 + bottomPad),
                      ],
                    ),
                  ),
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
    final logoW = math.min(w * 0.72, 280.0);

    return Semantics(
      label: 'RCAMARii',
      child: Container(
        width: logoW,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: AppVisuals.mintAccent.withValues(alpha: 0.7),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: AppVisuals.brandRed.withValues(alpha: 0.12),
              blurRadius: 22,
              spreadRadius: -4,
            ),
            BoxShadow(
              color: AppVisuals.brandBlue.withValues(alpha: 0.08),
              blurRadius: 18,
              spreadRadius: -8,
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppVisuals.brandWhite,
              AppVisuals.fieldMist,
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            _kOfficialLogoAsset,
            fit: BoxFit.contain,
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
      color: AppVisuals.glass(AppVisuals.cloudGlass, alpha: 0.74),
      child: Icon(
        Icons.eco_rounded,
        size: 64,
        color: AppVisuals.brandRed.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildBrandBlock(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppVisuals.glass(AppVisuals.brandWhite, alpha: 0.74),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppVisuals.mintAccent.withValues(alpha: 0.8),
            ),
          ),
          child: Text(
            'COMMAND CENTER STARTUP',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppVisuals.brandGreen,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppVisuals.brandRed,
              AppVisuals.brandGreen,
              AppVisuals.brandBlue,
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
          context.tr(
            'Preparing records, weather context, knowledge tools, and finance controls for a smooth handoff into the hub.',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppVisuals.textForestMuted,
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
              icon: Icons.dns_rounded,
              label: context.tr('Records'),
            ),
            _SplashChip(
              icon: Icons.cloud_sync_rounded,
              label: context.tr('Weather'),
            ),
            _SplashChip(
              icon: Icons.auto_stories_rounded,
              label: context.tr('Knowledge'),
            ),
            _SplashChip(
              icon: Icons.account_balance_wallet_rounded,
              label: context.tr('Finance'),
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
            height: 5,
            child: LinearProgressIndicator(
              backgroundColor: AppVisuals.mintAccent.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppVisuals.brandRed.withValues(alpha: 0.92),
              ),
            ),
          ),
        ),
        if (!reduceMotion) ...[
          const SizedBox(height: 10),
          _ShimmerDots(
            color: AppVisuals.brandBlue.withValues(alpha: 0.55),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final userName = appSettings.userName.trim();
    final launchMessage = userName.isEmpty
        ? 'Launching your farm workspace'
        : 'Launching your farm workspace, $userName';

    return Column(
      children: [
        Text(
          launchMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppVisuals.textForestMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('FIELD INTELLIGENCE BY NOMAD TECHNOLOGIES'),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppVisuals.textMuted,
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
        color: AppVisuals.brandWhite.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppVisuals.panelEdge,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 15, color: AppVisuals.brandBlue.withValues(alpha: 0.95)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppVisuals.textForest,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

