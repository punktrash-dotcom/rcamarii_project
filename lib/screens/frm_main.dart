import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/farm_income_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/ftracker_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/search_provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/voice_command_provider.dart';
import '../providers/worker_provider.dart';
import '../providers/sugarcane_profit_provider.dart';
import '../providers/theme_provider.dart';
import '../services/app_localization_service.dart';
import '../themes/app_visuals.dart';
import 'add_farm_screen.dart';
import 'frm_add_delivery.dart';
import 'frm_add_job2.dart';
import 'frm_logistics.dart';
import 'frm_add_sup_screen.dart';
import 'scr_msoft.dart';
import 'tab_activities.dart';
import 'tab_farm.dart';
import 'tab_knowledge.dart';
import 'tab_supplies.dart';

class FrmMain extends StatefulWidget {
  final int initialTab;

  const FrmMain({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<FrmMain> createState() => _FrmMainState();
}

class _FrmMainState extends State<FrmMain> {
  int _selectedIndex = 0;
  bool _showSearch = false;
  final TextEditingController _searchAutocompleteController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  int get addJ => _selectedIndex;

  final List<Widget> _tabs = const [
    TabFarm(),
    TabActivities(),
    TabSupplies(),
    TabKnowledge(),
    FrmLogistics(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab.clamp(0, _tabs.length - 1);

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _showSearch = false;
            _searchAutocompleteController.clear();
          });
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      if (navigationProvider.currentIndex != _selectedIndex) {
        navigationProvider.changeTab(_selectedIndex);
      }
    });
  }

  @override
  void dispose() {
    _searchAutocompleteController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    Provider.of<NavigationProvider>(context, listen: false).changeTab(index);
    setState(() => _selectedIndex = index);
  }

  Future<void> _refreshAll() async {
    final farm = Provider.of<FarmProvider>(context, listen: false);
    final activity = Provider.of<ActivityProvider>(context, listen: false);
    final equipment = Provider.of<EquipmentProvider>(context, listen: false);
    final supplies = Provider.of<SuppliesProvider>(context, listen: false);
    final deliveries = Provider.of<DeliveryProvider>(context, listen: false);
    final workers = Provider.of<WorkerProvider>(context, listen: false);
    final farmIncome = Provider.of<FarmIncomeProvider>(context, listen: false);
    final profits =
        Provider.of<SugarcaneProfitProvider>(context, listen: false);
    final ftracker = Provider.of<FtrackerProvider>(context, listen: false);
    final data = Provider.of<DataProvider>(context, listen: false);

    await Future.wait([
      farm.refreshFarms(),
      activity.loadActivities(),
      equipment.loadEquipment(),
      supplies.loadSupplies(),
      deliveries.loadDeliveries(),
      workers.loadWorkers(),
      farmIncome.loadRecords(),
      profits.loadProfitRecords(),
      ftracker.loadFtrackerRecords(),
      data.loadDefSupsFromDb(),
    ]);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Database refreshed')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).darkTheme;
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final reduceMotion = appSettings.reducedMotion;

    if (navigationProvider.currentIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedIndex = navigationProvider.currentIndex);
      });
    }

    return Scaffold(
      extendBody: true,
      appBar: _buildTopAppBar(theme),
      floatingActionButton: _buildFab(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(theme),
      body: AppBackdrop(
        isDark: isDarkMode,
        child: Column(
          children: [
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: _buildSearchAutocomplete(theme),
              ),
            Expanded(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox.expand(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedIndex),
                        child: _tabs[_selectedIndex],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(ThemeData theme) {
    final scheme = theme.colorScheme;
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final sections = [
      (context.tr('Estate'), context.tr('Farm Hub')),
      (context.tr('Ledger'), context.tr('Operations')),
      (context.tr('Assets'), context.tr('Inventory')),
      (context.tr('Knowledge'), context.tr('Library')),
      (context.tr('Logistics'), context.tr('Deliveries')),
    ];
    final section = sections[_selectedIndex];

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 72,
      backgroundColor: scheme.primary,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 20,
      title: _buildHeaderSection(theme, scheme, section),
      actions: [
        PopupMenuButton<_FrmMainOverflowAction>(
          tooltip: context.tr('More'),
          icon: Icon(
            Icons.more_vert_rounded,
            color: scheme.onPrimary,
          ),
          onSelected: _handleOverflowAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _FrmMainOverflowAction.refresh,
              child: Text(context.tr('Refresh')),
            ),
            if (appSettings.voiceAssistantEnabled)
              PopupMenuItem(
                value: _FrmMainOverflowAction.voice,
                child: Text(context.tr('Voice')),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TopTabButton(
                  icon: Icons.eco_rounded,
                  tooltip: context.tr('Estate'),
                  selected: _selectedIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _TopTabButton(
                  icon: Icons.analytics_rounded,
                  tooltip: context.tr('Activities'),
                  selected: _selectedIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                _TopTabButton(
                  icon: Icons.inventory_2_rounded,
                  tooltip: context.tr('Supplies'),
                  selected: _selectedIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
                _TopTabButton(
                  icon: Icons.auto_stories_rounded,
                  tooltip: context.tr('Knowledge'),
                  selected: _selectedIndex == 3,
                  onTap: () => _onItemTapped(3),
                ),
                _TopTabButton(
                  icon: Icons.local_shipping_rounded,
                  tooltip: context.tr('Deliveries'),
                  selected: _selectedIndex == 4,
                  onTap: () => _onItemTapped(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(
    ThemeData theme,
    ColorScheme scheme,
    (String, String) section,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.$1.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w900,
            color: scheme.tertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          section.$2,
          style: theme.textTheme.displaySmall?.copyWith(
            color: scheme.onPrimary,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAutocomplete(ThemeData theme) {
    final scheme = theme.colorScheme;
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    final activityProvider =
        Provider.of<ActivityProvider>(context, listen: false);
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        List<String> options = [];
        if (addJ == 0) {
          options = farmProvider.farms.map((f) => f.name).toSet().toList();
          options
              .addAll(farmProvider.farms.map((f) => f.type).toSet().toList());
        } else if (addJ == 1) {
          options =
              activityProvider.activities.map((a) => a.worker).toSet().toList();
          options.addAll(
              activityProvider.activities.map((a) => a.name).toSet().toList());
          options.addAll(
              dataProvider.workDefs.map((w) => w.name).toSet().toList());
        } else if (addJ == 2) {
          options = dataProvider.defSups.map((s) => s.name).toSet().toList();
          options
              .addAll(dataProvider.defSups.map((s) => s.type).toSet().toList());
          options.addAll(
            dataProvider.equipmentDefs.map((e) => e['Name'] as String).toSet(),
          );
        }

        return options.where(
          (option) => option.toLowerCase().contains(value.text.toLowerCase()),
        );
      },
      onSelected: (selection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          searchProvider.executeSearch(selection);
          setState(() {
            _showSearch = false;
            _searchAutocompleteController.clear();
          });
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.tertiary.withValues(alpha: 0.75),
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: context.tr('Search in this section...'),
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: scheme.primary,
                size: 20,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFab(ThemeData theme) {
    final scheme = theme.colorScheme;
    return FloatingActionButton(
      onPressed: _handleAddAction,
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      elevation: 4,
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }

  Widget _buildBottomAppBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: BottomAppBar(
        height: 76,
        notchMargin: 8,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        color: AppVisuals.surfaceInset.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            IconButton(
              tooltip: context.tr('More actions'),
              onPressed: _openBottomDrawer,
              icon: Icon(
                Icons.menu_rounded,
                color: AppVisuals.softWhite.withValues(alpha: 0.92),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: context.tr('Search'),
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (_showSearch) {
                  _searchFocusNode.requestFocus();
                }
              },
              icon: Icon(
                _showSearch ? Icons.close_rounded : Icons.search_rounded,
                color: AppVisuals.softWhite.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddAction() async {
    switch (_selectedIndex) {
      case 0:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddFarmScreen()),
        );
        break;
      case 1:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FrmAddJob2()),
        );
        break;
      case 2:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FrmAddSupScreen()),
        );
        break;
      case 3:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('No add action is available in the knowledge tab.'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 4:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FrmAddDelivery()),
        );
        break;
    }
  }

  Future<void> _openBottomDrawer() async {
    final selectedFarm =
        Provider.of<FarmProvider>(context, listen: false).selectedFarm;
    final sheetContext = context;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.96,
              ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.tips_and_updates_rounded),
                  title: Text(
                    context.tr('Recommendations and Tips'),
                  ),
                  subtitle: Text(
                    selectedFarm == null
                        ? context.tr('Open the knowledge tab')
                        : selectedFarm.name,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _onItemTapped(3);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.save_rounded),
                  title: Text(context.tr('Save changes')),
                  onTap: () {
                    Navigator.pop(context);
                    _saveChanges();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.undo_rounded),
                  title: Text(context.tr('Undo changes')),
                  onTap: () {
                    Navigator.pop(context);
                    _undoChanges();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app_rounded),
                  title: Text(context.tr('Exit main tab form')),
                  onTap: () {
                    Navigator.pop(context);
                    _exitToScrMsoft(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('Changes are saved from each form as you submit them.'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _undoChanges() async {
    setState(() {
      _showSearch = false;
      _searchAutocompleteController.clear();
    });
    await _refreshAll();
  }

  void _exitToScrMsoft(BuildContext parentContext) {
    if (Navigator.of(parentContext).canPop()) {
      Navigator.of(parentContext).pop();
      return;
    }

    Navigator.pushReplacement(
      parentContext,
      MaterialPageRoute(builder: (_) => const ScrMSoft()),
    );
  }

  void _handleOverflowAction(_FrmMainOverflowAction action) {
    switch (action) {
      case _FrmMainOverflowAction.refresh:
        _refreshAll();
        break;
      case _FrmMainOverflowAction.voice:
        Provider.of<VoiceCommandProvider>(context, listen: false)
            .requestCommand(context);
        break;
    }
  }
}

enum _FrmMainOverflowAction { refresh, voice }

class _TopTabButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _TopTabButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppVisuals.softWhite.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppVisuals.softWhite.withValues(alpha: 0.42)
                    : AppVisuals.softWhite.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: selected
                  ? AppVisuals.softWhite
                  : AppVisuals.softWhite.withValues(alpha: 0.78),
            ),
          ),
        ),
      ),
    );
  }
}
