import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/equipment_provider.dart';
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
import '../utils/app_layout_utils.dart';
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
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;

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
      body: AppBackdrop(
        isDark: isDarkMode,
        child: Column(
          children: [
            _buildHeader(theme),
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
                    child: KeyedSubtree(
                      key: ValueKey<int>(_selectedIndex),
                      child: _tabs[_selectedIndex],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomDock(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final scheme = theme.colorScheme;
    final voiceProvider =
        Provider.of<VoiceCommandProvider>(context, listen: false);
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final sections = [
      (context.tr('Estate'), context.tr('Farm Hub')),
      (context.tr('Ledger'), context.tr('Operations')),
      (context.tr('Assets'), context.tr('Inventory')),
      (context.tr('Library'), context.tr('Knowledge')),
    ];
    final section = sections[_selectedIndex];

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shouldStack = AppLayoutUtils.shouldStackHeader(
                  context,
                  widthBreakpoint: 560,
                  scaleBreakpoint: 1.08,
                ) ||
                constraints.maxWidth < 520;
            final actions = <Widget>[
              _HeaderButton(
                icon: Icons.grid_view_rounded,
                tooltip: context.tr('Main Hub'),
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ScrMSoft()),
                ),
              ),
              _HeaderButton(
                icon: Icons.search_rounded,
                tooltip: context.tr('Search'),
                onTap: () {
                  setState(() => _showSearch = !_showSearch);
                  if (_showSearch) _searchFocusNode.requestFocus();
                },
              ),
              _HeaderButton(
                icon: Icons.refresh_rounded,
                tooltip: context.tr('Refresh'),
                onTap: _refreshAll,
              ),
              if (appSettings.voiceAssistantEnabled)
                _HeaderButton(
                  icon: Icons.mic_rounded,
                  tooltip: context.tr('Voice'),
                  onTap: () => voiceProvider.requestCommand(context),
                ),
            ];

            return Column(
              children: [
                if (shouldStack)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(theme, scheme, section),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderSection(theme, scheme, section),
                      ),
                      Flexible(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: actions,
                        ),
                      ),
                    ],
                  ),
                if (_showSearch) ...[
                  const SizedBox(height: 16),
                  _buildSearchAutocomplete(theme),
                ],
              ],
            );
          },
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
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          section.$2,
          style: theme.textTheme.displaySmall?.copyWith(
            color: scheme.onSurface,
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
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.4),
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

  Widget _buildBottomDock(ThemeData theme) {
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.09),
              blurRadius: 22,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _NavButton(
                icon: Icons.eco_rounded,
                label: context.tr('Estate'),
                selected: _selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              _NavButton(
                icon: Icons.analytics_rounded,
                label: context.tr('Ledger'),
                selected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              _NavButton(
                icon: Icons.inventory_2_rounded,
                label: context.tr('Assets'),
                selected: _selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
              _NavButton(
                icon: Icons.auto_stories_rounded,
                label: context.tr('Library'),
                selected: _selectedIndex == 3,
                onTap: () => _onItemTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: scheme.primary, size: 22),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuint,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              if (selected) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimary,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
