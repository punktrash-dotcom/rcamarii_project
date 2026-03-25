import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/def_sup_model.dart';
import '../components/equipment_tab.dart';
import '../components/supplies_tab.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import '../themes/app_visuals.dart';
import 'frm_add_def_sup_screen.dart';
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
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;
  bool _showCatalogBrowser = false;
  String _catalogFilter = 'All';

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
      child: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildMetricsStrip(theme)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildPriceReferencePanel(theme)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _buildControlPanel(theme)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
        body: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildBodyPanel(theme),
        ),
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
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MarketPriceListScreen())),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: context.tr('Catalog'),
            value: context.tr('Database'),
            icon: Icons.storage_rounded,
            onTap: _openCatalogBrowser,
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
                setState(() => _showCatalogBrowser = false);
                if (_tabController.index != 0) _tabController.animateTo(0);
              },
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.price_check_rounded,
              label: context.tr('Prices'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MarketPriceListScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceReferencePanel(ThemeData theme) {
    final scheme = theme.colorScheme;

    Widget buildPriceShortcut({
      required String label,
      required IconData icon,
      required MarketPriceCategoryFilter filter,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MarketPriceListScreen(initialFilter: filter),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: scheme.primary, size: 18),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.price_change_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Latest Price Lists'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppVisuals.textForest,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Review current fertilizer, herbicide, and pesticide prices before procurement decisions.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForestMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MarketPriceListScreen(),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(context.tr('Open')),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary.withValues(alpha: 0.14),
                  foregroundColor: AppVisuals.textForest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              buildPriceShortcut(
                label: context.tr('All'),
                icon: Icons.grid_view_rounded,
                filter: MarketPriceCategoryFilter.all,
              ),
              const SizedBox(width: 10),
              buildPriceShortcut(
                label: context.tr('Fertilizer'),
                icon: Icons.spa_rounded,
                filter: MarketPriceCategoryFilter.fertilizer,
              ),
              const SizedBox(width: 10),
              buildPriceShortcut(
                label: context.tr('Herbicide'),
                icon: Icons.grass_rounded,
                filter: MarketPriceCategoryFilter.herbicide,
              ),
              const SizedBox(width: 10),
              buildPriceShortcut(
                label: context.tr('Pesticide'),
                icon: Icons.bug_report_rounded,
                filter: MarketPriceCategoryFilter.pesticide,
              ),
            ],
          ),
        ],
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

  void _openCatalogBrowser() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    if (dataProvider.defSups.isEmpty) {
      dataProvider.loadDefSupsFromDb();
    }
    setState(() {
      _showCatalogBrowser = true;
    });
  }

  Widget _buildBodyPanel(ThemeData theme) {
    return FrostedPanel(
      radius: 32,
      padding: const EdgeInsets.all(12),
      child: _showCatalogBrowser
          ? _buildCatalogBrowser(theme)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTabBar(theme),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      SuppliesTab(),
                      EquipmentTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCatalogBrowser(ThemeData theme) {
    final scheme = theme.colorScheme;
    final dataProvider = context.watch<DataProvider>();
    final groupedSupplies = <String, List<DefSup>>{};

    for (final item in dataProvider.defSups) {
      groupedSupplies.putIfAbsent(item.type, () => []).add(item);
    }

    final categories = groupedSupplies.keys.toList()..sort();
    final filteredCategories = _catalogFilter == 'All'
        ? categories
        : categories.where((type) => type == _catalogFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Catalog Browser'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppVisuals.primaryGold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Reference the supply catalog in its own list before selecting items for procurement.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForestMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: context.tr('Add Catalog Item'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FrmAddDefSupScreen(),
                      ),
                    ),
                    icon: Icon(
                      Icons.add_box_outlined,
                      color: scheme.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Close Catalog'),
                    onPressed: () =>
                        setState(() => _showCatalogBrowser = false),
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
          child: Row(
            children: [
              _CatalogFilterChip(
                label: context.tr('All'),
                selected: _catalogFilter == 'All',
                onTap: () => setState(() => _catalogFilter = 'All'),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                _CatalogFilterChip(
                  label: category,
                  selected: _catalogFilter == category,
                  onTap: () => setState(() => _catalogFilter = category),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: filteredCategories.isEmpty
              ? Center(
                  child: Text(
                    context.tr('Database empty'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filteredCategories.length,
                  itemBuilder: (context, index) {
                    final type = filteredCategories[index];
                    final items = groupedSupplies[type]!
                      ..sort(
                        (a, b) => a.name.toLowerCase().compareTo(
                              b.name.toLowerCase(),
                            ),
                      );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        scheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _catalogIcon(type),
                                    color: scheme.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        type.toUpperCase(),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.tr(
                                          '{count} catalog items',
                                          {'count': '${items.length}'},
                                        ),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: AppVisuals.textForestMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ...items.map(
                              (item) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: scheme.surface.withValues(alpha: 0.78),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color:
                                        scheme.outline.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              color: AppVisuals.textForest,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          if (item.description
                                              .trim()
                                              .isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                item.description.trim(),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: AppVisuals
                                                      .textForestMuted,
                                                  height: 1.45,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _catalogPriceLabel(item),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: item.cost > 0
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _catalogIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fertilizer':
        return Icons.spa_rounded;
      case 'herbicide':
        return Icons.grass_rounded;
      case 'pesticide':
        return Icons.bug_report_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  String _catalogPriceLabel(DefSup item) {
    if (item.cost > 0) {
      return '₱${item.cost.toStringAsFixed(2)}';
    }
    return context.tr('No price yet');
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  static const _metricMaroon = AppVisuals.deepGreen;
  const _MetricCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _metricMaroon,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppVisuals.mintAccent.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: _metricMaroon.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppVisuals.lightGold, size: 24),
            const SizedBox(height: 12),
            Text(label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppVisuals.mintAccent.withValues(alpha: 0.88),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    fontSize: 9)),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppVisuals.softWhite, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _CatalogFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatalogFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.32)
                : scheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: selected ? scheme.primary : AppVisuals.textForest,
            fontWeight: FontWeight.w800,
          ),
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
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.isPrimary = false});
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
