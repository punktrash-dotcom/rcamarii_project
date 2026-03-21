import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../themes/app_visuals.dart';
import 'scr_tracker.dart';

const _logoSplashBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0E1712),
    Color(0xFF16261C),
    Color(0xFF223127),
  ],
);

class FtrackerSplashScreen extends StatefulWidget {
  const FtrackerSplashScreen({super.key});

  @override
  State<FtrackerSplashScreen> createState() => _FtrackerSplashScreenState();
}

class _FtrackerSplashScreenState extends State<FtrackerSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final appSettings =
            Provider.of<AppSettingsProvider>(context, listen: false);
        final transitionDuration = appSettings.reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 800);
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => const ScrTracker(),
            transitionsBuilder: (c, anim, a2, child) =>
                appSettings.reducedMotion
                    ? child
                    : FadeTransition(opacity: anim, child: child),
            transitionDuration: transitionDuration,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FrostedPanel(
                radius: 34,
                color: Colors.white.withValues(alpha: 0.11),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF274734), Color(0xFF7EAC5F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1408 / 768,
                          child: SvgPicture.asset(
                            'lib/assets/images/rcamarii_logo.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Financial Tracker',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cash flow, records, and recent transaction intelligence for your farm operations.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator.adaptive(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppVisuals.forestEmerald,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
