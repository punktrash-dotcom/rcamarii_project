import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/equipment_tab.dart';
import '../components/supplies_tab.dart';
import '../data/schedules.dart';
import '../models/farm_model.dart';
import '../models/schedule_alert_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../services/app_localization_service.dart';
import '../services/app_route_observer.dart';
import 'market_price_list_screen.dart';
import '../services/farming_advice_service.dart';
import '../services/guideline_localization_service.dart';
import '../widgets/modern_screen_shell.dart';

class TabSupplies extends StatefulWidget {
  const TabSupplies({super.key});

  @override
  State<TabSupplies> createState() => _TabSuppliesState();
}

class _TabSuppliesState extends State<TabSupplies>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  final _suppliesTabController = SuppliesTabController();
  final GlobalKey _tabContentKey = GlobalKey();
  AppAudioProvider? _appAudio;
  AudioSoundStyle _screenAudioStyle = AudioSoundStyle.serious;
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;

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
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopScreenOpenAudioIfNeeded());
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernScreenShell(
      title: context.tr('Supply Intelligence'),
      subtitle: '',
      titleStyleOverride: const TextStyle(color: Colors.white),
      subtitleStyleOverride: const TextStyle(color: Colors.white),
      actionBadge: _buildDatabaseAction(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabContentHeight =
              (constraints.maxHeight * 0.78).clamp(520.0, 860.0).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildTabSwitcher(),
                    const SizedBox(height: 14),
                    SizedBox(
                      key: _tabContentKey,
                      height: tabContentHeight,
                      child: _buildTabContent(),
                    ),
                    const SizedBox(height: 20),
                    _buildMetricsLayer(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  GuidelineLanguage get _selectedLanguage =>
      context.watch<GuidelineLanguageProvider>().selectedLanguage;

  Future<void> _playScreenOpenAudioIfNeeded() async {
    if (!mounted || _playedScreenOpenAudio) {
      return;
    }
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: false);
    _appAudio ??= context.read<AppAudioProvider>();
    _screenAudioStyle = appSettings.audioSoundStyle;
    _playedScreenOpenAudio = true;
    await _appAudio!.playScreenOpenSound(
          screenKey: 'tab_supplies',
          style: _screenAudioStyle,
          enabled: appSettings.audioSoundsEnabled,
        );
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appAudio = _appAudio;
    if (appAudio == null) {
      return;
    }
    await appAudio.stopScreenOpenSound(
          screenKey: 'tab_supplies',
          style: _screenAudioStyle,
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appAudio ??= context.read<AppAudioProvider>();
    _screenAudioStyle =
        Provider.of<AppSettingsProvider>(context, listen: false)
            .audioSoundStyle;
    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
  }

  @override
  void didPushNext() {
    unawaited(_stopScreenOpenAudioIfNeeded());
  }

  @override
  void didPop() {
    unawaited(_stopScreenOpenAudioIfNeeded());
  }

  void _openDatabaseCatalog() {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    _suppliesTabController.showDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabContext = _tabContentKey.currentContext;
      if (tabContext != null) {
        Scrollable.ensureVisible(
          tabContext,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      }
    });
  }

  void _openLatestPriceList({
    MarketPriceCategoryFilter initialFilter = MarketPriceCategoryFilter.all,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketPriceListScreen(initialFilter: initialFilter),
      ),
    );
  }

  Widget _buildDatabaseAction(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _openDatabaseCatalog,
      icon: const Icon(Icons.storage_rounded, size: 16),
      label: Text(_ui('database')),
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  String _ui(String key) =>
      GuidelineLocalizationService.ui(_selectedLanguage, key);

  String _localizedCropLabel(String cropType) =>
      GuidelineLocalizationService.cropLabel(cropType, _selectedLanguage);

  String _localizedCategoryLabel(String category) =>
      GuidelineLocalizationService.categoryLabel(category, _selectedLanguage);

  ScheduleAlert _localizedAlert(ScheduleAlert alert) =>
      GuidelineLocalizationService.translateAlert(alert, _selectedLanguage);

  Widget _buildMetricsLayer() {
    final scheme = Theme.of(context).colorScheme;
    final selectedFarm = Provider.of<FarmProvider>(context).selectedFarm;
    final farmAgeInDays = _farmAgeInDays(selectedFarm);
    final cropType =
        selectedFarm != null ? _normalizeCropType(selectedFarm.type) : null;
    final schedule =
        cropType != null ? _scheduleForCrop(cropType) : const <ScheduleAlert>[];
    final activeAdvice = cropType != null && farmAgeInDays != null
        ? FarmingAdviceService.getAdviceForCrop(cropType, farmAgeInDays)
        : const <ScheduleAlert>[];
    final currentStage =
        farmAgeInDays != null ? _currentStage(schedule, farmAgeInDays) : null;
    final nextStage =
        farmAgeInDays != null ? _nextStage(schedule, farmAgeInDays) : null;
    final buyingGuides = selectedFarm != null && farmAgeInDays != null
        ? _purchaseGuidesForFarm(
            cropType: cropType!,
            ageInDays: farmAgeInDays,
            schedule: schedule,
            activeAdvice: activeAdvice,
            language: _selectedLanguage,
          )
        : const <_PurchaseGuide>[];
    final highlightedCategory =
        buyingGuides.isNotEmpty ? buyingGuides.first.category : 'Price List';

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 24;
        const baseWidth = 340.0;
        final columnCount =
            ((availableWidth / baseWidth).floor()).clamp(1, 3).toInt();
        const spacing = 12.0;
        final cardWidth =
            (availableWidth - (columnCount - 1) * spacing) / columnCount;

        final panels = [
          _buildPriceListPanel(
            scheme: scheme,
            farm: selectedFarm,
            farmAgeInDays: farmAgeInDays,
            highlightedCategory: highlightedCategory,
            currentStage: currentStage,
            nextStage: nextStage,
          ),
          _buildBuyingGuidePanel(
            scheme: scheme,
            farm: selectedFarm,
            farmAgeInDays: farmAgeInDays,
            buyingGuides: buyingGuides,
            currentStage: currentStage,
          ),
          _buildTimelinePanel(
            scheme: scheme,
            farm: selectedFarm,
            farmAgeInDays: farmAgeInDays,
            schedule: schedule,
            currentStage: currentStage,
            nextStage: nextStage,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.spaceBetween,
          children: panels
              .map((panel) => SizedBox(width: cardWidth, child: panel))
              .toList(),
        );
      },
    );
  }

  Widget _buildPriceListPanel({
    required ColorScheme scheme,
    required Farm? farm,
    required int? farmAgeInDays,
    required String highlightedCategory,
    required ScheduleAlert? currentStage,
    required ScheduleAlert? nextStage,
  }) {
    final title = _priceListButtonLabel(highlightedCategory);
    final subtitle = farm == null
        ? _ui('choose_farm_to_focus')
        : '${farm.name} - ${_localizedCropLabel(farm.type)}';
    final localizedCurrentStage =
        currentStage != null ? _localizedAlert(currentStage) : null;
    final localizedNextStage =
        nextStage != null ? _localizedAlert(nextStage) : null;

    return _buildPanelContainer(
      scheme: scheme,
      icon: Icons.price_change_rounded,
      title: _ui('price_list_title'),
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _priceListSummary(
              farm: farm,
              farmAgeInDays: farmAgeInDays,
              currentStage: localizedCurrentStage,
            ),
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: FloatingActionButton.extended(
              heroTag: 'recent-price-list-button',
              onPressed: _openLatestPriceList,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: scheme.onSurface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.42),
                  width: 1.4,
                ),
              ),
              icon: Icon(Icons.open_in_new_rounded, color: scheme.primary),
              label: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFocusChip(
                scheme: scheme,
                label: 'Fertilizer',
                selected: highlightedCategory == 'Fertilizer',
                onTap: () => _openLatestPriceList(
                  initialFilter: MarketPriceCategoryFilter.fertilizer,
                ),
              ),
              _buildFocusChip(
                scheme: scheme,
                label: 'Herbicide',
                selected: highlightedCategory == 'Herbicide',
                onTap: () => _openLatestPriceList(
                  initialFilter: MarketPriceCategoryFilter.herbicide,
                ),
              ),
              _buildFocusChip(
                scheme: scheme,
                label: 'Pesticide',
                selected: highlightedCategory == 'Pesticide',
                onTap: () => _openLatestPriceList(
                  initialFilter: MarketPriceCategoryFilter.pesticide,
                ),
              ),
            ],
          ),
        ],
      ),
      footer: Text(
        _priceListFooter(localizedNextStage),
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }

  Widget _buildBuyingGuidePanel({
    required ColorScheme scheme,
    required Farm? farm,
    required int? farmAgeInDays,
    required List<_PurchaseGuide> buyingGuides,
    required ScheduleAlert? currentStage,
  }) {
    return _buildPanelContainer(
      scheme: scheme,
      icon: Icons.shopping_bag_outlined,
      title: _ui('guide_title'),
      subtitle: farm == null
          ? _ui('needs_selected_farm')
          : _guideSubtitle(farm.type, farmAgeInDays ?? 0),
      child: farm == null
          ? _buildEmptyPanelCopy(
              scheme,
              _ui('select_farm_guide'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentStage != null
                      ? _stageFocusText(_localizedAlert(currentStage))
                      : _ui('no_exact_stage_match'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 12),
                if (buyingGuides.isEmpty)
                  _buildEmptyPanelCopy(
                    scheme,
                    _ui('no_recommendation'),
                  )
                else
                  ...buyingGuides.map(
                    (guide) => _buildGuideTile(
                      scheme: scheme,
                      guide: guide,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTimelinePanel({
    required ColorScheme scheme,
    required Farm? farm,
    required int? farmAgeInDays,
    required List<ScheduleAlert> schedule,
    required ScheduleAlert? currentStage,
    required ScheduleAlert? nextStage,
  }) {
    return _buildPanelContainer(
      scheme: scheme,
      icon: Icons.timeline_rounded,
      title: _ui('timeline_title'),
      subtitle: farm == null
          ? _ui('needs_selected_farm')
          : '${farm.name} - ${_localizedCropLabel(farm.type)}',
      child: farm == null
          ? _buildEmptyPanelCopy(
              scheme,
              _ui('pick_farm_timeline'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timelineSummary(farmAgeInDays ?? 0),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                ...schedule.map(
                  (entry) => _buildTimelineTile(
                    scheme: scheme,
                    alert: entry,
                    ageInDays: farmAgeInDays ?? 0,
                    isCurrent: _isSameAlert(entry, currentStage),
                    isNext: _isSameAlert(entry, nextStage),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyPanelCopy(ColorScheme scheme, String message) {
    return Text(
      message,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: scheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }

  String _priceListSummary({
    required Farm? farm,
    required int? farmAgeInDays,
    required ScheduleAlert? currentStage,
  }) {
    if (farm == null) {
      return _ui('open_catalog_help');
    }

    switch (_selectedLanguage) {
      case GuidelineLanguage.english:
        return currentStage != null
            ? '${farm.name} is ${farmAgeInDays ?? 0} days from planting. Current stage: ${currentStage.title}.'
            : '${farm.name} is ${farmAgeInDays ?? 0} days from planting. No active input window found yet.';
      case GuidelineLanguage.tagalog:
        return currentStage != null
            ? '${farmAgeInDays ?? 0} araw na mula nang itanim ang ${farm.name}. Kasalukuyang yugto: ${currentStage.title}.'
            : '${farmAgeInDays ?? 0} araw na mula nang itanim ang ${farm.name}. Wala pang aktibong yugto ng input.';
      case GuidelineLanguage.visayan:
        return currentStage != null
            ? '${farmAgeInDays ?? 0} ka adlaw na sukad pagtanom sa ${farm.name}. Kasamtangang yugto: ${currentStage.title}.'
            : '${farmAgeInDays ?? 0} ka adlaw na sukad pagtanom sa ${farm.name}. Wala pay aktibong yugto sa input.';
    }
  }

  String _priceListFooter(ScheduleAlert? nextStage) {
    if (nextStage == null) {
      return _ui('tap_open_catalog');
    }

    switch (_selectedLanguage) {
      case GuidelineLanguage.english:
        return 'Next application window: ${nextStage.title}. The button opens the latest price list.';
      case GuidelineLanguage.tagalog:
        return 'Susunod na yugto ng paglalagay: ${nextStage.title}. Bubuksan ng button ang pinakabagong listahan ng presyo.';
      case GuidelineLanguage.visayan:
        return 'Sunod nga bintana sa aplikasyon: ${nextStage.title}. Maablihan sa button ang pinakabag-o nga listahan sa presyo.';
    }
  }

  String _guideSubtitle(String cropType, int ageInDays) {
    final cropLabel = _localizedCropLabel(cropType);
    switch (_selectedLanguage) {
      case GuidelineLanguage.english:
        return '$cropLabel at day $ageInDays';
      case GuidelineLanguage.tagalog:
        return '$cropLabel sa araw $ageInDays';
      case GuidelineLanguage.visayan:
        return '$cropLabel sa adlaw $ageInDays';
    }
  }

  String _stageFocusText(ScheduleAlert stage) {
    switch (_selectedLanguage) {
      case GuidelineLanguage.english:
        return 'Stage focus: ${stage.title}';
      case GuidelineLanguage.tagalog:
        return 'Pokus na yugto: ${stage.title}';
      case GuidelineLanguage.visayan:
        return 'Tutok nga yugto: ${stage.title}';
    }
  }

  String _timelineSummary(int ageInDays) {
    switch (_selectedLanguage) {
      case GuidelineLanguage.english:
        return 'Timeline is based on $ageInDays days from the farm date.';
      case GuidelineLanguage.tagalog:
        return 'Ang iskedyul ay batay sa $ageInDays araw mula sa petsa ng bukid.';
      case GuidelineLanguage.visayan:
        return 'Ang timeline gibase sa $ageInDays ka adlaw gikan sa petsa sa umahan.';
    }
  }

  Widget _buildGuideTile({
    required ColorScheme scheme,
    required _PurchaseGuide guide,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: guide.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: guide.color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: guide.color.withValues(alpha: 0.16),
            ),
            child: Icon(guide.icon, color: guide.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      guide.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
                    _buildGuideLabel(
                      label: guide.category,
                      color: guide.color,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  guide.detail,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTile({
    required ColorScheme scheme,
    required ScheduleAlert alert,
    required int ageInDays,
    required bool isCurrent,
    required bool isNext,
  }) {
    final localizedAlert = _localizedAlert(alert);
    final statusLabel = isCurrent
        ? 'NOW'
        : isNext
            ? 'NEXT'
            : ageInDays > alert.endDay
                ? 'DONE'
                : 'UPCOMING';
    final statusColor = isCurrent
        ? scheme.primary
        : isNext
            ? scheme.secondary
            : ageInDays > alert.endDay
                ? scheme.onSurface.withValues(alpha: 0.55)
                : scheme.tertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? scheme.primary.withValues(alpha: 0.09)
            : scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.28)
              : scheme.onSurface.withValues(alpha: 0.08),
          width: 1.15,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: alert.color.withValues(alpha: 0.16),
            ),
            child: Icon(alert.icon, color: alert.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedAlert.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dayWindowLabel(alert),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localizedAlert.message,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              GuidelineLocalizationService.statusLabel(
                statusLabel,
                _selectedLanguage,
              ),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideLabel({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _localizedCategoryLabel(label).toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFocusChip({
    required ColorScheme scheme,
    required String label,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.35)
                  : scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            _localizedCategoryLabel(label),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContainer({
    required ColorScheme scheme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surface.withValues(alpha: 0.95),
            scheme.surfaceContainerHighest.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.12),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
                child: Icon(icon, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer,
          ],
        ],
      ),
    );
  }

  int? _farmAgeInDays(Farm? farm) {
    if (farm == null) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final plantedDate =
        DateTime(farm.date.year, farm.date.month, farm.date.day);
    final diff = today.difference(plantedDate).inDays;
    return diff < 0 ? 0 : diff;
  }

  String _normalizeCropType(String cropType) {
    final normalized = cropType.trim().toLowerCase();
    if (normalized.contains('sugar')) {
      return 'sugarcane';
    }
    if (normalized.contains('corn') || normalized.contains('maize')) {
      return 'corn';
    }
    if (normalized.contains('rice') || normalized.contains('palay')) {
      return 'rice';
    }
    return normalized;
  }

  List<ScheduleAlert> _scheduleForCrop(String cropType) {
    switch (_normalizeCropType(cropType)) {
      case 'rice':
        return riceSchedules;
      case 'corn':
        return cornSchedules;
      case 'sugarcane':
        return sugarcaneSchedules;
      default:
        return const <ScheduleAlert>[];
    }
  }

  ScheduleAlert? _currentStage(List<ScheduleAlert> schedule, int ageInDays) {
    for (final alert in schedule) {
      if (ageInDays >= alert.startDay && ageInDays <= alert.endDay) {
        return alert;
      }
    }
    return null;
  }

  ScheduleAlert? _nextStage(List<ScheduleAlert> schedule, int ageInDays) {
    for (final alert in schedule) {
      if (alert.startDay > ageInDays) {
        return alert;
      }
    }
    return null;
  }

  List<_PurchaseGuide> _purchaseGuidesForFarm({
    required String cropType,
    required int ageInDays,
    required List<ScheduleAlert> schedule,
    required List<ScheduleAlert> activeAdvice,
    required GuidelineLanguage language,
  }) {
    final currentStage = _currentStage(schedule, ageInDays);
    final nextStage = _nextStage(schedule, ageInDays);
    final sources = <ScheduleAlert>[
      ...activeAdvice,
      if (currentStage != null && !_containsAlert(activeAdvice, currentStage))
        currentStage,
      if (nextStage != null && !_containsAlert(activeAdvice, nextStage))
        nextStage,
    ];
    final guides = <_PurchaseGuide>[];
    final seenCategories = <String>{};

    for (final source in sources) {
      for (final category in _categoriesForAlert(source)) {
        if (!seenCategories.add(category)) {
          continue;
        }
        guides.add(
          _guideFromAlert(
            category: category,
            source: source,
            language: language,
          ),
        );
        if (guides.length == 3) {
          return guides;
        }
      }
    }

    if (guides.isNotEmpty) {
      return guides;
    }

    return [
      _PurchaseGuide(
        category: 'Planning',
        title: _planningTitle(language),
        detail: _planningDetail(cropType, language),
        icon: Icons.fact_check_outlined,
        color: Colors.blueGrey,
      ),
    ];
  }

  bool _containsAlert(List<ScheduleAlert> alerts, ScheduleAlert target) {
    return alerts.any((alert) => _isSameAlert(alert, target));
  }

  bool _isSameAlert(ScheduleAlert? left, ScheduleAlert? right) {
    if (left == null || right == null) {
      return false;
    }
    return left.title == right.title &&
        left.startDay == right.startDay &&
        left.endDay == right.endDay;
  }

  List<String> _categoriesForAlert(ScheduleAlert alert) {
    final text = '${alert.title} ${alert.message}'.toLowerCase();
    final categories = <String>[];

    if (_containsAny(text, const [
      'fertilizer',
      'nitrogen',
      'potassium',
      'npk',
      'compost',
      'phosphate',
      'phosphorus',
    ])) {
      categories.add('Fertilizer');
    }
    if (_containsAny(text, const [
      'herbicide',
      'weed',
      'weeding',
      'weed-free',
    ])) {
      categories.add('Herbicide');
    }
    if (_containsAny(text, const [
      'pest',
      'armyworm',
      'borer',
      'snail',
      'insect',
      'fung',
      'disease',
      'spray',
    ])) {
      categories.add('Pesticide');
    }

    return categories;
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  String _planningTitle(GuidelineLanguage language) {
    switch (language) {
      case GuidelineLanguage.english:
        return 'Review the next input window';
      case GuidelineLanguage.tagalog:
        return 'Suriin ang susunod na yugto ng input';
      case GuidelineLanguage.visayan:
        return 'Susiha ang sunod nga yugto sa input';
    }
  }

  String _planningDetail(String cropType, GuidelineLanguage language) {
    final cropLabel = GuidelineLocalizationService.cropLabel(cropType, language)
        .toLowerCase();
    switch (language) {
      case GuidelineLanguage.english:
        return 'No immediate fertilizer, herbicide, or pesticide trigger was found for this $cropLabel stage. Check the next timeline window before buying.';
      case GuidelineLanguage.tagalog:
        return 'Walang agarang senyales para bumili ng abono, herbisidyo, o pestisidyo sa yugtong ito ng $cropLabel. Tingnan muna ang susunod na yugto sa iskedyul.';
      case GuidelineLanguage.visayan:
        return 'Walay dayon nga timailhan sa pagpalit og abono, herbicide, o pesticide niining yugto sa $cropLabel. Tan-awa una ang sunod nga bintana sa timeline.';
    }
  }

  String _fertilizerGuideTitle({
    required GuidelineLanguage language,
    required bool finalDoseOnly,
  }) {
    switch (language) {
      case GuidelineLanguage.english:
        return finalDoseOnly
            ? 'Buy only the final fertilizer need'
            : 'Prepare fertilizer stock';
      case GuidelineLanguage.tagalog:
        return finalDoseOnly
            ? 'Bilhin lang ang huling kailangan na abono'
            : 'Maghanda ng suplay ng abono';
      case GuidelineLanguage.visayan:
        return finalDoseOnly
            ? 'Palita lang ang katapusang gikinahanglan nga abono'
            : 'Andama ang suplay sa abono';
    }
  }

  String _herbicideGuideTitle(GuidelineLanguage language) {
    switch (language) {
      case GuidelineLanguage.english:
        return 'Prepare weed-control inputs';
      case GuidelineLanguage.tagalog:
        return 'Maghanda ng panlaban sa damo';
      case GuidelineLanguage.visayan:
        return 'Andama ang panagang batok sa sagbot';
    }
  }

  String _pesticideGuideTitle({
    required GuidelineLanguage language,
    required bool minimalOnly,
  }) {
    switch (language) {
      case GuidelineLanguage.english:
        return minimalOnly
            ? 'Keep pesticide buying minimal'
            : 'Keep targeted pest control ready';
      case GuidelineLanguage.tagalog:
        return minimalOnly
            ? 'Limitahan ang pagbili ng pestisidyo'
            : 'Maghanda ng target na panlaban sa peste';
      case GuidelineLanguage.visayan:
        return minimalOnly
            ? 'Gamayi lang ang pagpalit og pesticide'
            : 'Andama ang tukmang panagang batok sa peste';
    }
  }

  _PurchaseGuide _guideFromAlert({
    required String category,
    required ScheduleAlert source,
    required GuidelineLanguage language,
  }) {
    final text = '${source.title} ${source.message}'.toLowerCase();
    final localizedSource =
        GuidelineLocalizationService.translateAlert(source, language);

    switch (category) {
      case 'Fertilizer':
        return _PurchaseGuide(
          category: category,
          title: _fertilizerGuideTitle(
            language: language,
            finalDoseOnly: text.contains('stop'),
          ),
          detail: '${localizedSource.title}: ${localizedSource.message}',
          icon: Icons.grass_rounded,
          color: Colors.green.shade500,
        );
      case 'Herbicide':
        return _PurchaseGuide(
          category: category,
          title: _herbicideGuideTitle(language),
          detail: '${localizedSource.title}: ${localizedSource.message}',
          icon: Icons.spa_outlined,
          color: Colors.orange.shade500,
        );
      case 'Pesticide':
        return _PurchaseGuide(
          category: category,
          title: _pesticideGuideTitle(
            language: language,
            minimalOnly: text.contains('avoid'),
          ),
          detail: '${localizedSource.title}: ${localizedSource.message}',
          icon: Icons.bug_report_outlined,
          color: Colors.red.shade400,
        );
      default:
        return _PurchaseGuide(
          category: 'Planning',
          title: _planningTitle(language),
          detail: '${localizedSource.title}: ${localizedSource.message}',
          icon: Icons.fact_check_outlined,
          color: Colors.blueGrey,
        );
    }
  }

  String _priceListButtonLabel(String highlightedCategory) {
    final recent = _ui('most_recent');
    final list = _ui('list');
    final categoryLabel = highlightedCategory == 'Price List'
        ? _ui('price_list_title')
        : _localizedCategoryLabel(highlightedCategory);
    switch (_selectedLanguage) {
      case GuidelineLanguage.english:
        return highlightedCategory == 'Price List'
            ? _ui('price_list_title')
            : '$recent $categoryLabel $list';
      case GuidelineLanguage.tagalog:
        return highlightedCategory == 'Price List'
            ? _ui('price_list_title')
            : '$recent $list ng $categoryLabel';
      case GuidelineLanguage.visayan:
        return highlightedCategory == 'Price List'
            ? _ui('price_list_title')
            : '$recent $list sa $categoryLabel';
    }
  }

  String _dayWindowLabel(ScheduleAlert alert) {
    if (alert.startDay < 0 && alert.endDay <= 0) {
      return switch (_selectedLanguage) {
        GuidelineLanguage.english => 'Pre-plant to day ${alert.endDay}',
        GuidelineLanguage.tagalog =>
          'Bago magtanim hanggang araw ${alert.endDay}',
        GuidelineLanguage.visayan =>
          'Sa dili pa motanom hangtod adlaw ${alert.endDay}',
      };
    }
    if (alert.startDay < 0) {
      return switch (_selectedLanguage) {
        GuidelineLanguage.english => 'Day ${alert.startDay} to ${alert.endDay}',
        GuidelineLanguage.tagalog =>
          'Araw ${alert.startDay} hanggang ${alert.endDay}',
        GuidelineLanguage.visayan =>
          'Adlaw ${alert.startDay} hangtod ${alert.endDay}',
      };
    }
    if (alert.startDay == alert.endDay) {
      return switch (_selectedLanguage) {
        GuidelineLanguage.english => 'Day ${alert.startDay}',
        GuidelineLanguage.tagalog => 'Araw ${alert.startDay}',
        GuidelineLanguage.visayan => 'Adlaw ${alert.startDay}',
      };
    }
    return switch (_selectedLanguage) {
      GuidelineLanguage.english => 'Day ${alert.startDay} to ${alert.endDay}',
      GuidelineLanguage.tagalog =>
        'Araw ${alert.startDay} hanggang ${alert.endDay}',
      GuidelineLanguage.visayan =>
        'Adlaw ${alert.startDay} hangtod ${alert.endDay}',
    };
  }

  Widget _buildTabSwitcher() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 68,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.25),
            scheme.secondary.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: scheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                scheme.secondary,
                scheme.secondaryContainer,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.secondary.withValues(alpha: 0.6),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.65),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6),
          tabs: [
            Tab(text: _ui('supplies_tab')),
            Tab(text: _ui('equipment_tab')),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            scheme.surface,
            scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            scheme.surfaceContainerLow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TabBarView(
              controller: _tabController,
              children: [
                SuppliesTab(controller: _suppliesTabController),
                const EquipmentTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseGuide {
  final String category;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const _PurchaseGuide({
    required this.category,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}
