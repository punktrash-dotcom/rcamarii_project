import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/data_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/search_provider.dart';
import '../providers/voice_command_provider.dart';
import '../services/app_localization_service.dart';
import '../themes/app_visuals.dart';
import 'scr_msoft.dart';
import 'scr_weather.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 360),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: _tabs[_selectedIndex],
              ),
            ),
          ),
          _buildBottomDock(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final voiceProvider =
        Provider.of<VoiceCommandProvider>(context, listen: false);
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final sections = [
      (context.tr('Estate'), context.tr('Farm')),
      (context.tr('Ledger'), context.tr('Activities')),
      (context.tr('Assets'), context.tr('Supplies')),
      (context.tr('Library'), context.tr('Knowledge')),
    ];
    final section = sections[_selectedIndex];

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: FrostedPanel(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.$1.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          section.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderButton(
                        icon: Icons.grid_view_rounded,
                        tooltip: context.tr('Main Hub'),
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const ScrMSoft()),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _HeaderButton(
                        icon: Icons.search_rounded,
                        tooltip: context.tr('Search current database'),
                        onTap: () {
                          setState(() => _showSearch = !_showSearch);
                          if (_showSearch) _searchFocusNode.requestFocus();
                        },
                      ),
                      const SizedBox(width: 4),
                      _HeaderButton(
                        icon: Icons.cloud_queue_rounded,
                        tooltip: context.tr('Weather forecast'),
                        onTap: _openWeatherForecast,
                      ),
                      if (appSettings.voiceAssistantEnabled) ...[
                        const SizedBox(width: 4),
                        _HeaderButton(
                          icon: Icons.mic_rounded,
                          tooltip: context.tr('Voice command'),
                          onTap: () => voiceProvider.requestCommand(context),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (_showSearch) ...[
                const SizedBox(height: 12),
                _buildSearchAutocomplete(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAutocomplete(ThemeData theme) {
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
        return TextField(
          stylusHandwritingEnabled: false,
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: context.tr('Search this section'),
            isDense: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }

  void _openWeatherForecast() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScrWeather()),
    );
  }

  Widget _buildBottomDock(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: FrostedPanel(
        radius: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        child: Row(
          children: [
            Expanded(
              child: _NavButton(
                icon: Icons.eco_rounded,
                label: context.tr('Estate'),
                selected: _selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
            ),
            Expanded(
              child: _NavButton(
                icon: Icons.analytics_rounded,
                label: context.tr('Ledger'),
                selected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
            ),
            Expanded(
              child: _NavButton(
                icon: Icons.inventory_2_rounded,
                label: context.tr('Assets'),
                selected: _selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
            ),
            Expanded(
              child: _NavButton(
                icon: Icons.auto_stories_rounded,
                label: context.tr('Library'),
                selected: _selectedIndex == 3,
                onTap: () => _onItemTapped(3),
              ),
            ),
          ],
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
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.42),
            ),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
