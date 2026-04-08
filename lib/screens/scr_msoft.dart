import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/farm_model.dart';
import '../models/schedule_alert_model.dart';
import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/weather_provider.dart';
import '../services/app_localization_service.dart';
import '../services/farm_alert_service.dart';
import '../services/farm_operations_service.dart';
import '../services/farming_advice_service.dart';
import '../services/guideline_localization_service.dart';
import '../themes/app_visuals.dart';
import 'exit_screen.dart';
import 'farm_report_dashboard_screen.dart';
import 'frm_main.dart';
import 'help_screen.dart';
import 'profit_calculator_screen.dart';
import 'scr_tracker.dart';
import 'scr_workers.dart';
import 'settings_screen.dart';

const String _kOfficialLogoAsset = 'lib/assets/images/logo2.png';

class ScrMSoft extends StatefulWidget {
  const ScrMSoft({super.key});

  @override
  State<ScrMSoft> createState() => _ScrMSoftState();
}

class _ScrMSoftState extends State<ScrMSoft> with WidgetsBindingObserver {
  FarmAlertCardData? _alarmCardData;
  bool _isAlarmCardVisible = false;
  bool _hasAlarmIndicator = false;

  bool get _showInteractionDetails =>
      Provider.of<AppSettingsProvider>(context, listen: false)
          .showDetailedDescriptions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrapProviders();
      await _loadAlarmState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadAlarmState());
    }
  }

  Future<void> _bootstrapProviders() async {
    final farm = Provider.of<FarmProvider>(context, listen: false);
    final activity = Provider.of<ActivityProvider>(context, listen: false);
    final equipment = Provider.of<EquipmentProvider>(context, listen: false);
    final supplies = Provider.of<SuppliesProvider>(context, listen: false);
    final deliveries = Provider.of<DeliveryProvider>(context, listen: false);
    final weather = Provider.of<WeatherProvider>(context, listen: false);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);

    await Future.wait([
      farm.refreshFarms(),
      activity.loadActivities(),
      equipment.loadEquipment(),
      supplies.loadSupplies(),
      deliveries.loadDeliveries(),
    ]);

    final selectedFarm =
        farm.selectedFarm ?? (farm.farms.isNotEmpty ? farm.farms.first : null);
    final location = selectedFarm != null
        ? '${selectedFarm.city}, ${selectedFarm.province}'
        : 'Metro Manila';
    if (appSettings.weatherAutoRefresh) {
      await weather.getWeather(location);
    }
  }

  Future<void> _loadAlarmState({bool consumePending = true}) async {
    await FarmAlertService.instance.initialize();
    final pending = consumePending
        ? await FarmAlertService.instance.consumePendingAlarmCard()
        : null;
    final latest = pending ?? await FarmAlertService.instance.latestAlarmCard();
    if (!mounted) {
      return;
    }
    setState(() {
      _alarmCardData = latest;
      _hasAlarmIndicator = latest != null;
      if (pending != null) {
        _isAlarmCardVisible = true;
      }
    });
  }

  Future<void> _openAlarmCard() async {
    if (_alarmCardData == null) {
      await _loadAlarmState(consumePending: false);
    }
    if (!mounted) {
      return;
    }
    if (_alarmCardData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No farm alarm is available right now.')),
      );
      return;
    }
    setState(() {
      _isAlarmCardVisible = true;
      _hasAlarmIndicator = false;
    });
    await FarmAlertService.instance.clearPendingAlarmCard();
  }

  Future<void> _muteAlarmToday() async {
    await FarmAlertService.instance.muteAlertsForToday();
    if (!mounted) {
      return;
    }
    setState(() {
      _isAlarmCardVisible = false;
      _hasAlarmIndicator = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Farm alarms won't remind you again today."),
      ),
    );
  }

  void _dismissAlarmCard() {
    setState(() {
      _isAlarmCardVisible = false;
      _hasAlarmIndicator = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final farmProvider = Provider.of<FarmProvider>(context);
    final activityProvider = Provider.of<ActivityProvider>(context);
    final suppliesProvider = Provider.of<SuppliesProvider>(context);
    final deliveryProvider = Provider.of<DeliveryProvider>(context);
    final language =
        Provider.of<GuidelineLanguageProvider>(context).selectedLanguage;

    final selectedFarm = farmProvider.selectedFarm;
    final cropAge = selectedFarm == null
        ? null
        : DateTime.now().difference(selectedFarm.date).inDays.clamp(0, 9999);
    final contextualAlerts = _buildContextualAlerts(
      selectedFarm,
      cropAge,
      language,
    );
    final harvestTimelines =
        farmProvider.farms.map(_HarvestTimelineEntry.fromFarm).toList()
          ..sort(
            (left, right) => left.daysToHarvest.compareTo(right.daysToHarvest),
          );
    final bottomInset = mediaQuery.viewInsets.bottom;
    final isDarkMode = Provider.of<ThemeProvider>(context).darkTheme;

    return Scaffold(
      body: AppBackdrop(
        isDark: isDarkMode,
        backgroundImageAsset: 'lib/assets/images/background.png',
        backgroundImageOpacity: isDarkMode ? 0.24 : 0.38,
        imageScrimColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.2)
            : AppVisuals.softWhite.withValues(alpha: 0.08),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(theme),
                if (_isAlarmCardVisible && _alarmCardData != null) ...[
                  const SizedBox(height: 18),
                  _buildAlarmCard(theme),
                ],
                const SizedBox(height: 24),
                _buildActionDeck(theme),
                const SizedBox(height: 24),
                _buildHubOverview(
                  theme: theme,
                  selectedFarm: selectedFarm,
                  cropAge: cropAge,
                  activityProvider: activityProvider,
                  suppliesProvider: suppliesProvider,
                  deliveryProvider: deliveryProvider,
                ),
                const SizedBox(height: 24),
                _buildOperationalAlerts(
                  theme: theme,
                  selectedFarm: selectedFarm,
                  cropAge: cropAge,
                  alerts: contextualAlerts,
                ),
                const SizedBox(height: 24),
                _buildHarvestTargets(
                  theme: theme,
                  timelines: harvestTimelines,
                ),
                const SizedBox(height: 24),
                _buildTodayBoard(
                  theme: theme,
                  activityProvider: activityProvider,
                ),
                const SizedBox(height: 32),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _openExitScreen(context),
                    icon:
                        const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: Text(context.tr('Exit RCAMARii')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final welcomeName =
        appSettings.userName.isEmpty ? 'Ramari' : appSettings.userName;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppVisuals.primaryGold.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: AppVisuals.primaryGold.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                _kOfficialLogoAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: AppVisuals.primaryGold.withValues(alpha: 0.2),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.eco_rounded,
                    color: AppVisuals.deepGreen,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RCAMARii',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppVisuals.primaryGold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome, $welcomeName',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppVisuals.textForestMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.help_outline_rounded,
            onTap: () => _openHelp(context),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _HeaderIconButton(
                icon: Icons.notifications_active_outlined,
                onTap: _openAlarmCard,
              ),
              if (_hasAlarmIndicator)
                Positioned(
                  right: 0,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppVisuals.softWhite,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.person_outline_rounded,
            onTap: () => _openSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(ThemeData theme) {
    final alarm = _alarmCardData!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppVisuals.cloudGlass.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppVisuals.primaryGold.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppVisuals.primaryGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppVisuals.primaryGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Farm Alarm',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppVisuals.primaryGold,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alarm.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppVisuals.textForest,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alarm.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.45,
            ),
          ),
          if (alarm.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...alarm.items.take(3).map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppVisuals.panelSoft.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.farmName} - ${item.title}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppVisuals.textForest,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppVisuals.textForestMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: _dismissAlarmCard,
                child: const Text('Dismiss'),
              ),
              FilledButton.tonal(
                onPressed: _muteAlarmToday,
                child: const Text("Don't remind me today."),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionDeck(ThemeData theme) {
    final showDetails = _showInteractionDetails;
    final actions = [
      _ActionItem(
        title: context.tr('Estate'),
        subtitle: context.tr('Open farms'),
        colors: const [
          AppVisuals.brandWhite,
          AppVisuals.fieldMist,
          AppVisuals.skyMist,
        ],
        accentColor: AppVisuals.brandRed,
        onTap: () => _openFrmMain(context),
      ),
      _ActionItem(
        title: context.tr('Finance'),
        subtitle: context.tr('Tracker'),
        colors: const [
          AppVisuals.brandWhite,
          Color(0xFFF0F8F8),
          Color(0xFFDDECEE),
        ],
        accentColor: AppVisuals.brandBlue,
        onTap: () => _openFtracker(context),
      ),
      _ActionItem(
        title: context.tr('Profit Tools'),
        subtitle: 'Final or Trial',
        colors: const [
          AppVisuals.brandWhite,
          Color(0xFFFAF9EC),
          Color(0xFFF4E7B3),
        ],
        accentColor: AppVisuals.lightGold,
        onTap: () => _openProfitEstimator(context),
      ),
      _ActionItem(
        title: context.tr('Reports'),
        subtitle: context.tr('Dashboard'),
        colors: const [
          AppVisuals.brandWhite,
          Color(0xFFF1F8F2),
          Color(0xFFE1F0DE),
        ],
        accentColor: AppVisuals.brandGreen,
        onTap: () => _openReports(context),
      ),
      _ActionItem(
        title: context.tr('Employees'),
        subtitle: context.tr('Crew panel'),
        colors: const [
          AppVisuals.brandWhite,
          Color(0xFFF8FAED),
          Color(0xFFE8F2D9),
        ],
        accentColor: AppVisuals.brandGreen,
        onTap: () => _openWorkers(context),
      ),
    ];

    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Action Deck'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppVisuals.primaryGold,
                      ),
                    ),
                    if (showDetails) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          'Fast routes into the farm workspace, tuned for daily operations.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppVisuals.textForestMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppVisuals.brandBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppVisuals.brandBlue.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  '${actions.length} routes',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth < 220 ? 1 : 2;
              final rows = <Widget>[];

              for (var start = 0;
                  start < actions.length;
                  start += columnCount) {
                final rowChildren = <Widget>[];

                for (var offset = 0; offset < columnCount; offset++) {
                  final index = start + offset;
                  rowChildren.add(
                    Expanded(
                      child: index < actions.length
                          ? actions[index]
                          : const SizedBox.shrink(),
                    ),
                  );

                  if (offset < columnCount - 1) {
                    rowChildren.add(const SizedBox(width: 16));
                  }
                }

                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rowChildren,
                  ),
                );

                if (start + columnCount < actions.length) {
                  rows.add(const SizedBox(height: 16));
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: rows,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHubOverview({
    required ThemeData theme,
    required Farm? selectedFarm,
    required int? cropAge,
    required ActivityProvider activityProvider,
    required SuppliesProvider suppliesProvider,
    required DeliveryProvider deliveryProvider,
  }) {
    final showDetails = _showInteractionDetails;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentActivityCount = activityProvider.activities
        .where((activity) => !activity.date.isBefore(sevenDaysAgo))
        .length;

    final fieldSummary = selectedFarm == null
        ? context.tr('Choose a farm to unlock crop-stage guidance.')
        : context.tr(
            '{farm} is {days} days from planting.',
            {
              'farm': selectedFarm.name,
              'days': '${cropAge ?? 0}',
            },
          );

    final cards = [
      (
        title: context.tr('Field focus'),
        body: fieldSummary,
        icon: Icons.landscape_rounded,
      ),
      (
        title: context.tr('Activity pulse'),
        body: context.tr(
          '{count} activity records were logged in the last 7 days.',
          {'count': '$recentActivityCount'},
        ),
        icon: Icons.analytics_rounded,
      ),
      (
        title: context.tr('Inventory posture'),
        body: context.tr(
          '{count} supply entries are available for review.',
          {'count': '${suppliesProvider.items.length}'},
        ),
        icon: Icons.inventory_2_rounded,
      ),
      (
        title: context.tr('Delivery posture'),
        body: context.tr(
          '{count} deliveries are recorded across the app.',
          {'count': '${deliveryProvider.deliveries.length}'},
        ),
        icon: Icons.local_shipping_rounded,
      ),
    ];

    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Live Overview'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(
                'A fast operational summary driven by your existing farm records.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            ),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final tileWidth =
                  wide ? (constraints.maxWidth - 12) / 2 : double.infinity;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: tileWidth,
                        child: _buildOverviewCard(
                          theme: theme,
                          icon: card.icon,
                          title: card.title,
                          body: card.body,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppVisuals.textForest.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppVisuals.primaryGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppVisuals.primaryGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayBoard({
    required ThemeData theme,
    required ActivityProvider activityProvider,
  }) {
    return FrostedPanel(
      radius: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Recent Activity'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          const SizedBox(height: 20),
          if (activityProvider.activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  context.tr('No recent activity recorded.'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activityProvider.activities.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = activityProvider.activities[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppVisuals.panelSoft.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppVisuals.primaryGold.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: AppVisuals.primaryGold,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppVisuals.textForest,
                              ),
                            ),
                            Text(
                              activity.farm,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppVisuals.textForest
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('MMM d').format(activity.date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppVisuals.primaryGold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<ScheduleAlert> _buildContextualAlerts(
    Farm? selectedFarm,
    int? cropAge,
    GuidelineLanguage language,
  ) {
    if (selectedFarm == null || cropAge == null) {
      return [];
    }

    final alerts = [
      ...FarmingAdviceService.getAdviceForCrop(selectedFarm.type, cropAge),
      ...FarmOperationsService.inputAlertsForCrop(selectedFarm.type, cropAge),
    ].map((alert) {
      return GuidelineLocalizationService.translateAlert(alert, language);
    }).toList();

    final deduped = <ScheduleAlert>[];
    for (final alert in alerts) {
      final exists = deduped.any(
        (entry) =>
            entry.title == alert.title &&
            entry.startDay == alert.startDay &&
            entry.endDay == alert.endDay,
      );
      if (!exists) {
        deduped.add(alert);
      }
    }

    deduped.sort(
      (left, right) => _alertDistance(left, cropAge)
          .compareTo(_alertDistance(right, cropAge)),
    );
    return deduped.take(4).toList();
  }

  int _alertDistance(ScheduleAlert alert, int cropAge) {
    if (cropAge >= alert.startDay && cropAge <= alert.endDay) {
      return 0;
    }
    if (cropAge < alert.startDay) {
      return alert.startDay - cropAge;
    }
    return cropAge - alert.endDay + 45;
  }

  Widget _buildOperationalAlerts({
    required ThemeData theme,
    required Farm? selectedFarm,
    required int? cropAge,
    required List<ScheduleAlert> alerts,
  }) {
    final showDetails = _showInteractionDetails;
    return FrostedPanel(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crop Action Alerts',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              selectedFarm == null
                  ? 'Select a farm to surface fertilizer, herbicide, pesticide, foliar, and harvest-prep timing.'
                  : 'Stage-based windows for ${selectedFarm.name}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 12),
          if (alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppVisuals.panelSoft.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                'No immediate crop-age action window is active yet.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HubAlertTile(
                  theme: theme,
                  alert: alert,
                  cropAge: cropAge,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHarvestTargets({
    required ThemeData theme,
    required List<_HarvestTimelineEntry> timelines,
  }) {
    final showDetails = _showInteractionDetails;
    return FrostedPanel(
      radius: 40,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Harvest Board',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppVisuals.primaryGold,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              'Quick view of expected harvest timing for each crop and field.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 12),
          if (timelines.isEmpty)
            Text(
              'No farms available yet.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timelines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final timeline = timelines[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppVisuals.panelSoft.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppVisuals.brandGreen.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              timeline.farm.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppVisuals.textForest,
                              ),
                            ),
                          ),
                          Text(
                            timeline.daysToHarvest >= 0
                                ? '${timeline.daysToHarvest} d'
                                : 'Harvest due',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppVisuals.primaryGold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${timeline.farm.type}  |  ${timeline.stage}  |  ${timeline.farm.area.toStringAsFixed(1)} ha',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppVisuals.textForestMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: timeline.progress.clamp(0.0, 1.0),
                          minHeight: 8,
                          color: AppVisuals.brandGreen,
                          backgroundColor:
                              AppVisuals.brandGreen.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Age ${timeline.ageInDays} days',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppVisuals.textForestMuted,
                            ),
                          ),
                          Text(
                            'Target ${DateFormat('MMM d, y').format(timeline.targetHarvest)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppVisuals.textForestMuted,
                            ),
                          ),
                          Text(
                            'Yield ${timeline.projectedYield.toStringAsFixed(1)} t',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppVisuals.textForestMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openHelp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpScreen()),
    );
  }

  void _openFrmMain(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FrmMain()));
  }

  void _openWorkers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScrWorkers()),
    );
  }

  void _openFtracker(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScrTracker()),
    );
  }

  void _openProfitEstimator(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfitCalculatorScreen()),
    );
  }

  void _openReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FarmReportDashboardScreen()),
    );
  }

  void _openExitScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ExitScreen()),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppVisuals.lightGold.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppVisuals.lightGold.withValues(alpha: 0.45),
          ),
        ),
        child: Icon(icon, size: 20, color: AppVisuals.lightGold),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final translucentColors =
        colors.map((color) => color.withValues(alpha: 0.68)).toList();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: translucentColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.14),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppVisuals.textForestMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _HubAlertTile extends StatelessWidget {
  const _HubAlertTile({
    required this.theme,
    required this.alert,
    required this.cropAge,
  });

  final ThemeData theme;
  final ScheduleAlert alert;
  final int? cropAge;

  @override
  Widget build(BuildContext context) {
    final age = cropAge ?? -1;
    final isActive = age >= alert.startDay && age <= alert.endDay;
    final ahead = alert.startDay - age;
    final status = isActive
        ? 'Now'
        : ahead > 0
            ? 'In $ahead d'
            : 'Review';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: alert.color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: alert.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(alert.icon, color: alert.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppVisuals.textForest,
                        ),
                      ),
                    ),
                    Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: alert.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HarvestTimelineEntry {
  const _HarvestTimelineEntry({
    required this.farm,
    required this.ageInDays,
    required this.stage,
    required this.targetHarvest,
    required this.projectedYield,
    required this.progress,
    required this.daysToHarvest,
  });

  final Farm farm;
  final int ageInDays;
  final String stage;
  final DateTime targetHarvest;
  final double projectedYield;
  final double progress;
  final int daysToHarvest;

  factory _HarvestTimelineEntry.fromFarm(Farm farm) {
    final ageInDays = FarmOperationsService.cropAgeInDays(farm.date);
    return _HarvestTimelineEntry(
      farm: farm,
      ageInDays: ageInDays,
      stage: FarmOperationsService.growthStage(farm.type, ageInDays),
      targetHarvest: FarmOperationsService.expectedHarvestDate(farm),
      projectedYield: FarmOperationsService.projectedYieldTons(farm),
      progress: FarmOperationsService.harvestProgress(farm.type, ageInDays),
      daysToHarvest: FarmOperationsService.daysUntilHarvest(farm),
    );
  }
}
