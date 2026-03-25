import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity_model.dart';
import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/navigation_provider.dart';
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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _sortMode = 'Date';
  String? _selectedWorkDefId;
  String? _selectedActivityId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChange);
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
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActivityMetrics(theme, filteredActivities, currency),
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
                        _buildActivityLedger(
                            theme, filteredActivities, currency),
                        _buildWorkDefinitions(theme),
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

  Widget _buildActivityMetrics(
      ThemeData theme, List<Activity> activities, NumberFormat currency) {
    final totalAmount =
        activities.fold<double>(0, (sum, act) => sum + act.total);
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: context.tr('Total Jobs'),
            value: activities.length.toString(),
            icon: Icons.work_history_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: context.tr('Total Spend'),
            value: currency.format(totalAmount),
            icon: Icons.payments_rounded,
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
            if (_isLedgerTab) ...[
              _ActionButton(
                icon: Icons.add_task_rounded,
                label: context.tr('New Job'),
                onTap: _openNewJobOrderForm,
                isPrimary: true,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                icon: Icons.edit_rounded,
                label: context.tr('Edit'),
                onTap:
                    _selectedActivityId == null ? () {} : _editSelectedActivity,
                enabled: _selectedActivityId != null,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                icon: Icons.delete_rounded,
                label: context.tr('Delete'),
                onTap: _selectedActivityId == null
                    ? () {}
                    : _deleteSelectedActivity,
                enabled: _selectedActivityId != null,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                icon: Icons.filter_alt_rounded,
                label: context.tr('Filter'),
                onTap: _openFilterSheet,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                icon: Icons.restart_alt_rounded,
                label: context.tr('Reset'),
                onTap: _resetFilters,
              ),
            ] else ...[
              _ActionButton(
                icon: Icons.add_rounded,
                label: context.tr('New Task'),
                onTap: _openAddWorkDefinitionForm,
                isPrimary: true,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                icon: Icons.edit_rounded,
                label: context.tr('Edit'),
                onTap:
                    _selectedWorkDefId == null ? () {} : _editSelectedWorkDef,
                enabled: _selectedWorkDefId != null,
              ),
            ],
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
          Tab(text: context.tr('LEDGER').toUpperCase()),
          Tab(text: context.tr('TASKS').toUpperCase()),
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
            child: Row(
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
                            color:
                                AppVisuals.textForest.withValues(alpha: 0.3))),
                  ],
                ),
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
            child: Row(
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

  void _openNewJobOrderForm() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const FrmAddJob2()));
  void _openAddWorkDefinitionForm() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const FrmAddWorkDefScreen()));
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  static const _metricMaroon = AppVisuals.deepGreen;
  const _MetricCard(
      {required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool isPrimary;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.enabled = true,
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
