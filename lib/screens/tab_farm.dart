import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  String? _expandedFarmId;

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
    if (!mounted) return;
    setState(() {
      _expandedFarmId ??= farmProvider.selectedFarm?.id;
    });
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

  void _toggleFarmCard(FarmProvider farmProvider, Farm farm) {
    final isExpanded = _expandedFarmId == farm.id;
    if (!isExpanded) {
      farmProvider.handleFarmSelection(farm);
    }
    setState(() {
      _expandedFarmId = isExpanded ? null : farm.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farmProvider = Provider.of<FarmProvider>(context);
    final farmTypes = farmProvider.uniqueFarmTypes;
    final expectedCount = farmTypes.isEmpty ? 1 : farmTypes.length;

    if (_currentTabCount != expectedCount || _tabController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncTabController());
      return const Center(
          child: CircularProgressIndicator(color: AppVisuals.primaryGold));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: AppVisuals.mainTabBackgroundImageOpacity(
              theme.brightness == Brightness.dark,
            ),
            child: Image.asset(
              'lib/assets/images/1.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppVisuals.mainTabImageOverlay(
                theme.brightness == Brightness.dark,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: FrostedPanel(
            radius: 32,
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surface.withValues(alpha: 0.46),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (farmTypes.isNotEmpty) ...[
                  _buildTabBar(theme, farmTypes),
                  const SizedBox(height: 12),
                ],
                farmTypes.isEmpty
                    ? _buildEmptyState(theme)
                    : SizedBox(
                        height: 600, // Adjusted height for TabBarView
                        child: TabBarView(
                          controller: _tabController!,
                          children: farmTypes.map((type) {
                            final farms =
                                farmProvider.groupedFarms[type] ?? [];
                            return _buildCardList(
                              theme,
                              farms,
                              farmProvider,
                            );
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
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
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
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
        tabs: types
            .map(
              (type) => Tab(
                child: SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      type.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCardList(
      ThemeData theme, List<Farm> farms, FarmProvider farmProvider) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: farms.length,
      itemBuilder: (context, index) {
        final farm = farms[index];
        final isSelected = _expandedFarmId == farm.id;
        final cropAge =
            DateTime.now().difference(farm.date).inDays.clamp(0, 9999);

        return GestureDetector(
          onTap: () => _toggleFarmCard(farmProvider, farm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppVisuals.surfaceGreen
                  : AppVisuals.surfaceGreen.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isSelected
                    ? AppVisuals.primaryGold
                    : AppVisuals.textForest.withValues(alpha: 0.05),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppVisuals.primaryGold.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppVisuals.primaryGold
                            : AppVisuals.textForest.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        farm.type.toLowerCase().contains('sugar')
                            ? Icons.bakery_dining_rounded
                            : Icons.grass_rounded,
                        color: isSelected
                            ? AppVisuals.deepGreen
                            : AppVisuals.primaryGold,
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
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${farm.city}, ${farm.province}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.75),
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
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isSelected) ...[
                  const SizedBox(height: 18),
                  _FarmFieldRow(
                    label: context.tr('Name'),
                    value: farm.name,
                  ),
                  _FarmFieldRow(
                    label: context.tr('Type'),
                    value: farm.type,
                  ),
                  _FarmFieldRow(
                    label: context.tr('Area'),
                    value: '${farm.area.toStringAsFixed(1)} ha',
                  ),
                  _FarmFieldRow(
                    label: context.tr('City'),
                    value: farm.city,
                  ),
                  _FarmFieldRow(
                    label: context.tr('Province'),
                    value: farm.province,
                  ),
                  _FarmFieldRow(
                    label: context.tr('Date'),
                    value: DateFormat('MMM d, y').format(farm.date),
                  ),
                  _FarmFieldRow(
                    label: context.tr('Owner'),
                    value: farm.owner,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _FarmActionIconButton(
                        tooltip: context.tr('Add Job'),
                        icon: Icons.add_task_rounded,
                        onTap: () => _addJob(farm),
                        backgroundColor:
                            theme.colorScheme.secondary.withValues(alpha: 0.14),
                        foregroundColor: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      _FarmActionIconButton(
                        tooltip: context.tr('Edit'),
                        icon: Icons.edit_rounded,
                        onTap: () => _editFarm(farm),
                        backgroundColor:
                            theme.colorScheme.tertiary.withValues(alpha: 0.18),
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      _FarmActionIconButton(
                        tooltip: context.tr('Delete'),
                        icon: Icons.delete_rounded,
                        onTap: () => _deleteFarm(farm),
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.14),
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
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
          Icon(Icons.agriculture_rounded,
              size: 80, color: AppVisuals.primaryGold.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text(
            context.tr('No estates recorded yet.'),
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: AppVisuals.textForest.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  void _editFarm(Farm farm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFarmScreen(farmID: farm.id),
      ),
    );
  }

  void _addJob(Farm farm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrmAddJob2(initialFName: farm.name),
      ),
    );
  }

  Future<void> _deleteFarm(Farm farm) async {
    final farmId = farm.id;
    if (farmId == null) return;
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);

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
  }
}

class _FarmFieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _FarmFieldRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmActionIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  const _FarmActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              color: foregroundColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
