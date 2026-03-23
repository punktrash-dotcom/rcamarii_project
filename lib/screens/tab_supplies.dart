import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/equipment_tab.dart';
import '../components/supplies_tab.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../themes/app_visuals.dart';
import 'frm_add_sup_screen.dart';
import 'market_price_list_screen.dart';

class TabSupplies extends StatefulWidget {
  const TabSupplies({super.key});

  @override
  State<TabSupplies> createState() => _TabSuppliesState();
}

class _TabSuppliesState extends State<TabSupplies>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  final _suppliesTabController = SuppliesTabController();
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;

  AppAudioProvider? _appAudio;
  AppSettingsProvider? _appSettings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playScreenOpenAudioIfNeeded();
    });
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) appRouteObserver.unsubscribe(this);
    unawaited(_stopScreenOpenAudioIfNeeded());
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appAudio ??= Provider.of<AppAudioProvider>(context, listen: false);
    _appSettings ??= Provider.of<AppSettingsProvider>(context, listen: false);

    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
  }

  Future<void> _playScreenOpenAudioIfNeeded() async {
    if (!mounted || _playedScreenOpenAudio) return;
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) return;

    _playedScreenOpenAudio = true;
    await appAudio.playScreenOpenSound(
      screenKey: 'tab_supplies',
      style: appSettings.audioSoundStyle,
      enabled: appSettings.audioSoundsEnabled,
    );
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) return;

    await appAudio.stopScreenOpenSound(
      screenKey: 'tab_supplies',
      style: appSettings.audioSoundStyle,
    );
  }

  @override
  void didPushNext() => unawaited(_stopScreenOpenAudioIfNeeded());
  @override
  void didPop() => unawaited(_stopScreenOpenAudioIfNeeded());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsStrip(theme),
          const SizedBox(height: 20),
          _buildControlPanel(theme),
          const SizedBox(height: 20),
          Expanded(
            child: FrostedPanel(
              radius: 32,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTabBar(theme),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SuppliesTab(controller: _suppliesTabController),
                        const EquipmentTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStrip(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: context.tr('Market Watch'),
            value: context.tr('View Prices'),
            icon: Icons.price_check_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketPriceListScreen())),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: context.tr('Catalog'),
            value: context.tr('Database'),
            icon: Icons.storage_rounded,
            onTap: () {
              _tabController.animateTo(0);
              _suppliesTabController.showDatabase();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel(ThemeData theme) {
    return FrostedPanel(
      radius: 28,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _ActionButton(
              icon: Icons.add_business_rounded,
              label: context.tr('Procure'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FrmAddSupScreen()),
                );
              },
              isPrimary: true,
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.inventory_rounded,
              label: context.tr('Stock'),
              onTap: () {
                if (_tabController.index == 0) {
                  _suppliesTabController.showInventory();
                }
              },
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.storage_rounded,
              label: context.tr('Catalog'),
              onTap: () {
                _tabController.animateTo(0);
                _suppliesTabController.showDatabase();
              },
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.price_check_rounded,
              label: context.tr('Prices'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MarketPriceListScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppVisuals.textForest.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        indicator: BoxDecoration(
          color: AppVisuals.primaryGold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppVisuals.primaryGold.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: AppVisuals.deepGreen,
        unselectedLabelColor: AppVisuals.textForest.withValues(alpha: 0.4),
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        tabs: [
          Tab(text: context.tr('SUPPLIES').toUpperCase()),
          Tab(text: context.tr('EQUIPMENT').toUpperCase()),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppVisuals.surfaceGreen.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppVisuals.textForest.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppVisuals.primaryGold, size: 24),
            const SizedBox(height: 12),
            Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppVisuals.textForest.withValues(alpha: 0.3), letterSpacing: 1.2, fontWeight: FontWeight.w800, fontSize: 9)),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppVisuals.textForest, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.isPrimary = false});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = isPrimary
        ? scheme.primary
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final fg = isPrimary ? scheme.onPrimary : scheme.onSurface;

    return SizedBox(
      width: 120,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary
                  ? scheme.primary.withValues(alpha: 0.2)
                  : scheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
