import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../services/app_localization_service.dart';
import '../services/data_seeder.dart';
import '../services/database_helper.dart';
import '../services/weekly_price_refresh_service.dart';
import '../themes/app_visuals.dart';
import 'frm_main.dart';
import 'scr_msoft.dart';

const _logoSplashBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0E1712),
    Color(0xFF16261C),
    Color(0xFF223127),
  ],
);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minimumLaunchDelay = Duration(milliseconds: 1200);

  late AnimationController _controller;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.05).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    _initApp();
  }

  Future<void> _initApp() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final launchDelay = Future.delayed(_minimumLaunchDelay);

    await Future.wait([
      appSettings.ready,
      DatabaseHelper.instance.database.then((_) => DataSeeder.ensureSeeded()),
    ]);

    dataProvider.setWorkDefs(DataSeeder.workDefsCsvData);
    dataProvider.setEquipment(DataSeeder.equipmentCsvData);
    await dataProvider.loadDefSupsFromDb();
    await WeeklyPriceRefreshService.instance.refreshIfDue(dataProvider);

    await launchDelay;
    if (!mounted) return;

    if (mounted) {
      final nextScreen =
          appSettings.launchDestination == LaunchDestination.workspace
              ? const FrmMain()
              : const ScrMSoft();
      final transitionDuration = appSettings.reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 1000);
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
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        isDark: true,
        backgroundGradient: _logoSplashBackground,
        orbTopLeftColor: Color(0xFF274734),
        orbTopRightColor: Color(0xFF6A4B3A),
        orbBottomLeftColor: Color(0x335C8A6A),
        orbBottomRightColor: Color(0x336A4B3A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    final rotationY =
                        math.sin(_glowController.value * 2 * math.pi) * 0.04;
                    final rotationX =
                        math.cos(_glowController.value * 2 * math.pi) * 0.018;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateX(rotationX)
                        ..rotateY(rotationY),
                      child: Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildLaunchCard(context),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Column(
                children: [
                  Text(
                    context.tr(
                      'RCAMARii is tuning your farm command center',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.66),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      'FIELD INTELLIGENCE BY NOMAD TECHNOLOGIES',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.34),
                          letterSpacing: 2.1,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchCard(BuildContext context) {
    final width = math.min(MediaQuery.of(context).size.width * 0.88, 380.0);
    return FrostedPanel(
      radius: 36,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      color: Colors.white.withValues(alpha: 0.1),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: math.min(width, 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E412C), Color(0xFF7AA95B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: AppVisuals.softGlow(AppVisuals.forestEmerald),
              ),
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: AspectRatio(
                  aspectRatio: 1408 / 768,
                  child: SvgPicture.asset(
                    'lib/assets/images/rcamarii_logo.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'RCAMARii',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Field intelligence for farms, crews, logistics, supplies, and profit.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
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
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildPulseBars(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPulseBars() {
    return List.generate(5, (index) {
      final phase = (_glowController.value * 2 * math.pi) + (index * 0.6);
      final height = 10 + (math.sin(phase) * 6);
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 10,
        height: height.abs() + 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppVisuals.forestEmerald.withValues(alpha: 0.9 - index * 0.1),
              AppVisuals.harvestGold.withValues(alpha: 0.42),
            ],
          ),
        ),
      );
    });
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
