import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity_model.dart';
import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/app_route_observer.dart';
import '../services/app_localization_service.dart';
import '../themes/app_visuals.dart';
import 'frm_add_job2.dart';
import 'frm_add_work_def_screen.dart';

class TabActivities extends StatefulWidget {
  const TabActivities({super.key});

  @override
  State<TabActivities> createState() => _TabActivitiesState();
}

class _TabActivitiesState extends State<TabActivities>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  String _searchQuery = '';
  String _sortMode = 'Date';
  String? _selectedWorkDefId;
  String? _selectedActivityId;
  bool _isRouteObserverSubscribed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChange);
    _clearSelections();
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

  bool get _isLedgerTab => _tabController.index == 0;

  void _handleTabChange() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {
      if (_isLedgerTab) {
        _selectedWorkDefId = null;
      } else {
        _selectedActivityId = null;
      }
    });
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) appRouteObserver.unsubscribe(this);
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _clearSelections() {
    _selectedActivityId = null;
    _selectedWorkDefId = null;
  }

  @override
  void didPush() => _clearSelections();

  @override
  void didPopNext() {
    if (!mounted) return;
    setState(_clearSelections);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nav = Provider.of<NavigationProvider>(context);
    final farmProvider = Provider.of<FarmProvider>(context);
    final activityProvider = Provider.of<ActivityProvider>(context);
    final currency = Provider.of<AppSettingsProvider>(context).currencyFormat;
    final filteredActivities =
        _filteredActivities(farmProvider, activityProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (nav.farmIdToFilter == null) return;
      try {
        final farm =
            farmProvider.farms.firstWhere((f) => f.id == nav.farmIdToFilter);
        if (_searchQuery != farm.name) {
          setState(() {
            _searchQuery = farm.name;
            _selectedActivityId = null;
          });
        }
        nav.clearFarmFilter();
      } catch (_) {}
    });

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
            color: theme.colorScheme.surface.withValues(alpha: 0.48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabBar(theme),
                const SizedBox(height: 12),
                _buildBodyToolbar(theme),
                const SizedBox(height: 12),
                SizedBox(
                  height: 600, // Adjusted height for TabBarView
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActivityLedger(theme, filteredActivities, currency),
                      _buildWorkDefinitions(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Activity> _filteredActivities(
      FarmProvider farmProvider, ActivityProvider activityProvider) {
    final filteredActivities = List<Activity>.from(activityProvider.activities);
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredActivities.removeWhere((act) =>
          !act.farm.toLowerCase().contains(query) &&
          !act.name.toLowerCase().contains(query));
    }
    if (_sortMode == 'Date') {
      filteredActivities.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortMode == 'Farm') {
      filteredActivities.sort((a, b) => a.farm.compareTo(b.farm));
    }
    return filteredActivities;
  }

  Widget _buildBodyToolbar(ThemeData theme) {
    if (!_isLedgerTab) {
      return const SizedBox.shrink();
    }

    final scheme = theme.colorScheme;
    final filtersActive = _searchQuery.isNotEmpty || _sortMode != 'Date';

    return Row(
      children: [
        const Spacer(),
        if (filtersActive) ...[
          _CompactIconButton(
            icon: Icons.restart_alt_rounded,
            tooltip: context.tr('Reset filters'),
            onTap: _resetFilters,
          ),
          const SizedBox(width: 8),
        ],
        _CompactIconButton(
          icon: Icons.filter_alt_rounded,
          tooltip: context.tr('Filter activities'),
          highlighted: filtersActive,
          onTap: _openFilterSheet,
        ),
        if (filtersActive) ...[
          const SizedBox(width: 10),
          Text(
            context.tr('Filtered'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
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
          Tab(text: context.tr('ACTIVITIES').toUpperCase()),
          Tab(text: context.tr('TASKS LIST').toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildActivityLedger(
      ThemeData theme, List<Activity> activities, NumberFormat currency) {
    if (activities.isEmpty) {
      return _buildEmptyState(
          theme, Icons.history_rounded, context.tr('No activities found.'));
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final act = activities[index];
        final isSelected = _selectedActivityId == act.jobId;

        return GestureDetector(
          onTap: () => setState(
              () => _selectedActivityId = isSelected ? null : act.jobId),
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
                      child: Icon(Icons.assignment_rounded,
                          color: isSelected
                              ? AppVisuals.deepGreen
                              : AppVisuals.primaryGold,
                          size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(act.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppVisuals.textForest,
                                  fontWeight: FontWeight.w900)),
                          Text(act.farm,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppVisuals.textForest
                                      .withValues(alpha: 0.4))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(currency.format(act.total),
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: AppVisuals.primaryGold,
                                fontWeight: FontWeight.w900)),
                        Text(DateFormat('MMM d').format(act.date),
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: AppVisuals.textForest
                                    .withValues(alpha: 0.3))),
                      ],
                    ),
                  ],
                ),
                if (isSelected) ...[
                  const SizedBox(height: 18),
                  _DetailsRow(label: context.tr('Tag'), value: act.tag),
                  _DetailsRow(
                    label: context.tr('Date'),
                    value: DateFormat('MMM d, y').format(act.date),
                  ),
                  _DetailsRow(label: context.tr('Farm'), value: act.farm),
                  _DetailsRow(label: context.tr('Name'), value: act.name),
                  _DetailsRow(label: context.tr('Labor'), value: act.labor),
                  _DetailsRow(
                    label: context.tr('Asset Used'),
                    value: act.assetUsed,
                  ),
                  _DetailsRow(
                    label: context.tr('Cost Type'),
                    value: act.costType,
                  ),
                  _DetailsRow(
                    label: context.tr('Duration'),
                    value: act.duration.toStringAsFixed(2),
                  ),
                  _DetailsRow(
                    label: context.tr('Cost'),
                    value: currency.format(act.cost),
                  ),
                  _DetailsRow(
                    label: context.tr('Total'),
                    value: currency.format(act.total),
                  ),
                  _DetailsRow(
                    label: context.tr('Worker'),
                    value: act.worker.trim().isEmpty
                        ? context.tr('None')
                        : act.worker,
                  ),
                  _DetailsRow(
                    label: context.tr('Note'),
                    value: (act.note ?? '').trim().isEmpty
                        ? context.tr('None')
                        : act.note!.trim(),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _editSelectedActivity,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(context.tr('Edit')),
                      ),
                      FilledButton.icon(
                        onPressed: _deleteSelectedActivity,
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        label: Text(context.tr('Delete')),
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

  Widget _buildWorkDefinitions(ThemeData theme) {
    final dataProvider = Provider.of<DataProvider>(context);
    final workDefs = dataProvider.workDefs;

    if (workDefs.isEmpty) {
      return _buildEmptyState(
          theme, Icons.task_rounded, context.tr('No tasks defined.'));
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: workDefs.length,
      itemBuilder: (context, index) {
        final def = workDefs[index];
        final isSelected = _selectedWorkDefId == def.id;

        return GestureDetector(
          onTap: () =>
              setState(() => _selectedWorkDefId = isSelected ? null : def.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppVisuals.surfaceGreen
                  : AppVisuals.surfaceGreen.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: isSelected
                      ? AppVisuals.primaryGold
                      : AppVisuals.textForest.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.label_important_rounded,
                        color: isSelected
                            ? AppVisuals.primaryGold
                            : AppVisuals.textForest.withValues(alpha: 0.2),
                        size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(def.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: AppVisuals.textForest,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppVisuals.primaryGold, size: 20),
                  ],
                ),
                if (isSelected) ...[
                  const SizedBox(height: 18),
                  _DetailsRow(label: context.tr('Name'), value: def.name),
                  _DetailsRow(label: context.tr('Type'), value: def.type),
                  _DetailsRow(
                    label: context.tr('Mode Of Work'),
                    value: def.modeOfWork,
                  ),
                  _DetailsRow(
                    label: context.tr('Cost'),
                    value:
                        Provider.of<AppSettingsProvider>(context, listen: false)
                            .currencyFormat
                            .format(def.cost),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _editSelectedWorkDef,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(context.tr('Edit')),
                      ),
                      FilledButton.icon(
                        onPressed: _deleteSelectedWorkDef,
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        label: Text(context.tr('Delete')),
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

  Widget _buildEmptyState(ThemeData theme, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64, color: AppVisuals.primaryGold.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(message,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppVisuals.textForest.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  void _editSelectedActivity() {
    final activityProvider =
        Provider.of<ActivityProvider>(context, listen: false);
    final activity = activityProvider.activities
        .firstWhere((a) => a.jobId == _selectedActivityId);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FrmAddJob2(editJobId: activity.jobId)));
  }

  void _editSelectedWorkDef() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final workDef =
        dataProvider.workDefs.firstWhere((w) => w.id == _selectedWorkDefId);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FrmAddWorkDefScreen(workDefId: workDef.id)));
  }

  Future<void> _deleteSelectedWorkDef() async {
    final workDefId = _selectedWorkDefId;
    if (workDefId == null) return;

    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final workDef = dataProvider.workDefs.firstWhere((w) => w.id == workDefId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Delete task?')),
          content: Text(
            context.tr(
              'This will permanently delete {task}.',
              {'task': workDef.name},
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

    await dataProvider.deleteWorkDef(workDefId);
    if (!mounted) return;
    setState(() {
      _selectedWorkDefId = null;
    });
  }

  Future<void> _deleteSelectedActivity() async {
    final jobId = _selectedActivityId;
    if (jobId == null) return;

    final activityProvider =
        Provider.of<ActivityProvider>(context, listen: false);
    final activity = activityProvider.getActivityById(jobId);
    if (activity == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Delete job?')),
          content: Text(
            context.tr(
              'This will permanently delete {job}.',
              {'job': activity.name},
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

    await activityProvider.deleteActivity(jobId);
    if (!mounted) return;

    setState(() {
      _selectedActivityId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Deleted {job}.',
            {'job': activity.name},
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final searchController = TextEditingController(text: _searchQuery);
    var draftQuery = _searchQuery;
    var draftSortMode = _sortMode;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final showDetails =
            Provider.of<AppSettingsProvider>(context).showDetailedDescriptions;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Filter activities'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (showDetails) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Search by farm or job name, then choose how the ledger should be ordered.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: context.tr('Search'),
                      hintText: context.tr('Type a farm or job name'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: draftQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                searchController.clear();
                                setModalState(() => draftQuery = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (value) =>
                        setModalState(() => draftQuery = value),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('Sort by'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ['Date', 'Farm'].map((mode) {
                      final selected = draftSortMode == mode;
                      return ChoiceChip(
                        label: Text(context.tr(mode)),
                        selected: selected,
                        onSelected: (_) {
                          setModalState(() => draftSortMode = mode);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            searchController.clear();
                            setModalState(() {
                              draftQuery = '';
                              draftSortMode = 'Date';
                            });
                          },
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: Text(context.tr('Reset')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = draftQuery.trim();
                              _sortMode = draftSortMode;
                              _selectedActivityId = null;
                            });
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(context.tr('Apply')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  void _resetFilters() => setState(() {
        _searchQuery = '';
        _sortMode = 'Date';
        _selectedActivityId = null;
      });
}

class _DetailsRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailsRow({
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
            width: 92,
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

class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: highlighted
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 18,
              color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
