import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/farm_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../themes/app_visuals.dart';
import 'add_farm_screen.dart';
import 'frm_add_job2.dart';

class TabFarm extends StatefulWidget {
  const TabFarm({super.key});

  @override
  State<TabFarm> createState() => _TabFarmState();
}

class _TabFarmState extends State<TabFarm>
    with TickerProviderStateMixin, RouteAware {
  TabController? _tabController;
  int _currentTabCount = 0;
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;

  AppAudioProvider? _appAudio;
  AppSettingsProvider? _appSettings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
      _playScreenOpenAudioIfNeeded();
    });
  }

  Future<void> _initData() async {
    if (!mounted) return;
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    await farmProvider.refreshFarms();
    _syncTabController();
  }

  Future<void> _playScreenOpenAudioIfNeeded() async {
    if (!mounted || _playedScreenOpenAudio) return;
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) return;

    _playedScreenOpenAudio = true;
    await appAudio.playScreenOpenSound(
      screenKey: 'tab_farm',
      style: appSettings.audioSoundStyle,
      enabled: appSettings.audioSoundsEnabled,
    );
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) return;

    await appAudio.stopScreenOpenSound(
      screenKey: 'tab_farm',
      style: appSettings.audioSoundStyle,
    );
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

  void _syncTabController() {
    if (!mounted) return;
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    final types = farmProvider.uniqueFarmTypes;
    final newCount = types.isEmpty ? 1 : types.length;

    if (_tabController == null || _currentTabCount != newCount) {
      _tabController?.dispose();
      _tabController = TabController(length: newCount, vsync: this);
      _currentTabCount = newCount;
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) appRouteObserver.unsubscribe(this);
    unawaited(_stopScreenOpenAudioIfNeeded());
    _tabController?.dispose();
    super.dispose();
  }

  @override
  void didPushNext() => unawaited(_stopScreenOpenAudioIfNeeded());
  @override
  void didPop() => unawaited(_stopScreenOpenAudioIfNeeded());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farmProvider = Provider.of<FarmProvider>(context);
    final farmTypes = farmProvider.uniqueFarmTypes;
    final expectedCount = farmTypes.isEmpty ? 1 : farmTypes.length;

    if (_currentTabCount != expectedCount || _tabController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncTabController());
      return const Center(child: CircularProgressIndicator(color: AppVisuals.primaryGold));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFarmMetrics(theme, farmProvider),
          const SizedBox(height: 20),
          _buildControlPanel(theme, farmProvider),
          const SizedBox(height: 20),
          Expanded(
            child: FrostedPanel(
              radius: 32,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (farmTypes.isNotEmpty) ...[
                    _buildTabBar(theme, farmTypes),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: farmTypes.isEmpty
                        ? _buildEmptyState(theme)
                        : TabBarView(
                            controller: _tabController!,
                            children: farmTypes.map((type) {
                              final farms = farmProvider.groupedFarms[type] ?? [];
                              return _buildCardList(theme, farms, farmProvider);
                            }).toList(),
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

  Widget _buildFarmMetrics(ThemeData theme, FarmProvider provider) {
    final totalArea = provider.farms.fold<double>(0, (sum, farm) => sum + farm.area);
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: context.tr('Total Estates'),
            value: provider.farms.length.toString(),
            icon: Icons.home_work_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: context.tr('Total Area'),
            value: '${totalArea.toStringAsFixed(1)} ha',
            icon: Icons.map_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel(ThemeData theme, FarmProvider farmProvider) {
    return FrostedPanel(
      radius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _ActionButton(
              icon: Icons.add_rounded,
              label: context.tr('New Estate'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFarmScreen()),
              ),
              isPrimary: true,
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.add_task_rounded,
              label: context.tr('Add Job'),
              onTap: () {
                if (farmProvider.selectedFarm != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FrmAddJob2(initialFName: farmProvider.selectedFarm!.name),
                    ),
                  );
                }
              },
              enabled: farmProvider.selectedFarm != null,
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.edit_rounded,
              label: context.tr('Edit'),
              onTap: () {
                if (farmProvider.selectedFarm != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddFarmScreen(farmID: farmProvider.selectedFarm!.id),
                    ),
                  );
                }
              },
              enabled: farmProvider.selectedFarm != null,
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.delete_rounded,
              label: context.tr('Delete'),
              onTap: () async {
                final farm = farmProvider.selectedFarm;
                if (farm == null) return;
                final farmId = farm.id;
                if (farmId == null) return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(context.tr('Delete farm?')),
                      content: Text(
                        context.tr(
                          'This will permanently delete {farm}.',
                          {'farm': farm.name},
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(context.tr('Cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(context.tr('Delete')),
                        ),
                      ],
                    );
                  },
                );
                if (confirmed != true) return;
                await farmProvider.deleteFarm(farmId);
              },
              enabled: farmProvider.selectedFarm != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, List<String> types) {
    if (types.isEmpty) return const SizedBox.shrink();
    final scheme = theme.colorScheme;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        indicator: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: scheme.onPrimary,
        unselectedLabelColor: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        tabs: types.map((type) => Tab(text: type.toUpperCase())).toList(),
      ),
    );
  }

  Widget _buildCardList(ThemeData theme, List<Farm> farms, FarmProvider farmProvider) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: farms.length,
      itemBuilder: (context, index) {
        final farm = farms[index];
        final isSelected = farmProvider.selectedFarm?.id == farm.id;
        final cropAge = DateTime.now().difference(farm.date).inDays.clamp(0, 9999);

        return GestureDetector(
          onTap: () => farmProvider.handleFarmSelection(farm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? AppVisuals.surfaceGreen : AppVisuals.surfaceGreen.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isSelected ? AppVisuals.primaryGold : AppVisuals.textForest.withValues(alpha: 0.05),
                width: 1.5,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppVisuals.primaryGold.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ] : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppVisuals.primaryGold : AppVisuals.textForest.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    farm.type.toLowerCase().contains('sugar') ? Icons.bakery_dining_rounded : Icons.grass_rounded,
                    color: isSelected ? AppVisuals.deepGreen : AppVisuals.primaryGold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farm.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${farm.city}, ${farm.province}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${farm.area.toStringAsFixed(1)} ha',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppVisuals.primaryGold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      context.tr('{days} Days', {'days': '$cropAge'}),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.agriculture_rounded, size: 80, color: AppVisuals.primaryGold.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text(
            context.tr('No estates recorded yet.'),
            style: theme.textTheme.bodyLarge?.copyWith(color: AppVisuals.textForest.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppVisuals.textForest.withValues(alpha: 0.3),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppVisuals.textForest,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.isPrimary = false,
  });

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
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.35,
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
      ),
    );
  }
}
