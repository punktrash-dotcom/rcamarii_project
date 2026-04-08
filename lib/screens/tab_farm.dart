import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/farm_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../services/app_localization_service.dart';
import '../services/farm_operations_service.dart';
import '../services/app_route_observer.dart';
import '../themes/app_visuals.dart';
import 'farm_harvest_board_screen.dart';
import 'add_farm_screen.dart';
import 'crop_simulation_screen.dart';
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
  String? _focusedFarmId;
  bool _didRequestInitialCardFocus = false;
  final Map<String, FocusNode> _farmCardFocusNodes = {};

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
    _syncFarmCardFocusNodes(farmProvider.farms);
    final selectedFarm = farmProvider.selectedFarm;
    setState(() {
      _expandedFarmId = selectedFarm?.id;
      _focusedFarmId = selectedFarm?.id ??
          (farmProvider.farms.isEmpty ? null : farmProvider.farms.first.id);
      _didRequestInitialCardFocus = false;
    });
    _requestInitialCardFocus();
    _syncTabController();
    _selectTabForFarmType(selectedFarm?.type);
  }

  void _syncFarmCardFocusNodes(List<Farm> farms) {
    final validIds = farms.map((farm) => farm.id).whereType<String>().toSet();
    final removedIds = _farmCardFocusNodes.keys
        .where((id) => !validIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      _farmCardFocusNodes.remove(id)?.dispose();
    }
    for (final id in validIds) {
      _farmCardFocusNodes.putIfAbsent(id, FocusNode.new);
    }
    if (_focusedFarmId != null && !validIds.contains(_focusedFarmId)) {
      _focusedFarmId = null;
    }
  }

  void _requestInitialCardFocus() {
    if (_didRequestInitialCardFocus || !mounted) {
      return;
    }
    final focusedFarmId = _focusedFarmId;
    if (focusedFarmId == null) {
      return;
    }
    _didRequestInitialCardFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _farmCardFocusNodes[focusedFarmId]?.requestFocus();
    });
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

  void _selectTabForFarmType(String? farmType) {
    final tabController = _tabController;
    if (!mounted || tabController == null || farmType == null) {
      return;
    }
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    final types = farmProvider.uniqueFarmTypes;
    final targetIndex = types.indexOf(farmType);
    if (targetIndex < 0 || targetIndex >= tabController.length) {
      return;
    }
    if (tabController.index != targetIndex) {
      tabController.index = targetIndex;
    }
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) appRouteObserver.unsubscribe(this);
    unawaited(_stopScreenOpenAudioIfNeeded());
    _tabController?.dispose();
    for (final node in _farmCardFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didPushNext() => unawaited(_stopScreenOpenAudioIfNeeded());
  @override
  void didPop() => unawaited(_stopScreenOpenAudioIfNeeded());
  @override
  void didPopNext() {
    unawaited(_initData());
    unawaited(_playScreenOpenAudioIfNeeded());
  }

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
    _syncFarmCardFocusNodes(farmProvider.farms);
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: FrostedPanel(
            radius: 32,
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surface.withValues(alpha: 0.46),
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
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: farms.length,
      itemBuilder: (context, index) {
        final farm = farms[index];
        final farmId = farm.id;
        final isSelected = _expandedFarmId == farm.id;
        final isFocused = _focusedFarmId == farm.id;
        final cropAge =
            DateTime.now().difference(farm.date).inDays.clamp(0, 9999);
        final backgroundAsset = FarmOperationsService.cropBackdropAssetForAge(
          farm.type,
          cropAge,
        );
        final growthStage =
            FarmOperationsService.growthStage(farm.type, cropAge);
        final focusNode = farmId == null
            ? null
            : _farmCardFocusNodes.putIfAbsent(farmId, FocusNode.new);

        return FocusableActionDetector(
          focusNode: focusNode,
          autofocus: index == 0 && !_didRequestInitialCardFocus,
          onFocusChange: (hasFocus) {
            if (!mounted || farmId == null) return;
            setState(() {
              if (hasFocus) {
                _focusedFarmId = farmId;
              } else if (_focusedFarmId == farmId) {
                _focusedFarmId = null;
              }
            });
          },
          shortcuts: <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggleFarmCard(farmProvider, farm);
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: () {
              focusNode?.requestFocus();
              _toggleFarmCard(farmProvider, farm);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isSelected || isFocused
                      ? AppVisuals.primaryGold
                      : AppVisuals.textForest.withValues(alpha: 0.05),
                  width: isFocused ? 2 : 1.5,
                ),
                boxShadow: isSelected || isFocused
                    ? [
                        BoxShadow(
                          color: AppVisuals.primaryGold.withValues(
                            alpha: isSelected ? 0.15 : 0.1,
                          ),
                          blurRadius: isSelected ? 20 : 14,
                          offset: const Offset(0, 8),
                        )
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      backgroundAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withValues(
                              alpha: isSelected ? 0.26 : 0.34,
                            ),
                            const Color(0xFF102516).withValues(
                              alpha: isSelected ? 0.58 : 0.72,
                            ),
                            const Color(0xFF07130C).withValues(
                              alpha: isSelected ? 0.82 : 0.88,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: isSelected || isFocused ? 0.22 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Icon(
                                farm.type.toLowerCase().contains('sugar')
                                    ? Icons.bakery_dining_rounded
                                    : Icons.grass_rounded,
                                color: AppVisuals.primaryGold,
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
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${farm.city}, ${farm.province}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.78),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _FarmCardBadge(
                                        label: growthStage,
                                        color: AppVisuals.brandGreen,
                                      ),
                                      _FarmCardBadge(
                                        label: context.tr(
                                          '{days} Days',
                                          {'days': '$cropAge'},
                                        ),
                                        color: AppVisuals.primaryGold,
                                      ),
                                    ],
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
                                  FarmOperationsService.seasonLabel(farm.date),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
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
                            lightText: true,
                          ),
                          _FarmFieldRow(
                            label: context.tr('Type'),
                            value: farm.type,
                            lightText: true,
                          ),
                          _FarmFieldRow(
                            label: context.tr('Area'),
                            value: '${farm.area.toStringAsFixed(1)} ha',
                            lightText: true,
                          ),
                          _FarmFieldRow(
                            label: context.tr('City'),
                            value: farm.city,
                            lightText: true,
                          ),
                          _FarmFieldRow(
                            label: context.tr('Province'),
                            value: farm.province,
                            lightText: true,
                          ),
                          _FarmFieldRow(
                            label: context.tr('Date'),
                            value: DateFormat('MMM d, y').format(farm.date),
                            lightText: true,
                          ),
                          _FarmFieldRow(
                            label: context.tr('Owner'),
                            value: farm.owner,
                            lightText: true,
                          ),
                          _FarmFieldRow(
                            label: context.tr('Season'),
                            value: 'Season ${farm.seasonNumber}',
                            lightText: true,
                          ),
                          _FarmFieldRow(
                            label: context.tr('Harvest'),
                            value: FarmOperationsService.isHarvestStatus(farm)
                                ? 'Harvest Status'
                                : 'Pre-Harvest',
                            lightText: true,
                          ),
                          if (farm.type.toLowerCase().contains('sugar'))
                            _FarmFieldRow(
                              label: context.tr('Ratoon'),
                              value: '${farm.ratoonCount}',
                              lightText: true,
                            ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FarmActionIconButton(
                                tooltip: 'Crop simulator',
                                icon: Icons.view_in_ar_rounded,
                                onTap: () => _openCropSimulation(farm),
                                backgroundColor: theme.colorScheme.tertiary
                                    .withValues(alpha: 0.24),
                                foregroundColor: Colors.white,
                              ),
                              _FarmActionIconButton(
                                tooltip: FarmOperationsService.isHarvestStatus(
                                        farm)
                                    ? context.tr('Harvest Board')
                                    : 'Harvest Board is view-only until harvest status or early harvest is enabled.',
                                icon: Icons.ssid_chart_rounded,
                                onTap: () => _openHarvestBoard(farm),
                                backgroundColor: AppVisuals.primaryGold
                                    .withValues(alpha: 0.24),
                                foregroundColor: Colors.white,
                              ),
                              _FarmActionIconButton(
                                tooltip: context.tr('Add Job'),
                                icon: Icons.add_task_rounded,
                                onTap: () => _addJob(farm),
                                backgroundColor: theme.colorScheme.secondary
                                    .withValues(alpha: 0.2),
                                foregroundColor: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              _FarmActionIconButton(
                                tooltip: context.tr('Edit'),
                                icon: Icons.edit_rounded,
                                onTap: () => _editFarm(farm),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.16,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              _FarmActionIconButton(
                                tooltip: context.tr('Delete'),
                                icon: Icons.delete_rounded,
                                onTap: () => _deleteFarm(farm),
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.24),
                                foregroundColor: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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

  void _openHarvestBoard(Farm farm) {
    if (!FarmOperationsService.isHarvestStatus(farm)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'This farm is not yet in harvest status. Harvest Board inputs stay locked until harvest status or Early Harvest is enabled.',
            ),
          ),
        );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FarmHarvestBoardScreen(farm: farm),
      ),
    );
  }

  void _openCropSimulation(Farm farm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropSimulationScreen(farm: farm),
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

class _FarmCardBadge extends StatelessWidget {
  const _FarmCardBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _FarmFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool lightText;

  const _FarmFieldRow({
    required this.label,
    required this.value,
    this.lightText = false,
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
                color: lightText
                    ? Colors.white.withValues(alpha: 0.74)
                    : AppVisuals.textForestMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: lightText ? Colors.white : AppVisuals.textForest,
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
