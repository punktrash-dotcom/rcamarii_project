import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity_model.dart';
import '../models/farm_model.dart';
import '../models/work_def_model.dart';
import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/app_localization_service.dart';
import '../widgets/modern_screen_shell.dart';
import 'frm_add_job2.dart';
import 'frm_add_work_def_screen.dart';

class TabActivities extends StatefulWidget {
  const TabActivities({super.key});

  @override
  State<TabActivities> createState() => _TabActivitiesState();
}

class _TabActivitiesState extends State<TabActivities>
    with SingleTickerProviderStateMixin {
  static const _panelColor = Color(0xFF1A2421);
  static const _cardColor = Color(0xFF8DB35E);
  static const _selectedColor = Color(0xFFC0CA33);
  static const _darkText = Color(0xFF1A2421);
  static const _unselectedTabColor = Color(0xFF4F4F4F);

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
    if (!mounted || _tabController.indexIsChanging) {
      return;
    }

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
    final nav = Provider.of<NavigationProvider>(context);
    final farmProvider = Provider.of<FarmProvider>(context);
    final activityProvider = Provider.of<ActivityProvider>(context);
    final currency = Provider.of<AppSettingsProvider>(context).currencyFormat;
    final filteredActivities =
        _filteredActivities(farmProvider, activityProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (nav.farmIdToFilter == null) {
        return;
      }
      try {
        final farm =
            farmProvider.farms.firstWhere((f) => f.id == nav.farmIdToFilter);
        if (_searchQuery != farm.name) {
          setState(() {
            _searchQuery = farm.name;
            _selectedActivityId = null;
          });
        }
      } catch (_) {}
    });

    return ModernScreenShell(
      title: context.tr('Activity Intelligence'),
      subtitle: '',
      actionBadge: _buildNewJobOrderButton(),
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
              _buildActivityMetrics(
                filteredActivities,
                currency,
                compact: compact,
              ),
              SizedBox(height: sectionGap),
              _buildTabBarRow(compact: compact),
              SizedBox(height: sectionGap),
              _buildControlPanel(compact: compact),
              SizedBox(height: sectionGap),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActivityLedger(
                      filteredActivities,
                      currency,
                      compact: compact,
                    ),
                    _buildWorkDefinitions(compact: compact),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Activity> _filteredActivities(
    FarmProvider farmProvider,
    ActivityProvider activityProvider,
  ) {
    final filteredActivities = List<Activity>.from(activityProvider.activities);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredActivities.removeWhere((act) {
        return !act.farm.toLowerCase().contains(query) &&
            !act.name.toLowerCase().contains(query);
      });
    }

    if (_sortMode == 'Date') {
      filteredActivities.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortMode == 'Farm') {
      filteredActivities.sort((a, b) => a.farm.compareTo(b.farm));
    } else if (_sortMode == 'Crop') {
      filteredActivities.sort((a, b) {
        final farmA = farmProvider.farms.firstWhere(
          (f) => f.name == a.farm,
          orElse: () => Farm(
            id: '0',
            name: '',
            type: '',
            area: 0,
            city: '',
            province: '',
            date: DateTime.now(),
            owner: '',
          ),
        );
        final farmB = farmProvider.farms.firstWhere(
          (f) => f.name == b.farm,
          orElse: () => Farm(
            id: '0',
            name: '',
            type: '',
            area: 0,
            city: '',
            province: '',
            date: DateTime.now(),
            owner: '',
          ),
        );
        return farmA.type.compareTo(farmB.type);
      });
    }

    return filteredActivities;
  }

  Widget _buildNewJobOrderButton() {
    return OutlinedButton.icon(
      onPressed: _openNewJobOrderForm,
      icon: const Icon(Icons.add_task_rounded, size: 16),
      label: Text(context.tr('NEW JOB ORDER')),
      style: _buildToolbarButtonStyle(compact: false),
    );
  }

  Widget _buildActivityMetrics(
    List<Activity> activities,
    NumberFormat currency, {
    required bool compact,
  }) {
    final totalAmount =
        activities.fold<double>(0, (sum, act) => sum + act.total);
    final focusLabel =
        _searchQuery.isEmpty ? context.tr('All farms') : _searchQuery;

    return SizedBox(
      height: compact ? 50 : 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildMetricTile(
            context.tr('Jobs'),
            activities.length.toString(),
            Icons.list_alt_rounded,
            compact: compact,
          ),
          _buildMetricTile(
            context.tr('Spend'),
            _formatCurrencyTrimmed(currency, totalAmount),
            Icons.payments_rounded,
            compact: compact,
          ),
          _buildMetricTile(
            context.tr('Focus'),
            focusLabel,
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
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 120 : 150),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarRow({required bool compact}) {
    final accent = Theme.of(context).colorScheme.secondary;
    final baseColor = Theme.of(context).colorScheme.surface;
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
        unselectedLabelColor: _unselectedTabColor,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          fontSize: compact ? 11 : 12,
        ),
        tabs: [context.tr('LEDGER'), context.tr('TASKS')]
            .map(
              (label) => Tab(
                child: SizedBox(
                  width: tabWidth,
                  height: tabHeight,
                  child: Center(
                    child: Text(
                      label,
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

  Widget _buildControlPanel({required bool compact}) {
    return Container(
      height: compact ? 64 : 70,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _panelColor,
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
        children: _isLedgerTab
            ? _buildLedgerToolbarActions(compact: compact)
            : _buildTaskToolbarActions(compact: compact),
      ),
    );
  }

  List<Widget> _buildLedgerToolbarActions({required bool compact}) {
    return [
      _buildSortMenuButton(compact: compact),
      _buildToolbarActionButton(
        Icons.restart_alt_rounded,
        context.tr('RESET'),
        _resetFilters,
        compact: compact,
      ),
      _buildToolbarActionButton(
        Icons.edit_document,
        context.tr('EDIT'),
        _selectedActivityId == null ? null : _editSelectedActivity,
        enabled: _selectedActivityId != null,
        compact: compact,
      ),
      _buildToolbarActionButton(
        Icons.delete_forever_rounded,
        context.tr('DELETE'),
        _selectedActivityId == null ? null : _deleteSelectedActivity,
        enabled: _selectedActivityId != null,
        isDelete: true,
        compact: compact,
      ),
    ];
  }

  List<Widget> _buildTaskToolbarActions({required bool compact}) {
    return [
      _buildToolbarActionButton(
        Icons.add_rounded,
        context.tr('ADD TASK'),
        _openAddWorkDefinitionForm,
        compact: compact,
      ),
      _buildToolbarActionButton(
        Icons.edit_document,
        context.tr('EDIT'),
        _selectedWorkDefId == null ? null : _editSelectedWorkDef,
        enabled: _selectedWorkDefId != null,
        compact: compact,
      ),
      _buildToolbarActionButton(
        Icons.delete_forever_rounded,
        context.tr('DELETE'),
        _selectedWorkDefId == null ? null : _deleteSelectedWorkDef,
        enabled: _selectedWorkDefId != null,
        isDelete: true,
        compact: compact,
      ),
    ];
  }

  Widget _buildSortMenuButton({required bool compact}) {
    const filterChoices = ['Date', 'Farm', 'Crop'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
      child: PopupMenuButton<String>(
        tooltip: context.tr('Sort activities'),
        onSelected: (value) {
          setState(() {
            _sortMode = value;
            _selectedActivityId = null;
          });
        },
        itemBuilder: (context) => filterChoices
            .map(
              (choice) => CheckedPopupMenuItem<String>(
                value: choice,
                checked: _sortMode == choice,
                child: Text(context.tr(choice)),
              ),
            )
            .toList(),
        child: _buildToolbarButtonShell(
          icon: Icons.sort_rounded,
          label: context.tr(
            'SORT: {mode}',
            {'mode': context.tr(_sortMode).toUpperCase()},
          ),
          compact: compact,
        ),
      ),
    );
  }

  Widget _buildToolbarActionButton(
    IconData icon,
    String label,
    VoidCallback? onTap, {
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
        style: _buildToolbarButtonStyle(
          compact: compact,
          isDelete: isDelete,
        ),
      ),
    );
  }

  Widget _buildToolbarButtonShell({
    required IconData icon,
    required String label,
    required bool compact,
    bool isDelete = false,
    bool enabled = true,
  }) {
    final foregroundColor = enabled
        ? (isDelete ? Colors.redAccent : Colors.white70)
        : Colors.white12;
    final borderColor = enabled
        ? (isDelete ? Colors.redAccent.withValues(alpha: 0.4) : Colors.white12)
        : Colors.white12;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: foregroundColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _buildToolbarButtonStyle({
    required bool compact,
    bool isDelete = false,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: isDelete ? Colors.redAccent : Colors.white70,
      disabledForegroundColor: Colors.white12,
      side: BorderSide(
        color:
            isDelete ? Colors.redAccent.withValues(alpha: 0.4) : Colors.white12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      minimumSize: Size(0, compact ? 40 : 44),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      textStyle: TextStyle(
        fontSize: compact ? 9 : 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildActivityLedger(
    List<Activity> filteredActivities,
    NumberFormat currency, {
    required bool compact,
  }) {
    if (filteredActivities.isEmpty) {
      return _buildEmptyActivityState(compact: compact);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12, compact ? 4 : 8, 12, 12),
      itemCount: filteredActivities.length,
      itemBuilder: (context, index) {
        final act = filteredActivities[index];
        return _buildActivityCard(act, currency, compact: compact);
      },
    );
  }

  Widget _buildActivityCard(
    Activity activity,
    NumberFormat currency, {
    required bool compact,
  }) {
    final isSelected = activity.jobId == _selectedActivityId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedActivityId = isSelected ? null : activity.jobId;
        });
      },
      onLongPress: () => _showEditDialog(activity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: compact ? 10 : 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _selectedColor
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
          leading: _buildSelectionAvatar(
            label: _activityBadgeLabel(activity),
            isSelected: isSelected,
            compact: compact,
          ),
          title: Text(
            activity.name,
            style: TextStyle(
              color: _darkText,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 15 : 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: compact ? 1 : 2),
              Text(
                DateFormat('MMM dd, yyyy').format(activity.date),
                style: TextStyle(
                  color: _darkText,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${activity.farm} - ${activity.labor}',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                activity.worker.isEmpty
                    ? context.tr('Worker: Unassigned')
                    : context.tr(
                        'Worker: {worker}',
                        {'worker': activity.worker},
                      ),
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: compact ? 9 : 10,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrencyTrimmed(currency, activity.total),
                style: TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 12 : 13,
                ),
              ),
              Text(
                _activityDurationLabel(activity),
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkDefinitions({required bool compact}) {
    final dataProvider = Provider.of<DataProvider>(context);
    final workDefs = dataProvider.workDefs;
    final currency = Provider.of<AppSettingsProvider>(context).currencyFormat;

    if (workDefs.isEmpty) {
      return _buildEmptyWorkDefState(compact: compact);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12, compact ? 4 : 8, 12, 12),
      itemCount: workDefs.length,
      itemBuilder: (context, index) {
        final def = workDefs[index];
        final isSelected = _selectedWorkDefId == def.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedWorkDefId = isSelected ? null : def.id;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: compact ? 10 : 12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? _selectedColor
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
              leading: _buildSelectionAvatar(
                label: _workDefBadgeLabel(def),
                isSelected: isSelected,
                compact: compact,
              ),
              title: Text(
                def.name,
                style: TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 15 : 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: compact ? 1 : 2),
                  Text(
                    context.tr('Type: {type}', {'type': def.type}),
                    style: TextStyle(
                      color: _darkText,
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.tr('Mode: {mode}', {'mode': def.modeOfWork}),
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.tr('Ready for selection in new job orders'),
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: compact ? 9 : 10,
                    ),
                  ),
                ],
              ),
              trailing: Text(
                _formatCurrencyTrimmed(currency, def.cost),
                style: TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionAvatar({
    required String label,
    required bool isSelected,
    required bool compact,
  }) {
    return Container(
      width: compact ? 40 : 44,
      height: compact ? 40 : 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isSelected ? _selectedColor : Colors.black.withValues(alpha: 0.1),
        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Center(
        child: isSelected
            ? const Icon(
                Icons.check_circle_rounded,
                color: _darkText,
                size: 24,
              )
            : Text(
                label,
                style: TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.w900,
                  fontSize: label.length > 1 ? 10 : 12,
                ),
              ),
      ),
    );
  }

  String _activityBadgeLabel(Activity activity) {
    final source =
        activity.tag.trim().isNotEmpty ? activity.tag : activity.name;
    final normalized =
        source.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (normalized.isEmpty) {
      return 'A';
    }
    return normalized.length == 1 ? normalized : normalized.substring(0, 2);
  }

  String _workDefBadgeLabel(WorkDef workDef) {
    final normalized =
        workDef.type.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (normalized.isEmpty) {
      return 'WD';
    }
    return normalized.length == 1 ? normalized : normalized.substring(0, 2);
  }

  String _activityDurationLabel(Activity activity) {
    if (activity.duration <= 0) {
      return activity.costType;
    }
    final durationText =
        activity.duration.truncateToDouble() == activity.duration
            ? activity.duration.toStringAsFixed(0)
            : activity.duration.toStringAsFixed(1);
    return context.tr('{duration} hr', {'duration': durationText});
  }

  Widget _buildEmptyActivityState({required bool compact}) {
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
            onPressed: _openNewJobOrderForm,
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              context.tr('INITIALIZE NEW JOB ORDER'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkDefState({required bool compact}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.tr('TASK GRID EMPTY'),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          OutlinedButton.icon(
            onPressed: _openAddWorkDefinitionForm,
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              context.tr('ADD TASK DEFINITION'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _openNewJobOrderForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrmAddJob2(initialFName: _searchQuery),
      ),
    );
  }

  Future<void> _openAddWorkDefinitionForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FrmAddWorkDefScreen(),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _selectedWorkDefId = null);
  }

  Future<void> _editSelectedWorkDef() async {
    if (_selectedWorkDefId == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrmAddWorkDefScreen(workDefId: _selectedWorkDefId),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _selectedWorkDefId = null);
  }

  Future<void> _deleteSelectedWorkDef() async {
    if (_selectedWorkDefId == null) {
      return;
    }

    final provider = Provider.of<DataProvider>(context, listen: false);
    WorkDef? selectedDef;
    for (final def in provider.workDefs) {
      if (def.id == _selectedWorkDefId) {
        selectedDef = def;
        break;
      }
    }

    if (selectedDef == null) {
      setState(() => _selectedWorkDefId = null);
      return;
    }
    final selectedDefName = selectedDef.name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelColor,
        title: Text(
          context.tr('Confirm Removal'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        content: Text(
          context.tr(
            'Are you sure you want to remove "{name}" from task definitions?',
            {'name': selectedDefName},
          ),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('CANCEL'),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr('REMOVE'),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await provider.deleteWorkDef(selectedDef.id);
    if (!mounted) {
      return;
    }

    setState(() => _selectedWorkDefId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Task definition removed'))),
    );
  }

  void _resetFilters() {
    Provider.of<NavigationProvider>(context, listen: false).clearFarmFilter();
    setState(() {
      _searchQuery = '';
      _sortMode = 'Date';
      _selectedActivityId = null;
    });
  }

  void _editSelectedActivity() {
    if (_selectedActivityId == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrmAddJob2(editJobId: _selectedActivityId!),
      ),
    );
  }

  Future<void> _deleteSelectedActivity() async {
    if (_selectedActivityId == null) {
      return;
    }

    final provider = Provider.of<ActivityProvider>(context, listen: false);
    final activity = provider.getActivityById(_selectedActivityId!);
    if (activity == null) {
      setState(() => _selectedActivityId = null);
      return;
    }

    await _confirmActivityDelete(activity, provider);
  }

  Future<void> _confirmActivityDelete(
    Activity activity,
    ActivityProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelColor,
        title: Text(
          context.tr('Confirm Removal'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        content: Text(
          context.tr(
            'Are you sure you want to remove "{name}" from the ledger?',
            {'name': activity.name},
          ),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
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

    if (confirmed == true) {
      await provider.deleteActivity(activity.jobId);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedActivityId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Job removed from ledger'))),
      );
    }
  }

  void _showEditDialog(Activity activity) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelColor,
        title: Text(
          context.tr('Edit Job Record'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        content: Text(
          context.tr('Open this job order for editing?'),
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('CANCEL'),
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FrmAddJob2(editJobId: activity.jobId),
                ),
              );
            },
            child: Text(
              context.tr('OPEN'),
              style: TextStyle(color: _selectedColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCurrencyTrimmed(NumberFormat format, double value) {
  final formatted = format.format(value);
  final dotIndex = formatted.lastIndexOf('.');
  if (dotIndex == -1) return formatted;
  final integerPart = formatted.substring(0, dotIndex);
  final decimalPart = formatted.substring(dotIndex + 1);
  if (RegExp(r'^0+$').hasMatch(decimalPart)) return integerPart;
  final trimmedDecimal = decimalPart.replaceFirst(RegExp(r'0+$'), '');
  return '$integerPart.$trimmedDecimal';
}
