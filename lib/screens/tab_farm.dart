import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/farm_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../widgets/modern_screen_shell.dart';
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
    if (!mounted || _playedScreenOpenAudio) {
      return;
    }
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    _playedScreenOpenAudio = true;
    await context.read<AppAudioProvider>().playScreenOpenSound(
          screenKey: 'tab_farm',
          style: appSettings.audioSoundStyle,
          enabled: appSettings.audioSoundsEnabled,
        );
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    await context.read<AppAudioProvider>().stopScreenOpenSound(
          screenKey: 'tab_farm',
          style: appSettings.audioSoundStyle,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopScreenOpenAudioIfNeeded());
    _tabController?.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    unawaited(_stopScreenOpenAudioIfNeeded());
  }

  @override
  void didPop() {
    unawaited(_stopScreenOpenAudioIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final farmProvider = Provider.of<FarmProvider>(context);
    final farmTypes = farmProvider.uniqueFarmTypes;
    const lightTeal = Color.fromARGB(252, 169, 173, 170);

    final expectedCount = farmTypes.isEmpty ? 1 : farmTypes.length;

    if (_currentTabCount != expectedCount || _tabController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncTabController());
      return const Center(child: CircularProgressIndicator(color: lightTeal));
    }

    if (farmProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: lightTeal));
    }

    return ModernScreenShell(
      title: context.tr('Estate Oversight'),
      subtitle: '',
      titleStyleOverride: const TextStyle(color: Colors.white),
      subtitleStyleOverride: const TextStyle(color: Colors.white),
      outerPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      headerPadding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      bodyPadding: const EdgeInsets.symmetric(vertical: 6),
      headerGap: 10,
      titleGap: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 560;
          final sectionGap = compact ? 8.0 : 12.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFarmMetrics(farmProvider, compact: compact),
              SizedBox(height: sectionGap),
              _buildTabBarRow(farmTypes, compact: compact),
              SizedBox(height: sectionGap),
              _buildHorizontalControlPanel(
                farmProvider,
                compact: compact,
              ),
              SizedBox(height: sectionGap),
              Expanded(
                child: farmTypes.isEmpty
                    ? _buildEmptyState(compact: compact)
                    : TabBarView(
                        controller: _tabController!,
                        children: farmTypes.map((type) {
                          final farms = farmProvider.groupedFarms[type] ?? [];
                          return _buildCardList(
                            farms,
                            farmProvider,
                            compact: compact,
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHorizontalControlPanel(
    FarmProvider farmProvider, {
    required bool compact,
  }) {
    return Container(
      height: compact ? 64 : 70,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2421),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          vertical: compact ? 6 : 8,
          horizontal: compact ? 6 : 8,
        ),
        children: [
          _buildHorizontalButton(
            Icons.add_home_work_rounded,
            context.tr('ADD ESTATE'),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddFarmScreen(),
                ),
              );
            },
            compact: compact,
          ),
          _buildHorizontalButton(
            Icons.add_task_rounded,
            context.tr('ADD TASK'),
            () {
              if (farmProvider.selectedFarm != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FrmAddJob2(
                      initialFName: farmProvider.selectedFarm!.name,
                    ),
                  ),
                );
              }
            },
            enabled: farmProvider.selectedFarm != null,
            compact: compact,
          ),
          _buildHorizontalButton(
            Icons.edit_document,
            context.tr('EDIT'),
            () {
              if (farmProvider.selectedFarm != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddFarmScreen(farmID: farmProvider.selectedFarm!.id),
                  ),
                );
              }
            },
            enabled: farmProvider.selectedFarm != null,
            compact: compact,
          ),
          _buildHorizontalButton(
            Icons.delete_forever_rounded,
            context.tr('DELETE'),
            () {
              if (farmProvider.selectedFarm != null) {
                _confirmDelete(farmProvider.selectedFarm!.id!, farmProvider);
              }
            },
            isDelete: true,
            enabled: farmProvider.selectedFarm != null,
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDelete = false,
    bool enabled = true,
    required bool compact,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: compact ? 14 : 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDelete ? Colors.redAccent : Colors.white70,
          disabledForegroundColor: Colors.white12,
          side: BorderSide(
            color: isDelete
                ? Colors.redAccent.withValues(alpha: 0.4)
                : Colors.white12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: Size(0, compact ? 40 : 44),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          visualDensity:
              compact ? VisualDensity.compact : VisualDensity.standard,
          textStyle: TextStyle(
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildFarmMetrics(FarmProvider provider, {required bool compact}) {
    final totalFarms = provider.farms.length;
    final totalArea =
        provider.farms.fold<double>(0, (sum, farm) => sum + farm.area);
    final active = provider.selectedFarm;

    return SizedBox(
      height: compact ? 50 : 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildMetricTile(
            context.tr('Estates'),
            totalFarms.toString(),
            Icons.home_work_rounded,
            compact: compact,
          ),
          _buildMetricTile(
            context.tr('Area'),
            '${totalArea.toStringAsFixed(1)} ha',
            Icons.map_rounded,
            compact: compact,
          ),
          _buildMetricTile(
            context.tr('Farm'),
            active?.name ?? context.tr('None'),
            Icons.visibility_rounded,
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    IconData icon, {
    required bool compact,
  }) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: accent),
          SizedBox(width: compact ? 5 : 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 9 : 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarRow(List<String> farmTypes, {required bool compact}) {
    final accent = Theme.of(context).colorScheme.secondary;
    final baseColor = Theme.of(context).colorScheme.surface;
    const unselectedFarmTypeColor = Color(0xFF4F4F4F);
    final tabWidth = compact ? 112.0 : 128.0;
    final tabHeight = compact ? 38.0 : 42.0;

    return Container(
      height: compact ? 48 : 54,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.9),
              accent.withValues(alpha: 0.4),
            ],
          ),
        ),
        labelColor: Colors.black87,
        unselectedLabelColor: unselectedFarmTypeColor,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          fontSize: compact ? 11 : 12,
        ),
        tabs: farmTypes.isEmpty
            ? [
                Tab(
                  child: SizedBox(
                    width: tabWidth,
                    height: tabHeight,
                    child: Center(child: Text(context.tr('NO DATA'))),
                  ),
                ),
              ]
            : farmTypes
                .map(
                  (type) => Tab(
                    child: SizedBox(
                      width: tabWidth,
                      height: tabHeight,
                      child: Center(
                        child: Text(
                          type.toUpperCase(),
                          textAlign: TextAlign.center,
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
    List<Farm> farms,
    FarmProvider farmProvider, {
    required bool compact,
  }) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12, compact ? 4 : 8, 12, 12),
      itemCount: farms.length,
      itemBuilder: (context, index) {
        final farm = farms[index];
        final isSelected = farmProvider.selectedFarm?.id == farm.id;
        final cropAge = DateTime.now().difference(farm.date).inDays;

        return GestureDetector(
          onTap: () => farmProvider.handleFarmSelection(farm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: compact ? 10 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFF8DB35E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFC0CA33)
                    : Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 20,
                vertical: compact ? 6 : 8,
              ),
              leading: Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFFC0CA33)
                      : Colors.black.withValues(alpha: 0.1),
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Center(
                  child: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF1A2421),
                          size: 24,
                        )
                      : Text(
                          farm.id.toString(),
                          style: const TextStyle(
                            color: Color(0xFF1A2421),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              title: Text(
                farm.name,
                style: TextStyle(
                  color: const Color(0xFF1A2421),
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 15 : 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: compact ? 1 : 2),
                  Text(
                    context.tr(
                      'Age of Crop: {days} days',
                      {'days': '$cropAge'},
                    ),
                    style: TextStyle(
                      color: const Color(0xFF1A2421),
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.tr(
                      '{type} - {area} Hectares',
                      {
                        'type': farm.type,
                        'area': farm.area.toString(),
                      },
                    ),
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.tr(
                      'Location: {city}, {province}',
                      {
                        'city': farm.city.toLowerCase(),
                        'province': farm.province.toLowerCase(),
                      },
                    ),
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: compact ? 9 : 10,
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF1A2421),
                ),
                onSelected: (value) {
                  if (value == 'Activities') {
                    farmProvider.handleFarmSelection(farm);
                    Provider.of<NavigationProvider>(context, listen: false)
                        .changeTab(1, farmId: farm.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'Activities',
                    child: Text(
                      context.tr('View Details'),
                      style: const TextStyle(fontSize: 12),
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

  Widget _buildEmptyState({required bool compact}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.tr('TERMINAL STANDBY'),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddFarmScreen()),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              context.tr('INITIALIZE NEW ESTATE'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, FarmProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2421),
        title: Text(
          context.tr('Confirm Removal'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        content: Text(
          context
              .tr('Are you sure you want to remove this record from the grid?'),
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('CANCEL'),
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr('REMOVE'),
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      provider.deleteFarm(id);
    }
  }
}
