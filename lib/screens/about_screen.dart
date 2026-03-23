import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../themes/app_visuals.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with RouteAware {
  AppAudioProvider? _appAudio;
  bool _playedAboutAudio = false;
  bool _isRouteObserverSubscribed = false;

  Future<void> _stopAboutAudio() async {
    final appAudio = _appAudio;
    if (appAudio == null) {
      return;
    }
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
    await appAudio.stopScreenOpenSound(
      screenKey: 'about',
      style: appSettings.audioSoundStyle,
    );
  }

  Future<void> _closeAboutScreen() async {
    await _stopAboutAudio();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appAudio ??= context.read<AppAudioProvider>();
    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
    if (_playedAboutAudio) {
      return;
    }

    final appSettings = Provider.of<AppSettingsProvider>(context);
    _playedAboutAudio = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _appAudio!.playScreenOpenSound(
          screenKey: 'about',
          style: appSettings.audioSoundStyle,
          enabled: appSettings.audioSoundsEnabled,
          loop: true,
        ),
      );
    });
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopAboutAudio());
    super.dispose();
  }

  @override
  void didPushNext() {
    unawaited(_stopAboutAudio());
  }

  @override
  void didPop() {
    unawaited(_stopAboutAudio());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      onPopInvokedWithResult: (_, __) {
        unawaited(_stopAboutAudio());
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackdrop(
          isDark: isDark,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                children: [
                  FrostedPanel(
                    radius: 30,
                    color: isDark
                        ? AppVisuals.surfaceGreen.withValues(alpha: 0.94)
                        : AppVisuals.surfaceGreen.withValues(alpha: 0.92),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _closeAboutScreen,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                scheme.secondary.withValues(alpha: 0.24),
                            foregroundColor: AppVisuals.warmOffWhite,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      scheme.secondary.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  context.tr('About RCAMARii').toUpperCase(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: AppVisuals.warmOffWhite
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context
                                    .tr('Built from a family farm in Bukidnon'),
                                style: theme.textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppVisuals.warmOffWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FrostedPanel(
                      radius: 34,
                      padding: const EdgeInsets.all(0),
                      color: scheme.surface
                          .withValues(alpha: isDark ? 0.88 : 0.92),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeroCard(context),
                              const SizedBox(height: 14),
                              _buildFactStrip(context),
                              const SizedBox(height: 14),
                              _buildStoryCard(
                                context,
                                icon: Icons.home_work_rounded,
                                title: context.tr('Where RCAMARii started'),
                                body: context.tr(
                                  'RCAMARii began as a practical tool for a family-owned farm in Sinayawan, Valencia City, Bukidnon. It was originally built to support the daily work of the family farm, from organizing field activities to keeping records clearer and easier to review.',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildStoryCard(
                                context,
                                icon: Icons.share_rounded,
                                title: context.tr('Why it was shared'),
                                body: context.tr(
                                  'As the system became more useful in real farm operations, NOMAD, the owner and programmer behind RCAMARii, decided not to keep it private. The goal expanded from helping one farm operate better to helping new sugarcane and rice farmers gain guidance, structure, and confidence in managing their own farms.',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildStoryCard(
                                context,
                                icon: Icons.agriculture_rounded,
                                title: context.tr('What the app is for'),
                                body: context.tr(
                                  'RCAMARii is designed to bring together estate records, job orders, supply references, weather context, and farm guidance in one place. It is meant to support real agricultural work with a focus on sugarcane and rice farming, especially for growers who are still building their routines and decision-making process.',
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildMissionPanel(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppVisuals.surfaceGreen.withValues(alpha: 0.96),
            AppVisuals.deepGreen.withValues(alpha: 0.9),
            AppVisuals.primaryGold.withValues(alpha: 0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppVisuals.surfaceGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppVisuals.textForest.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.landscape_rounded,
                  color: AppVisuals.textForest,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.tr(
                    'RCAMARii grew out of real field work, real family decisions, and real farming needs.',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(
              'From its roots in Bukidnon, the app now aims to offer practical guidance for farmers who need a clearer way to manage operations and learn as they grow.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppVisuals.textMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(context.tr('Family-owned')),
              _buildHeroChip(context.tr('Sugarcane focus')),
              _buildHeroChip(context.tr('Rice guidance')),
              _buildHeroChip(context.tr('Built by NOMAD')),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('Built for one family farm, shared to guide many more.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.92),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppVisuals.textForest.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: AppVisuals.primaryGold.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppVisuals.textForest,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildFactStrip(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final items = [
          _FactItem(
            icon: Icons.person_rounded,
            label: context.tr('Programmer'),
            value: 'NOMAD',
          ),
          _FactItem(
            icon: Icons.place_rounded,
            label: context.tr('Location'),
            value: 'Sinayawan, Valencia City, Bukidnon',
          ),
          _FactItem(
            icon: Icons.grass_rounded,
            label: context.tr('Focus'),
            value: context.tr('Sugarcane and Rice'),
          ),
        ];

        if (wide) {
          return Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: item == items.last ? 0 : 10,
                      ),
                      child: _buildFactCard(context, item),
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Column(
          children: items
              .map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: item == items.last ? 0 : 10),
                  child: _buildFactCard(context, item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildFactCard(BuildContext context, _FactItem item) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surface.withValues(alpha: 0.98),
            scheme.surfaceContainerHighest.withValues(alpha: 0.74),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: scheme.secondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.58,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionPanel(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppVisuals.surfaceGreen.withValues(alpha: 0.94),
            AppVisuals.deepGreen.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
            color: AppVisuals.primaryGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Mission'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              'RCAMARii exists to turn lived farming experience into practical support. It reflects the discipline of a working family farm in Bukidnon and shares that experience to help newer farmers start with better guidance, better records, and better day-to-day decisions.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppVisuals.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactItem {
  final IconData icon;
  final String label;
  final String value;

  const _FactItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}
