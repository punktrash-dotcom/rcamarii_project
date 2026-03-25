import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/delivery_model.dart';
import '../models/ftracker_model.dart';
import '../models/sugarcane_profit_model.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/ftracker_provider.dart';
import '../providers/sugarcane_profit_provider.dart';
import '../services/app_properties_store.dart';
import '../services/app_route_observer.dart';
import '../themes/app_visuals.dart';
import '../widgets/searchable_dropdown.dart';
import 'harvest_profit_calculator_screen.dart';

enum ProfitSourceMode { manualTrial, recentDelivery, pendingDelivery }

const _standaloneProfitSourceLabel = 'Standalone profit record';

class ProfitCalculatorScreen extends StatefulWidget {
  const ProfitCalculatorScreen({super.key});

  @override
  State<ProfitCalculatorScreen> createState() => _ProfitCalculatorScreenState();
}

class _ProfitCalculatorScreenState extends State<ProfitCalculatorScreen>
    with RouteAware {
  static const _lastTransactionKey = 'profit_calculator_last_transaction_v1';
  static const _screenBackground = AppVisuals.fieldMist;
  static const _surfaceCard = AppVisuals.cloudGlass;
  static const _surfaceRaised = AppVisuals.panelSoftAlt;
  static const _accentPrimary = AppVisuals.growthGreen;
  static const _accentSecondary = AppVisuals.accentChartBlue;
  static const _accentTertiary = AppVisuals.primaryGold;
  static const _accentError = Color(0xFFFF6B6B);
  static final _numberInputFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]'));

  final TextEditingController _netTonsCaneController = TextEditingController();
  final TextEditingController _lkgPerTcController = TextEditingController();
  final TextEditingController _planterShareController = TextEditingController();
  final TextEditingController _sugarPricePerLkgController =
      TextEditingController();
  final TextEditingController _molassesKgController = TextEditingController();
  final TextEditingController _molassesPricePerKgController =
      TextEditingController();
  final TextEditingController _productionCostsController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  late final List<TextEditingController> _controllers;
  _SavedProfitEntry? _savedEntry;
  _ProfitBreakdown? _lastSavedProjection;
  bool _isApplyingSavedEntry = false;
  bool _isLoadingDeliverySources = false;
  ProfitSourceMode _sourceMode = ProfitSourceMode.manualTrial;
  int? _selectedDeliveryId;
  AppAudioProvider? _appAudio;
  AppSettingsProvider? _appSettings;
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;

  NumberFormat get _currency =>
      Provider.of<AppSettingsProvider?>(context, listen: false)
          ?.currencyFormat ??
      NumberFormat.currency(locale: 'en_PH', symbol: '\u20B1');

  String get _currencySymbol =>
      Provider.of<AppSettingsProvider?>(context, listen: false)
          ?.currencySymbol ??
      '\u20B1';

  @override
  void initState() {
    super.initState();
    _controllers = [
      _netTonsCaneController,
      _lkgPerTcController,
      _planterShareController,
      _sugarPricePerLkgController,
      _molassesKgController,
      _molassesPricePerKgController,
      _productionCostsController,
    ];

    for (final controller in _controllers) {
      controller.addListener(_handleInputChanged);
    }

    _loadSavedEntry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeliverySources();
      _playScreenOpenAudioIfNeeded();
    });
  }

  Future<void> _playScreenOpenAudioIfNeeded() async {
    if (!mounted || _playedScreenOpenAudio) {
      return;
    }
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) {
      return;
    }
    _playedScreenOpenAudio = true;
    await appAudio.playScreenOpenSound(
      screenKey: 'profit',
      style: appSettings.audioSoundStyle,
      enabled: appSettings.audioSoundsEnabled,
    );
  }

  Future<void> _stopScreenOpenAudioIfNeeded() async {
    final appSettings = _appSettings;
    final appAudio = _appAudio;
    if (appSettings == null || appAudio == null) {
      return;
    }
    await appAudio.stopScreenOpenSound(
      screenKey: 'profit',
      style: appSettings.audioSoundStyle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appAudio = Provider.of<AppAudioProvider?>(context, listen: false);
    _appSettings = Provider.of<AppSettingsProvider?>(context, listen: false);
    if (!_isRouteObserverSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
        _isRouteObserverSubscribed = true;
      }
    }
  }

  @override
  void dispose() {
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    unawaited(_stopScreenOpenAudioIfNeeded());
    for (final controller in _controllers) {
      controller
        ..removeListener(_handleInputChanged)
        ..dispose();
    }
    _scrollController.dispose();
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

  void _handleInputChanged() {
    if (_isApplyingSavedEntry) {
      return;
    }

    if (mounted) {
      setState(() {
        if (_lastSavedProjection != null && _hasInput) {
          _lastSavedProjection = null;
        }
      });
    }
  }

  void _clearAll({bool clearSavedProjection = true}) {
    _isApplyingSavedEntry = true;
    try {
      for (final controller in _controllers) {
        controller.clear();
      }
    } finally {
      _isApplyingSavedEntry = false;
    }
    if (mounted) {
      setState(() {
        if (clearSavedProjection) {
          _lastSavedProjection = null;
        }
      });
    }
    FocusScope.of(context).unfocus();
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.pixels <= 0) {
      return;
    }

    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String _cleanNumber(String input) => input.replaceAll(',', '').trim();

  double _parseNumber(String input) =>
      double.tryParse(_cleanNumber(input)) ?? 0.0;

  bool get _hasInput => _controllers
      .any((controller) => _cleanNumber(controller.text).isNotEmpty);
  bool get _hasCompleteProfitRecord =>
      _cleanNumber(_netTonsCaneController.text).isNotEmpty &&
      _cleanNumber(_lkgPerTcController.text).isNotEmpty &&
      _cleanNumber(_planterShareController.text).isNotEmpty &&
      _cleanNumber(_sugarPricePerLkgController.text).isNotEmpty &&
      _cleanNumber(_productionCostsController.text).isNotEmpty;

  Future<void> _loadSavedEntry() async {
    final raw = await _store.getString(_lastTransactionKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final savedEntry = _SavedProfitEntry.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _savedEntry = savedEntry;
      });
    } catch (_) {
      await _store.remove(_lastTransactionKey);
    }
  }

  _SavedProfitEntry _captureCurrentEntry({
    required _ProfitBreakdown breakdown,
    Delivery? selectedDelivery,
  }) {
    final normalizedFarmType =
        (selectedDelivery?.type.trim().isNotEmpty ?? false)
            ? selectedDelivery!.type.trim()
            : 'Sugarcane';
    final normalizedFarmName =
        (selectedDelivery?.name.trim().isNotEmpty ?? false)
            ? selectedDelivery!.name.trim()
            : _standaloneProfitSourceLabel;

    return _SavedProfitEntry(
      netTonsCane: _netTonsCaneController.text,
      lkgPerTc: _lkgPerTcController.text,
      planterShare: _planterShareController.text,
      sugarPricePerLkg: _sugarPricePerLkgController.text,
      molassesKg: _molassesKgController.text,
      molassesPricePerKg: _molassesPricePerKgController.text,
      productionCosts: _productionCostsController.text,
      farmType: normalizedFarmType,
      farmName: normalizedFarmName,
      sugarProceeds: breakdown.sugarProceeds,
      molassesProceeds: breakdown.molassesProceeds,
      totalRevenue: breakdown.totalRevenue,
      netProfit: breakdown.netProfit,
      savedAt: DateTime.now(),
    );
  }

  Future<void> _persistSavedEntry(_SavedProfitEntry entry) async {
    await _store.setString(_lastTransactionKey, jsonEncode(entry.toJson()));

    if (!mounted) {
      return;
    }

    setState(() {
      _savedEntry = entry;
    });
  }

  Future<void> _loadDeliverySources() async {
    final deliveryProvider =
        Provider.of<DeliveryProvider?>(context, listen: false);
    final profitProvider =
        Provider.of<SugarcaneProfitProvider?>(context, listen: false);

    if (deliveryProvider == null || profitProvider == null) {
      return;
    }

    setState(() {
      _isLoadingDeliverySources = true;
    });

    await deliveryProvider.loadDeliveries();
    await profitProvider.loadProfitRecords();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingDeliverySources = false;
    });
  }

  Future<void> _storeCurrentEntry() async {
    if (!_hasInput) {
      return;
    }

    final entry = _captureCurrentEntry(breakdown: _breakdown);
    await _persistSavedEntry(entry);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
              'Stored details saved. Load them later and change only the fields you need.'),
        ),
      );
  }

  void _useSavedEntry() {
    final savedEntry = _savedEntry;
    if (savedEntry == null) {
      return;
    }

    _isApplyingSavedEntry = true;
    try {
      _netTonsCaneController.text = savedEntry.netTonsCane;
      _lkgPerTcController.text = savedEntry.lkgPerTc;
      _planterShareController.text = savedEntry.planterShare;
      _sugarPricePerLkgController.text = savedEntry.sugarPricePerLkg;
      _molassesKgController.text = savedEntry.molassesKg;
      _molassesPricePerKgController.text = savedEntry.molassesPricePerKg;
      _productionCostsController.text = savedEntry.productionCosts;
    } finally {
      _isApplyingSavedEntry = false;
    }

    setState(() {
      _lastSavedProjection = null;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
              'Stored details loaded. Update only the fields that changed.'),
        ),
      );
  }

  void _setSourceMode(ProfitSourceMode mode) {
    setState(() {
      _sourceMode = mode;
      _selectedDeliveryId = null;
    });
  }

  bool _isPendingDelivery(Delivery delivery) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deliveryDate = DateTime(
      delivery.date.year,
      delivery.date.month,
      delivery.date.day,
    );
    return deliveryDate.isAfter(today);
  }

  List<Delivery> _filterSugarcaneDeliveries(
    List<Delivery> deliveries,
    Set<int> linkedDeliveryIds, {
    required bool pending,
  }) {
    final filtered = deliveries.where((delivery) {
      final deliveryId = delivery.delId;
      if (deliveryId != null && linkedDeliveryIds.contains(deliveryId)) {
        return false;
      }
      return _isPendingDelivery(delivery) == pending;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Delivery? _findDeliveryById(List<Delivery> deliveries, int? deliveryId) {
    if (deliveryId == null) {
      return null;
    }
    for (final delivery in deliveries) {
      if (delivery.delId == deliveryId) {
        return delivery;
      }
    }
    return null;
  }

  String _formatInputNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _applyDeliverySource(Delivery delivery) {
    _isApplyingSavedEntry = true;
    try {
      if (delivery.quantity > 0) {
        _netTonsCaneController.text = _formatInputNumber(delivery.quantity);
      }
    } finally {
      _isApplyingSavedEntry = false;
    }

    setState(() {
      _selectedDeliveryId = delivery.delId;
    });
  }

  String _formatSourceDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _deliveryWeightLabel(Delivery delivery) {
    if (delivery.quantity <= 0) {
      return 'Weight pending';
    }
    return '${_formatInputNumber(delivery.quantity)} tons';
  }

  String _deliveryTrackingLabel(Delivery delivery) {
    final tracking = delivery.ticketNo?.trim() ?? '';
    if (tracking.isEmpty) {
      return 'Tracking pending';
    }
    return 'Tracking $tracking';
  }

  ProfitSourceMode _resolveQueueSourceMode({
    required List<Delivery> recentDeliveries,
    required List<Delivery> pendingDeliveries,
  }) {
    if (recentDeliveries.isEmpty && pendingDeliveries.isEmpty) {
      return ProfitSourceMode.manualTrial;
    }
    if (_sourceMode == ProfitSourceMode.pendingDelivery &&
        pendingDeliveries.isNotEmpty) {
      return ProfitSourceMode.pendingDelivery;
    }
    if (_sourceMode == ProfitSourceMode.recentDelivery &&
        recentDeliveries.isNotEmpty) {
      return ProfitSourceMode.recentDelivery;
    }
    return recentDeliveries.isNotEmpty
        ? ProfitSourceMode.recentDelivery
        : ProfitSourceMode.pendingDelivery;
  }

  String _deliveryDropdownLabel(Delivery delivery, {required bool pending}) {
    final status = pending ? 'Pending' : 'Recent';
    final weightLabel = _deliveryWeightLabel(delivery);
    return '${delivery.name} | ${_deliveryTrackingLabel(delivery)} | ${_formatSourceDate(delivery.date)} | $weightLabel | $status';
  }

  Ftracker _buildTrackerRecord(
    SugarcaneProfit record, {
    Delivery? selectedDelivery,
  }) {
    final farmType = (selectedDelivery?.type.trim().isNotEmpty ?? false)
        ? selectedDelivery!.type.trim()
        : 'Sugarcane';
    final farmName = record.farmName.trim().isNotEmpty
        ? record.farmName.trim()
        : _standaloneProfitSourceLabel;

    return Ftracker(
      date: record.deliveryDate,
      type: 'Income',
      category: 'Farm',
      name: '$farmType | $farmName',
      amount: record.totalRevenue,
      note: [
        'Profit calculator revenue entry',
        'Net profit: ${_currency.format(record.netProfit)}',
        if (record.note?.trim().isNotEmpty ?? false) record.note!.trim(),
      ].join(' | '),
    );
  }

  Future<void> _saveProfitRecord(
    SugarcaneProfitProvider profitProvider,
    Delivery? selectedDelivery,
  ) async {
    if (!_hasCompleteProfitRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the required harvest, pricing, and production cost fields first.',
          ),
        ),
      );
      return;
    }

    final deliveryProvider =
        Provider.of<DeliveryProvider?>(context, listen: false);
    final linkedIds = profitProvider.linkedDeliveryIds;
    final allDeliveries =
        deliveryProvider?.sugarcaneDeliveries ?? const <Delivery>[];
    final recentDeliveries = _filterSugarcaneDeliveries(
      allDeliveries,
      linkedIds,
      pending: false,
    );
    final pendingDeliveries = _filterSugarcaneDeliveries(
      allDeliveries,
      linkedIds,
      pending: true,
    );
    final hasQueuedDeliveries =
        recentDeliveries.isNotEmpty || pendingDeliveries.isNotEmpty;
    final effectiveSourceMode = _resolveQueueSourceMode(
      recentDeliveries: recentDeliveries,
      pendingDeliveries: pendingDeliveries,
    );

    if (hasQueuedDeliveries && selectedDelivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Queued sugarcane deliveries are waiting. Match this computation to the correct farm and tracking / ticket number before saving.',
          ),
        ),
      );
      return;
    }

    final breakdown = _breakdown;
    final now = DateTime.now();
    final sourceType = selectedDelivery == null ? 'manual' : 'delivery';
    final sourceStatus = selectedDelivery == null
        ? 'manual'
        : switch (effectiveSourceMode) {
            ProfitSourceMode.manualTrial => 'manual',
            ProfitSourceMode.recentDelivery => 'recent',
            ProfitSourceMode.pendingDelivery => 'pending',
          };
    final isPendingSource =
        effectiveSourceMode == ProfitSourceMode.pendingDelivery;
    final sourceLabel = selectedDelivery == null
        ? _standaloneProfitSourceLabel
        : _deliveryDropdownLabel(
            selectedDelivery,
            pending: isPendingSource,
          );
    final farmName = selectedDelivery?.name ?? _standaloneProfitSourceLabel;
    final sourceNote = selectedDelivery?.note;

    final record = SugarcaneProfit(
      deliveryId: selectedDelivery?.delId,
      sourceType: sourceType,
      sourceLabel: sourceLabel,
      sourceStatus: sourceStatus,
      farmName: farmName,
      deliveryDate: selectedDelivery?.date ?? now,
      netTonsCane: _parseNumber(_netTonsCaneController.text),
      lkgPerTc: _parseNumber(_lkgPerTcController.text),
      planterShare: _parseNumber(_planterShareController.text),
      sugarPricePerLkg: _parseNumber(_sugarPricePerLkgController.text),
      molassesKg: _parseNumber(_molassesKgController.text),
      molassesPricePerKg: _parseNumber(_molassesPricePerKgController.text),
      productionCosts: _parseNumber(_productionCostsController.text),
      sugarProceeds: breakdown.sugarProceeds,
      molassesProceeds: breakdown.molassesProceeds,
      totalRevenue: breakdown.totalRevenue,
      netProfit: breakdown.netProfit,
      note: sourceNote,
      createdAt: now,
    );

    final trackerRecord = _buildTrackerRecord(
      record,
      selectedDelivery: selectedDelivery,
    );
    final savedEntry = _captureCurrentEntry(
      breakdown: breakdown,
      selectedDelivery: selectedDelivery,
    );
    final ftrackerProvider =
        Provider.of<FtrackerProvider?>(context, listen: false);

    try {
      await profitProvider.saveProfitRecord(
        record,
        trackerRecord: trackerRecord,
      );
      await _persistSavedEntry(savedEntry);
      if (ftrackerProvider != null) {
        await ftrackerProvider.loadFtrackerRecords();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to save the profit record: $error'),
          ),
        );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _lastSavedProjection = breakdown;
      if (selectedDelivery != null) {
        _selectedDeliveryId = null;
      }
    });
    _clearAll(clearSavedProjection: false);
    await _scrollToTop();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            selectedDelivery == null
                ? 'Profit record saved and revenue was added to FTracker.'
                : 'Profit saved, revenue was added to FTracker, and the selected delivery left the queue.',
          ),
        ),
      );
  }

  ThemeData _buildCalculatorTheme(ThemeData baseTheme) {
    final scheme = baseTheme.colorScheme.copyWith(
      brightness: Brightness.light,
      primary: _accentPrimary,
      secondary: _accentSecondary,
      tertiary: _accentTertiary,
      error: _accentError,
      errorContainer: const Color(0xFFFFDAD6),
      surface: _surfaceCard,
      surfaceContainerHighest: _surfaceRaised,
      onSurface: AppVisuals.textForest,
      onSurfaceVariant: AppVisuals.textForestMuted,
      onPrimary: AppVisuals.deepGreen,
      onSecondary: AppVisuals.deepGreen,
      onTertiary: AppVisuals.deepGreen,
      onErrorContainer: AppVisuals.textForest,
    );

    return baseTheme.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: _screenBackground,
      canvasColor: _screenBackground,
      cardColor: _surfaceRaised,
      iconTheme: const IconThemeData(color: AppVisuals.textForest),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: AppVisuals.textForest,
        displayColor: AppVisuals.textForest,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.82),
        labelStyle:
            TextStyle(color: AppVisuals.textForest.withValues(alpha: 0.65)),
        floatingLabelStyle: const TextStyle(
          color: AppVisuals.textForest,
          fontWeight: FontWeight.w700,
        ),
        hintStyle:
            TextStyle(color: AppVisuals.textForest.withValues(alpha: 0.38)),
        prefixStyle: const TextStyle(color: AppVisuals.textForest),
        suffixStyle:
            TextStyle(color: AppVisuals.textForest.withValues(alpha: 0.72)),
        prefixIconColor: AppVisuals.textForest.withValues(alpha: 0.72),
        suffixIconColor: AppVisuals.textForest.withValues(alpha: 0.72),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: AppVisuals.textForest.withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: AppVisuals.textForest.withValues(alpha: 0.45)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              BorderSide(color: AppVisuals.textForest.withValues(alpha: 0.16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppVisuals.textForest,
          backgroundColor: AppVisuals.textForest.withValues(alpha: 0.04),
          side:
              BorderSide(color: AppVisuals.textForest.withValues(alpha: 0.14)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary.withValues(alpha: 0.92),
          disabledForegroundColor:
              AppVisuals.textForest.withValues(alpha: 0.38),
          disabledBackgroundColor:
              AppVisuals.textForest.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(color: AppVisuals.textForest),
      ),
    );
  }

  _ProfitBreakdown get _breakdown {
    final netTonsCane = _parseNumber(_netTonsCaneController.text);
    final lkgPerTc = _parseNumber(_lkgPerTcController.text);
    final planterSharePercent = _parseNumber(_planterShareController.text);
    final sugarPricePerLkg = _parseNumber(_sugarPricePerLkgController.text);
    final molassesKg = _parseNumber(_molassesKgController.text);
    final molassesPricePerKg = _parseNumber(_molassesPricePerKgController.text);
    final productionCosts = _parseNumber(_productionCostsController.text);

    final planterShareDecimal = planterSharePercent / 100;
    final sugarProceeds =
        netTonsCane * lkgPerTc * planterShareDecimal * sugarPricePerLkg;
    final molassesProceeds = molassesKg * molassesPricePerKg;
    final totalRevenue = sugarProceeds + molassesProceeds;
    final netProfit = totalRevenue - productionCosts;

    return _ProfitBreakdown(
      sugarProceeds: sugarProceeds,
      molassesProceeds: molassesProceeds,
      totalRevenue: totalRevenue,
      productionCosts: productionCosts,
      netProfit: netProfit,
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AppSettingsProvider?>(context);
    final calculatorTheme = _buildCalculatorTheme(Theme.of(context));

    return Theme(
      data: calculatorTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final breakdown = _breakdown;
          final hasInput = _hasInput;
          final showSavedProjection = !hasInput && _lastSavedProjection != null;
          final displayedBreakdown =
              hasInput ? breakdown : (_lastSavedProjection ?? breakdown);
          final isLoss = (hasInput || showSavedProjection) &&
              displayedBreakdown.netProfit < 0;
          final deliveryProvider = Provider.of<DeliveryProvider?>(context);
          final profitProvider = Provider.of<SugarcaneProfitProvider?>(context);

          return Scaffold(
            backgroundColor: _screenBackground,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth - 40;

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary.withValues(alpha: 0.16),
                        scheme.secondary.withValues(alpha: 0.10),
                        _screenBackground,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -110,
                        right: -70,
                        child: _buildAura(
                          color: scheme.secondary.withValues(alpha: 0.18),
                          size: 240,
                        ),
                      ),
                      Positioned(
                        top: 240,
                        left: -100,
                        child: _buildAura(
                          color: scheme.tertiary.withValues(alpha: 0.12),
                          size: 220,
                        ),
                      ),
                      SafeArea(
                        child: SingleChildScrollView(
                          key: const ValueKey('profitCalculator.scrollView'),
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(theme),
                              const SizedBox(height: 18),
                              _buildHeroCard(
                                theme,
                                displayedBreakdown,
                                hasInput,
                                isLoss,
                                showSavedProjection: showSavedProjection,
                              ),
                              const SizedBox(height: 16),
                              _buildMetricsGrid(
                                theme: theme,
                                width: availableWidth,
                                breakdown: displayedBreakdown,
                                hasInput: hasInput || showSavedProjection,
                              ),
                              const SizedBox(height: 18),
                              _buildInputsPanel(
                                theme: theme,
                                width: availableWidth,
                                deliveryProvider: deliveryProvider,
                                profitProvider: profitProvider,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Live estimate updates as you type. Use Store details to keep a reusable draft, then load it later and edit only the fields that changed.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.72),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAura({required Color color, required double size}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.5,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final scheme = theme.colorScheme;
    final compactHeader = MediaQuery.sizeOf(context).width < 430;
    final backButton = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).maybePop(),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LIVE SUGARCANE ESTIMATE',
          style: theme.textTheme.bodySmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Profit Calculator',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
    final locationBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppVisuals.textForest.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppVisuals.textForest.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        'Philippines',
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compactHeader) ...[
          Row(
            children: [
              backButton,
              const Spacer(),
              locationBadge,
            ],
          ),
          const SizedBox(height: 14),
          titleBlock,
        ] else
          Row(
            children: [
              backButton,
              const SizedBox(width: 14),
              Expanded(child: titleBlock),
              const SizedBox(width: 12),
              locationBadge,
            ],
          ),
        const SizedBox(height: 14),
        Text(
          'Select crop',
          style: theme.textTheme.bodySmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              key: const ValueKey('profitCalculator.crop.sugarcane'),
              label: const Text('Sugarcane'),
              selected: true,
              onSelected: (_) {},
            ),
            ChoiceChip(
              key: const ValueKey('profitCalculator.crop.rice'),
              label: const Text('Rice'),
              selected: false,
              onSelected: (_) => _openHarvestCalculator(HarvestCrop.rice),
            ),
            ChoiceChip(
              key: const ValueKey('profitCalculator.crop.corn'),
              label: const Text('Corn'),
              selected: false,
              onSelected: (_) => _openHarvestCalculator(HarvestCrop.corn),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openHarvestCalculator(HarvestCrop crop) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HarvestProfitCalculatorScreen(initialCrop: crop),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Widget _buildHeroCard(
    ThemeData theme,
    _ProfitBreakdown breakdown,
    bool hasInput,
    bool isLoss, {
    bool showSavedProjection = false,
  }) {
    final scheme = theme.colorScheme;
    final hasProjection = hasInput || showSavedProjection;
    final gradientColors = isLoss
        ? [
            scheme.error.withValues(alpha: 0.92),
            scheme.errorContainer.withValues(alpha: 0.95),
            scheme.surfaceContainerHighest.withValues(alpha: 0.98),
          ]
        : hasProjection
            ? [
                scheme.secondary.withValues(alpha: 0.95),
                scheme.primary.withValues(alpha: 0.94),
                scheme.surfaceContainerHighest.withValues(alpha: 0.98),
              ]
            : [
                scheme.primary.withValues(alpha: 0.9),
                scheme.primary.withValues(alpha: 0.74),
                scheme.surfaceContainerHighest.withValues(alpha: 0.95),
              ];

    final heroTextColor = isLoss ? scheme.onErrorContainer : scheme.onPrimary;
    final statusLabel = showSavedProjection
        ? 'Last saved projection'
        : !hasInput
            ? 'Start with your latest field and market figures.'
            : isLoss
                ? 'Loss Position'
                : 'Revenue is ahead of production costs.';
    final statusMessage = showSavedProjection
        ? 'Projected computation from the most recently saved record.'
        : isLoss
            ? 'Loss Position'
            : hasInput
                ? 'Revenue is ahead of production costs.'
                : 'Start with your latest field and market figures.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: AppVisuals.textForest.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: AppVisuals.textForest.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.stacked_line_chart_rounded,
              size: 132,
              color: AppVisuals.textForest.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppVisuals.textForest.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  hasProjection ? statusLabel : 'Ready for live calculation',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: heroTextColor.withValues(alpha: 0.92),
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Projected Net Profit',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: heroTextColor.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currency.format(breakdown.netProfit),
                key: const ValueKey('profitCalculator.netProfit'),
                style: theme.textTheme.displayLarge?.copyWith(
                  color: heroTextColor,
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                statusMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: heroTextColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildHeroChip(
                    theme: theme,
                    icon: Icons.paid_rounded,
                    label: 'Revenue',
                    value: _currency.format(breakdown.totalRevenue),
                    foregroundColor: heroTextColor,
                  ),
                  _buildHeroChip(
                    theme: theme,
                    icon: Icons.inventory_2_rounded,
                    label: 'Costs',
                    value: _currency.format(breakdown.productionCosts),
                    foregroundColor: heroTextColor,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppVisuals.textForest.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppVisuals.textForest.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: foregroundColor.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid({
    required ThemeData theme,
    required double width,
    required _ProfitBreakdown breakdown,
    required bool hasInput,
  }) {
    final scheme = theme.colorScheme;
    const spacing = 12.0;
    final columns = width >= 980
        ? 4
        : width >= 680
            ? 2
            : 1;
    final cardWidth =
        columns == 1 ? width : (width - ((columns - 1) * spacing)) / columns;

    final metrics = [
      _MetricCardData(
        title: 'Sugar Proceeds',
        value: _currency.format(breakdown.sugarProceeds),
        icon: Icons.grass_rounded,
        accent: scheme.primary,
        valueKey: const ValueKey('profitCalculator.sugarProceeds'),
      ),
      _MetricCardData(
        title: 'Molasses Proceeds',
        value: _currency.format(breakdown.molassesProceeds),
        icon: Icons.water_drop_rounded,
        accent: scheme.secondary,
        valueKey: const ValueKey('profitCalculator.molassesProceeds'),
      ),
      _MetricCardData(
        title: 'Total Revenue',
        value: _currency.format(breakdown.totalRevenue),
        icon: Icons.account_balance_wallet_rounded,
        accent: scheme.tertiary,
        valueKey: const ValueKey('profitCalculator.totalRevenue'),
      ),
      _MetricCardData(
        title: 'Production Costs',
        value: _currency.format(breakdown.productionCosts),
        icon: Icons.receipt_long_rounded,
        accent: hasInput && breakdown.netProfit < 0
            ? scheme.error
            : scheme.onSurface,
        valueKey: const ValueKey('profitCalculator.productionCostsValue'),
      ),
    ];

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: metrics
          .map((metric) => SizedBox(
                width: cardWidth,
                child: _buildMetricCard(theme, metric),
              ))
          .toList(),
    );
  }

  Widget _buildMetricCard(ThemeData theme, _MetricCardData metric) {
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surfaceContainerHighest.withValues(alpha: 0.92),
            scheme.surface.withValues(alpha: 0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: metric.accent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: metric.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(metric.icon, color: metric.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metric.value,
                  key: metric.valueKey,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsPanel({
    required ThemeData theme,
    required double width,
    required DeliveryProvider? deliveryProvider,
    required SugarcaneProfitProvider? profitProvider,
  }) {
    final scheme = theme.colorScheme;
    const spacing = 14.0;
    final columns = width >= 1080 ? 2 : 1;
    final stackHeaderVertical = width < 860;
    final sectionWidth =
        columns == 1 ? width : (width - ((columns - 1) * spacing)) / columns;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surface.withValues(alpha: 0.98),
            scheme.surfaceContainerHighest.withValues(alpha: 0.94),
            scheme.surface.withValues(alpha: 0.99),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!stackHeaderVertical)
                Row(
                  children: [
                    Expanded(child: _buildInputStackHeading(theme, scheme)),
                    const SizedBox(width: 12),
                    _buildInputStackActions(),
                  ],
                )
              else ...[
                _buildInputStackHeading(theme, scheme),
                const SizedBox(height: 14),
                _buildInputStackActions(),
              ],
            ],
          ),
          if (_savedEntry != null) ...[
            const SizedBox(height: 12),
            Text(
              'Stored details saved ${DateFormat('MMM d, h:mm a').format(_savedEntry!.savedAt)}. Load them any time and only revise the fields that moved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.70),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _buildDeliverySourceCard(
            theme: theme,
            deliveryProvider: deliveryProvider,
            profitProvider: profitProvider,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: sectionWidth,
                child: _buildSectionCard(
                  theme: theme,
                  icon: Icons.agriculture_rounded,
                  title: 'Harvest Inputs',
                  subtitle: 'Production volume and planter share',
                  fields: [
                    _buildInputField(
                      controller: _netTonsCaneController,
                      fieldKey: 'profitCalculator.netTonsCane',
                      label: 'Net Weight of Cane',
                      hint: 'Example: 100',
                      previousValue: _savedEntry?.netTonsCane,
                      icon: Icons.scale_rounded,
                      suffix: 'tons',
                    ),
                    _buildInputField(
                      controller: _lkgPerTcController,
                      fieldKey: 'profitCalculator.lkgPerTc',
                      label: 'LKG/TC',
                      hint: 'Example: 1.90',
                      previousValue: _savedEntry?.lkgPerTc,
                      icon: Icons.straighten_rounded,
                    ),
                    _buildInputField(
                      controller: _planterShareController,
                      fieldKey: 'profitCalculator.planterShare',
                      label: 'Planter Share',
                      hint: 'Example: 70',
                      previousValue: _savedEntry?.planterShare,
                      icon: Icons.pie_chart_rounded,
                      suffix: '%',
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: sectionWidth,
                child: _buildSectionCard(
                  theme: theme,
                  icon: Icons.sell_rounded,
                  title: 'Market Returns',
                  subtitle: 'Sugar and optional molasses pricing',
                  fields: [
                    _buildInputField(
                      controller: _sugarPricePerLkgController,
                      fieldKey: 'profitCalculator.sugarPricePerLkg',
                      label: 'Sugar Price per LKG',
                      hint: 'Example: 50',
                      previousValue: _savedEntry?.sugarPricePerLkg,
                      icon: Icons.payments_rounded,
                      prefix: _currencySymbol,
                    ),
                    _buildInputField(
                      controller: _molassesKgController,
                      fieldKey: 'profitCalculator.molassesKg',
                      label: 'Molasses Quantity',
                      hint: 'Optional',
                      previousValue: _savedEntry?.molassesKg,
                      icon: Icons.water_drop_rounded,
                      suffix: 'kg',
                    ),
                    _buildInputField(
                      controller: _molassesPricePerKgController,
                      fieldKey: 'profitCalculator.molassesPricePerKg',
                      label: 'Molasses Price per kg',
                      hint: 'Optional',
                      previousValue: _savedEntry?.molassesPricePerKg,
                      icon: Icons.local_offer_rounded,
                      prefix: _currencySymbol,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: sectionWidth,
                child: _buildSectionCard(
                  theme: theme,
                  icon: Icons.request_quote_rounded,
                  title: 'Cost Inputs',
                  subtitle: 'Total expenses to subtract from revenue',
                  fields: [
                    _buildInputField(
                      controller: _productionCostsController,
                      fieldKey: 'profitCalculator.productionCosts',
                      label: 'Production Costs Per Delivery',
                      hint: 'Example: 35000',
                      previousValue: _savedEntry?.productionCosts,
                      icon: Icons.receipt_long_rounded,
                      prefix: _currencySymbol,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profitProvider != null) ...[
            const SizedBox(height: 20),
            Text(
              'Save the completed calculation here. If a queued sugarcane delivery is waiting, link the correct farm and tracking / ticket number first so the queue stays accurate.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.70),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('profitCalculator.saveProfitRecord'),
              onPressed: () {
                final linkedDelivery = _findLinkedDeliveryForCurrentMode(
                  deliveryProvider,
                  profitProvider,
                );
                _saveProfitRecord(profitProvider, linkedDelivery);
              },
              icon: const Icon(Icons.save_alt_rounded),
              label: Text(
                _findLinkedDeliveryForCurrentMode(
                          deliveryProvider,
                          profitProvider,
                        ) ==
                        null
                    ? 'Save Profit Record'
                    : 'Save Linked Delivery Profit',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputStackHeading(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INPUT STACK',
          style: theme.textTheme.bodySmall?.copyWith(
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Harvest, pricing, and cost assumptions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildInputStackActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        if (_savedEntry != null)
          OutlinedButton.icon(
            key: const ValueKey('profitCalculator.loadStoredEntry'),
            onPressed: _useSavedEntry,
            icon: const Icon(Icons.history_rounded),
            label: const Text('Load stored details'),
          ),
        FilledButton.icon(
          key: const ValueKey('profitCalculator.storeEntry'),
          onPressed: _hasInput ? _storeCurrentEntry : null,
          icon: const Icon(Icons.bookmark_added_rounded),
          label: Text(
            _savedEntry == null ? 'Store details' : 'Update stored details',
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('profitCalculator.clearAll'),
          onPressed: _clearAll,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Clear all'),
        ),
      ],
    );
  }

  Delivery? _findLinkedDeliveryForCurrentMode(
    DeliveryProvider? deliveryProvider,
    SugarcaneProfitProvider? profitProvider,
  ) {
    if (deliveryProvider == null || profitProvider == null) {
      return null;
    }

    final linkedIds = profitProvider.linkedDeliveryIds;
    final recentDeliveries = _filterSugarcaneDeliveries(
      deliveryProvider.sugarcaneDeliveries,
      linkedIds,
      pending: false,
    );
    final pendingDeliveries = _filterSugarcaneDeliveries(
      deliveryProvider.sugarcaneDeliveries,
      linkedIds,
      pending: true,
    );
    final effectiveSourceMode = _resolveQueueSourceMode(
      recentDeliveries: recentDeliveries,
      pendingDeliveries: pendingDeliveries,
    );
    final available = switch (effectiveSourceMode) {
      ProfitSourceMode.manualTrial => const <Delivery>[],
      ProfitSourceMode.recentDelivery => recentDeliveries,
      ProfitSourceMode.pendingDelivery => pendingDeliveries,
    };
    return _findDeliveryById(available, _selectedDeliveryId);
  }

  Widget _buildDeliverySourceCard({
    required ThemeData theme,
    required DeliveryProvider? deliveryProvider,
    required SugarcaneProfitProvider? profitProvider,
  }) {
    final scheme = theme.colorScheme;
    final linkedIds = profitProvider?.linkedDeliveryIds ?? const <int>{};
    final allDeliveries =
        deliveryProvider?.sugarcaneDeliveries ?? const <Delivery>[];
    final recentDeliveries = _filterSugarcaneDeliveries(
      allDeliveries,
      linkedIds,
      pending: false,
    );
    final pendingDeliveries = _filterSugarcaneDeliveries(
      allDeliveries,
      linkedIds,
      pending: true,
    );
    final hasQueuedDeliveries =
        recentDeliveries.isNotEmpty || pendingDeliveries.isNotEmpty;
    final effectiveSourceMode = _resolveQueueSourceMode(
      recentDeliveries: recentDeliveries,
      pendingDeliveries: pendingDeliveries,
    );
    final activeDeliveries = switch (effectiveSourceMode) {
      ProfitSourceMode.manualTrial => const <Delivery>[],
      ProfitSourceMode.recentDelivery => recentDeliveries,
      ProfitSourceMode.pendingDelivery => pendingDeliveries,
    };
    final selectedDelivery =
        _findDeliveryById(activeDeliveries, _selectedDeliveryId);
    final selectedValue = activeDeliveries.any(
      (delivery) => delivery.delId == _selectedDeliveryId,
    )
        ? _selectedDeliveryId
        : null;
    final queuedCount = recentDeliveries.length + pendingDeliveries.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppVisuals.textForest.withValues(alpha: 0.08)),
      ),
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
                      'DELIVERY SOURCE',
                      style: theme.textTheme.bodySmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Queued sugarcane deliveries waiting for profit entry',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (deliveryProvider != null && profitProvider != null)
                OutlinedButton.icon(
                  onPressed:
                      _isLoadingDeliverySources ? null : _loadDeliverySources,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (deliveryProvider == null || profitProvider == null)
            Text(
              'Delivery sync is unavailable in this context. Save will stay as a standalone profit record.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.70),
                height: 1.5,
              ),
            )
          else if (_isLoadingDeliverySources)
            const LinearProgressIndicator()
          else if (!hasQueuedDeliveries)
            Text(
              'No recent or pending sugarcane deliveries are waiting right now. You can still save this as a standalone profit record.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.70),
                height: 1.5,
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.tertiary.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notification_important_rounded,
                    color: scheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      queuedCount == 1
                          ? '1 sugarcane delivery is waiting. Match this computation to the correct farm and tracking / ticket number before saving.'
                          : '$queuedCount sugarcane deliveries are waiting. Match this computation to the correct farm and tracking / ticket number before saving.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (recentDeliveries.isNotEmpty)
                  ChoiceChip(
                    label: Text('Recent (${recentDeliveries.length})'),
                    selected:
                        effectiveSourceMode == ProfitSourceMode.recentDelivery,
                    onSelected: (_) =>
                        _setSourceMode(ProfitSourceMode.recentDelivery),
                  ),
                if (pendingDeliveries.isNotEmpty)
                  ChoiceChip(
                    label: Text('Pending (${pendingDeliveries.length})'),
                    selected:
                        effectiveSourceMode == ProfitSourceMode.pendingDelivery,
                    onSelected: (_) =>
                        _setSourceMode(ProfitSourceMode.pendingDelivery),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SearchableDropdownFormField<int>(
              initialValue: selectedValue,
              decoration: const InputDecoration(
                labelText:
                    'Queued sugarcane delivery by farm and tracking number',
              ),
              items: activeDeliveries
                  .where((delivery) => delivery.delId != null)
                  .map(
                    (delivery) => DropdownMenuItem<int>(
                      value: delivery.delId!,
                      child: Text(
                        _deliveryDropdownLabel(
                          delivery,
                          pending: effectiveSourceMode ==
                              ProfitSourceMode.pendingDelivery,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                final delivery = _findDeliveryById(activeDeliveries, value);
                if (delivery == null) {
                  setState(() {
                    _selectedDeliveryId = null;
                  });
                  return;
                }
                _applyDeliverySource(delivery);
              },
            ),
            if (selectedDelivery == null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Pick the matching farm and tracking / ticket number so this profit record is attached to the correct queued transaction.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    height: 1.5,
                  ),
                ),
              ),
            if (selectedDelivery != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppVisuals.textForest.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppVisuals.textForest.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedDelivery.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Date: ${_formatSourceDate(selectedDelivery.date)}    ${_deliveryWeightLabel(selectedDelivery)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    if ((selectedDelivery.ticketNo?.trim().isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Tracking / Ticket: ${selectedDelivery.ticketNo!.trim()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    if ((selectedDelivery.note?.trim().isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          selectedDelivery.note!.trim(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.64),
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (selectedDelivery.quantity <= 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Weekly report not posted yet. Enter the net tons manually in the harvest inputs when the report arrives.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.70),
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> fields,
  }) {
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surfaceContainerHighest.withValues(alpha: 0.94),
            scheme.surface.withValues(alpha: 0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns =
                  constraints.maxWidth >= 520 && fields.length > 1 ? 2 : 1;
              final fieldWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: fields
                    .map((field) => SizedBox(width: fieldWidth, child: field))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String fieldKey,
    required String label,
    required String hint,
    String? previousValue,
    required IconData icon,
    String? prefix,
    String? suffix,
  }) {
    final savedHint = previousValue?.trim() ?? '';
    final showSavedSuggestion =
        controller.text.trim().isEmpty && savedHint.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          stylusHandwritingEnabled: false,
          key: ValueKey(fieldKey),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_numberInputFormatter],
          style: const TextStyle(
            color: AppVisuals.textForest,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: AppVisuals.textForest,
          decoration: InputDecoration(
            labelText: label,
            hintText: showSavedSuggestion ? savedHint : hint,
            prefixText: prefix,
            suffixText: suffix,
            prefixIcon: Icon(icon, size: 18),
          ),
        ),
        if (showSavedSuggestion) ...[
          const SizedBox(height: 8),
          InkWell(
            key: ValueKey('$fieldKey.useSavedHint'),
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              _isApplyingSavedEntry = true;
              try {
                controller.value = TextEditingValue(
                  text: savedHint,
                  selection: TextSelection.collapsed(offset: savedHint.length),
                );
              } finally {
                _isApplyingSavedEntry = false;
              }

              if (!mounted) {
                return;
              }

              setState(() {
                _lastSavedProjection = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    savedHint,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProfitBreakdown {
  const _ProfitBreakdown({
    required this.sugarProceeds,
    required this.molassesProceeds,
    required this.totalRevenue,
    required this.productionCosts,
    required this.netProfit,
  });

  final double sugarProceeds;
  final double molassesProceeds;
  final double totalRevenue;
  final double productionCosts;
  final double netProfit;
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.valueKey,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final Key valueKey;
}

class _SavedProfitEntry {
  const _SavedProfitEntry({
    required this.netTonsCane,
    required this.lkgPerTc,
    required this.planterShare,
    required this.sugarPricePerLkg,
    required this.molassesKg,
    required this.molassesPricePerKg,
    required this.productionCosts,
    required this.farmType,
    required this.farmName,
    required this.sugarProceeds,
    required this.molassesProceeds,
    required this.totalRevenue,
    required this.netProfit,
    required this.savedAt,
  });

  final String netTonsCane;
  final String lkgPerTc;
  final String planterShare;
  final String sugarPricePerLkg;
  final String molassesKg;
  final String molassesPricePerKg;
  final String productionCosts;
  final String farmType;
  final String farmName;
  final double sugarProceeds;
  final double molassesProceeds;
  final double totalRevenue;
  final double netProfit;
  final DateTime savedAt;

  Map<String, dynamic> toJson() {
    return {
      'netTonsCane': netTonsCane,
      'lkgPerTc': lkgPerTc,
      'planterShare': planterShare,
      'sugarPricePerLkg': sugarPricePerLkg,
      'molassesKg': molassesKg,
      'molassesPricePerKg': molassesPricePerKg,
      'productionCosts': productionCosts,
      'farmType': farmType,
      'farmName': farmName,
      'sugarProceeds': sugarProceeds,
      'molassesProceeds': molassesProceeds,
      'totalRevenue': totalRevenue,
      'netProfit': netProfit,
      'savedAt': savedAt.millisecondsSinceEpoch,
    };
  }

  factory _SavedProfitEntry.fromJson(Map<String, dynamic> json) {
    return _SavedProfitEntry(
      netTonsCane: json['netTonsCane'] as String? ?? '',
      lkgPerTc: json['lkgPerTc'] as String? ?? '',
      planterShare: json['planterShare'] as String? ?? '',
      sugarPricePerLkg: json['sugarPricePerLkg'] as String? ?? '',
      molassesKg: json['molassesKg'] as String? ?? '',
      molassesPricePerKg: json['molassesPricePerKg'] as String? ?? '',
      productionCosts: json['productionCosts'] as String? ?? '',
      farmType: json['farmType'] as String? ?? 'Sugarcane',
      farmName: json['farmName'] as String? ?? _standaloneProfitSourceLabel,
      sugarProceeds: (json['sugarProceeds'] as num?)?.toDouble() ?? 0,
      molassesProceeds: (json['molassesProceeds'] as num?)?.toDouble() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0,
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        json['savedAt'] as int? ?? 0,
      ),
    );
  }
}
