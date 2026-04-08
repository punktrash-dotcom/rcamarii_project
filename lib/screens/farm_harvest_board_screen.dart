import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/activity_model.dart';
import '../models/delivery_model.dart';
import '../models/farm_harvest_entry_model.dart';
import '../models/farm_harvest_session_model.dart';
import '../models/farm_model.dart';
import '../models/sugarcane_profit_model.dart';
import '../providers/app_settings_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/farm_harvest_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/sugarcane_profit_provider.dart';
import '../services/database_helper.dart';
import '../services/farm_operations_service.dart';
import '../themes/app_visuals.dart';
import '../utils/app_number_input_formatter.dart';
import '../widgets/focus_tooltip.dart';
import '../widgets/searchable_dropdown.dart';
import 'frm_logistics.dart';
import 'harvest_board_sugarcane_profit_screen.dart';

class FarmHarvestBoardScreen extends StatefulWidget {
  const FarmHarvestBoardScreen({
    super.key,
    required this.farm,
  });

  final Farm farm;

  @override
  State<FarmHarvestBoardScreen> createState() => _FarmHarvestBoardScreenState();
}

class _FarmHarvestBoardScreenState extends State<FarmHarvestBoardScreen> {
  static final _numberFormatter = AppNumberInputFormatter();

  late final FarmHarvestProvider _harvestProvider;
  late Farm _farm;
  final TextEditingController _tonsController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _deliveryBatchController =
      TextEditingController();
  final TextEditingController _deliveryTrackingController =
      TextEditingController();
  final TextEditingController _deliveryCompanyController =
      TextEditingController();
  final TextEditingController _deliveryCostController = TextEditingController();
  final TextEditingController _deliveryNoteController = TextEditingController();
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

  bool _startEarlyHarvest = false;
  String _entryType = 'delivery';
  DateTime _entryDate = DateTime.now();
  DateTime _deliveryDate = DateTime.now();
  FarmHarvestEntry? _editingEntry;
  bool _showDeliveryForm = false;
  bool _showProfitCard = false;
  int? _selectedPendingDeliveryId;

  NumberFormat get _currency =>
      Provider.of<AppSettingsProvider?>(context, listen: false)
          ?.currencyFormat ??
      NumberFormat.currency(locale: 'en_PH', symbol: '\u20B1');

  bool get _isSugarcane => _farm.type.toLowerCase().contains('sugar');
  bool get _isFarmInHarvestStatus =>
      FarmOperationsService.isHarvestStatus(_farm);
  bool get _showInteractionDetails =>
      Provider.of<AppSettingsProvider>(context, listen: false)
          .showDetailedDescriptions;

  bool _canEditHarvestBoard([FarmHarvestSession? session]) {
    return _isFarmInHarvestStatus ||
        _startEarlyHarvest ||
        (session?.isEarlyStart ?? false);
  }

  @override
  void initState() {
    super.initState();
    _farm = widget.farm;
    _harvestProvider = FarmHarvestProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBoardData();
    });
  }

  @override
  void dispose() {
    _harvestProvider.dispose();
    _tonsController.dispose();
    _amountController.dispose();
    _labelController.dispose();
    _noteController.dispose();
    _deliveryBatchController.dispose();
    _deliveryTrackingController.dispose();
    _deliveryCompanyController.dispose();
    _deliveryCostController.dispose();
    _deliveryNoteController.dispose();
    _netTonsCaneController.dispose();
    _lkgPerTcController.dispose();
    _planterShareController.dispose();
    _sugarPricePerLkgController.dispose();
    _molassesKgController.dispose();
    _molassesPricePerKgController.dispose();
    _productionCostsController.dispose();
    super.dispose();
  }

  double _parseNumber(String input) =>
      double.tryParse(input.replaceAll(',', '').trim()) ?? 0;

  Future<void> _loadBoardData() async {
    final deliveryProvider =
        Provider.of<DeliveryProvider?>(context, listen: false);
    final profitProvider =
        Provider.of<SugarcaneProfitProvider?>(context, listen: false);
    final activityProvider =
        Provider.of<ActivityProvider?>(context, listen: false);
    await _harvestProvider.loadForFarm(_farm);
    final futures = <Future<void>>[];

    if (deliveryProvider != null) {
      futures.add(deliveryProvider.loadDeliveries());
    }
    if (profitProvider != null) {
      futures.add(profitProvider.loadProfitRecords());
    }
    if (activityProvider != null) {
      futures.add(activityProvider.loadActivities());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _pickEntryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _entryDate = picked;
      });
    }
  }

  void _clearForm() {
    setState(() {
      _entryType = 'delivery';
      _entryDate = DateTime.now();
      _editingEntry = null;
    });
    _tonsController.clear();
    _amountController.clear();
    _labelController.clear();
    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  void _loadEntryForEdit(FarmHarvestEntry entry) {
    final session = _harvestProvider.activeSession;
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Harvest inputs are locked until this farm reaches harvest status.',
      );
      return;
    }
    setState(() {
      _editingEntry = entry;
      _entryType = entry.entryType;
      _entryDate = entry.entryDate;
    });
    _tonsController.text = entry.quantityTons == 0
        ? ''
        : entry.quantityTons.toStringAsFixed(
            entry.quantityTons.truncateToDouble() == entry.quantityTons ? 0 : 2,
          );
    _amountController.text = entry.amount == 0
        ? ''
        : entry.amount.toStringAsFixed(
            entry.amount.truncateToDouble() == entry.amount ? 0 : 2,
          );
    _labelController.text = entry.label;
    _noteController.text = entry.note ?? '';
  }

  Future<void> _refreshFarmRef() async {
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    await farmProvider.refreshFarms();
    final updatedFarm = farmProvider.farms.cast<Farm?>().firstWhere(
          (farm) => farm != null && farm.id == _farm.id,
          orElse: () => null,
        );
    if (updatedFarm != null && mounted) {
      setState(() {
        _farm = updatedFarm;
      });
    }
  }

  Future<void> _refreshBoardAfterRoute() async {
    await _loadBoardData();
    await _refreshFarmRef();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openSugarcaneDeliveryScreen() async {
    final session = _harvestProvider.activeSession;
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Sell Cane stays locked until this farm reaches harvest status.',
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FrmLogistics(
          initialFarmName: _farm.name,
          sugarcaneOnlyMode: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _refreshBoardAfterRoute();
  }

  Future<void> _openSugarcaneProfitCalculator(
    List<Delivery> pendingDeliveries,
  ) async {
    if (pendingDeliveries.isEmpty) {
      return;
    }
    final session = _harvestProvider.activeSession;
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Pending Payment stays locked until this farm reaches harvest status.',
      );
      return;
    }
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HarvestBoardSugarcaneProfitScreen(
          farm: _farm,
          pendingDeliveries: pendingDeliveries,
          closeToFarmTabOnClose: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (result == 'close_to_tab_farm') {
      Navigator.of(context).pop();
      return;
    }
    await _refreshBoardAfterRoute();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String content,
  }) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            Tooltip(
              message: 'Close this dialog without applying the action.',
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ),
            Tooltip(
              message: 'Apply the selected action for this farm or harvest.',
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ),
          ],
        );
      },
    );
    return decision ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChangeNotifierProvider<FarmHarvestProvider>.value(
      value: _harvestProvider,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackdrop(
          isDark: theme.brightness == Brightness.dark,
          child: SafeArea(
            child: Consumer<FarmHarvestProvider>(
              builder: (context, harvestProvider, _) {
                final deliveryProvider = Provider.of<DeliveryProvider?>(
                  context,
                );
                final profitProvider = Provider.of<SugarcaneProfitProvider?>(
                  context,
                );
                final activityProvider = Provider.of<ActivityProvider?>(
                  context,
                );
                final activeSession = harvestProvider.activeSession;
                final activeDeliveries = !_isSugarcane || activeSession == null
                    ? const <Delivery>[]
                    : _sessionSugarcaneDeliveries(
                        session: activeSession,
                        deliveryProvider: deliveryProvider,
                      );
                final pendingDeliveries = !_isSugarcane || activeSession == null
                    ? const <Delivery>[]
                    : _pendingSugarcaneDeliveries(
                        session: activeSession,
                        deliveryProvider: deliveryProvider,
                        profitProvider: profitProvider,
                      );
                final completedProfits = !_isSugarcane || activeSession == null
                    ? const <SugarcaneProfit>[]
                    : _sessionSugarcaneProfits(
                        session: activeSession,
                        deliveryProvider: deliveryProvider,
                        profitProvider: profitProvider,
                      );
                final preHarvestExpenses =
                    !_isSugarcane || activeSession == null
                        ? const <Activity>[]
                        : _preHarvestExpenses(
                            session: activeSession,
                            activityProvider: activityProvider,
                          );
                final activeSummary = activeSession == null
                    ? null
                    : _isSugarcane
                        ? _HarvestSummary.fromSugarcaneProfitRecords(
                            session: activeSession,
                            records: completedProfits,
                            targetTons:
                                FarmOperationsService.projectedYieldTons(_farm),
                            fallbackPricePerTon:
                                _defaultPricePerTon(_farm.type),
                          )
                        : _HarvestSummary.fromSession(
                            session: activeSession,
                            entries: harvestProvider.entriesForSession(
                              activeSession.sessionId!,
                              includeInactive: true,
                            ),
                            targetTons:
                                FarmOperationsService.projectedYieldTons(
                              _farm,
                            ),
                            fallbackPricePerTon:
                                _defaultPricePerTon(_farm.type),
                          );
                final previousSummaries = harvestProvider.completedSessions
                    .take(3)
                    .map(
                      (session) => _isSugarcane
                          ? _HarvestSummary.fromSugarcaneProfitRecords(
                              session: session,
                              records: _sessionSugarcaneProfits(
                                session: session,
                                deliveryProvider: deliveryProvider,
                                profitProvider: profitProvider,
                              ),
                              targetTons:
                                  FarmOperationsService.projectedYieldTons(
                                _farm,
                              ),
                              fallbackPricePerTon:
                                  _defaultPricePerTon(_farm.type),
                            )
                          : _HarvestSummary.fromSession(
                              session: session,
                              entries: harvestProvider.entriesForSession(
                                session.sessionId!,
                                includeInactive: true,
                              ),
                              targetTons:
                                  FarmOperationsService.projectedYieldTons(
                                _farm,
                              ),
                              fallbackPricePerTon:
                                  _defaultPricePerTon(_farm.type),
                            ),
                    )
                    .toList(growable: false);
                final canEditHarvestBoard = _canEditHarvestBoard(activeSession);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 18),
                      _buildHarvestAccessCard(theme, activeSession),
                      const SizedBox(height: 18),
                      if (harvestProvider.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              color: AppVisuals.primaryGold,
                            ),
                          ),
                        )
                      else ...[
                        if (activeSession == null)
                          _buildStartCard(theme)
                        else ...[
                          _buildHeroCard(theme, activeSummary!),
                          const SizedBox(height: 16),
                          _buildMetricsGrid(theme, activeSummary),
                          if (_isSugarcane) ...[
                            const SizedBox(height: 18),
                            _buildSugarcaneActionsCard(
                              theme,
                              pendingDeliveries: pendingDeliveries,
                              canEdit: canEditHarvestBoard,
                            ),
                            const SizedBox(height: 18),
                            _buildSugarcaneDeliveryReportCard(
                              theme,
                              deliveries: activeDeliveries,
                              completedProfits: completedProfits,
                            ),
                            const SizedBox(height: 18),
                            _buildPreHarvestExpenseFeedCard(
                              theme,
                              session: activeSession,
                              expenses: preHarvestExpenses,
                            ),
                          ] else ...[
                            const SizedBox(height: 18),
                            _buildInputCard(
                              theme,
                              activeSession,
                              canEdit: canEditHarvestBoard,
                            ),
                            const SizedBox(height: 18),
                            _buildEntriesCard(
                              theme,
                              harvestProvider.entriesForSession(
                                activeSession.sessionId!,
                                includeInactive: true,
                              ),
                              canEdit: canEditHarvestBoard,
                            ),
                          ],
                          const SizedBox(height: 18),
                          _buildFinishCard(theme, activeSession),
                        ],
                        const SizedBox(height: 18),
                        _buildHistoryCard(theme, previousSummaries),
                        const SizedBox(height: 18),
                        _buildSeasonActionsCard(theme, activeSession),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startHarvest() async {
    if (!_canEditHarvestBoard()) {
      _showMessage(
        'This farm is not yet in harvest status. Harvest controls stay disabled until the farm reaches harvest status.',
      );
      return;
    }
    try {
      await _harvestProvider.startHarvest(
        _farm,
        isEarlyStart: _startEarlyHarvest,
      );
      _showMessage(
        _startEarlyHarvest
            ? 'Early harvest board started.'
            : 'Harvest board started.',
      );
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _saveEntry(FarmHarvestSession session) async {
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Harvest inputs are locked until this farm reaches harvest status.',
      );
      return;
    }
    final label = _labelController.text.trim();
    final note = _noteController.text.trim();
    final tons = _parseNumber(_tonsController.text);
    final amount = _parseNumber(_amountController.text);
    final requiresTons = _entryType == 'delivery';
    final requiresAmount = _entryType != 'note';

    if (label.isEmpty) {
      _showMessage('Add a label for this input.');
      return;
    }
    if (requiresTons && tons <= 0) {
      _showMessage('Delivery tons must be greater than zero.');
      return;
    }
    if (requiresAmount && amount <= 0) {
      _showMessage('Amount must be greater than zero.');
      return;
    }

    final entry = FarmHarvestEntry(
      entryId: _editingEntry?.entryId,
      sessionId: session.sessionId!,
      entryType: _entryType,
      label: label,
      quantityTons: requiresTons ? tons : 0,
      amount: requiresAmount ? amount : 0,
      entryDate: _entryDate,
      note: note.isEmpty ? null : note,
      isActive: _editingEntry?.isActive ?? true,
      createdAt: _editingEntry?.createdAt ?? DateTime.now(),
      updatedAt: _editingEntry == null ? null : DateTime.now(),
    );

    if (_editingEntry == null) {
      await _harvestProvider.addEntry(_farm, entry);
      _showMessage('Harvest input added.');
    } else {
      await _harvestProvider.updateEntry(_farm, entry);
      _showMessage('Harvest input updated.');
    }
    _clearForm();
  }

  Future<void> _toggleUndoRedo(
    FarmHarvestSession session, {
    required bool redo,
  }) async {
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Harvest inputs are locked until this farm reaches harvest status.',
      );
      return;
    }
    if (redo) {
      await _harvestProvider.redoLastEntry(_farm, session.sessionId!);
      _showMessage('Redo applied.');
    } else {
      await _harvestProvider.undoLastEntry(_farm, session.sessionId!);
      _showMessage('Last input undone.');
    }
  }

  Future<void> _toggleEntry(FarmHarvestEntry entry) async {
    final session = _harvestProvider.activeSession;
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Harvest inputs are locked until this farm reaches harvest status.',
      );
      return;
    }
    await _harvestProvider.setEntryActive(
      _farm,
      entry,
      isActive: !entry.isActive,
    );
    _showMessage(entry.isActive ? 'Input disabled.' : 'Input restored.');
  }

  Future<void> _finishHarvest(FarmHarvestSession session) async {
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Finish Harvest stays disabled until this farm reaches harvest status.',
      );
      return;
    }
    final confirmed = await _confirm(
      title: 'Finish harvest?',
      content:
          'Are you sure you want to end this harvest and move it into season history?',
    );
    if (!confirmed) {
      return;
    }
    await _harvestProvider.finishHarvest(_farm, session);
    _showMessage('Harvest marked complete.');
  }

  Future<void> _restartHarvest(FarmHarvestSession session) async {
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Restart Board stays disabled until this farm reaches harvest status.',
      );
      return;
    }
    final confirmed = await _confirm(
      title: 'Restart harvest board?',
      content:
          'This clears the ongoing entries for the current board and starts the season over.',
    );
    if (!confirmed) {
      return;
    }
    await _harvestProvider.restartHarvest(_farm, session);
    _clearForm();
    _showMessage('Harvest board restarted.');
  }

  Future<void> _advanceToNextSeason() async {
    final confirmed = await _confirm(
      title: 'Continue to next season?',
      content:
          'This resets the farm timeline, starts a new crop season, and refreshes the corresponding guidelines and tips.',
    );
    if (!confirmed) {
      return;
    }
    if (!mounted) {
      return;
    }

    final activeSession = _harvestProvider.activeSession;
    if (activeSession != null) {
      await _harvestProvider.finishHarvest(_farm, activeSession);
    }
    if (!mounted) {
      return;
    }

    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    await farmProvider.advanceToNextSeason(
      _farm,
      incrementRatoon: _isSugarcane,
    );
    await _refreshFarmRef();
    await _harvestProvider.loadForFarm(_farm);
    _clearForm();
    _showMessage('Farm moved to the next season.');
  }

  Future<void> _resetFarmTimeline() async {
    final confirmed = await _confirm(
      title: 'Reset this farm?',
      content:
          'This resets the current farm timeline to today and restarts the current season guidance without moving to the next season.',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    final now = DateTime.now();
    final normalizedDate = DateTime(now.year, now.month, now.day);
    await farmProvider.updateFarm(_farm.copyWith(date: normalizedDate));
    await _refreshFarmRef();
    await _harvestProvider.loadForFarm(_farm);
    _clearForm();
    _showMessage('Farm timeline reset.');
  }

  Future<void> _deleteFarm() async {
    final confirmed = await _confirm(
      title: 'Remove this farm?',
      content:
          'This removes the farm and its harvest board history from the app.',
    );
    if (!confirmed) {
      return;
    }
    if (!mounted) {
      return;
    }
    await _harvestProvider.clearFarmHistory(_farm);
    if (!mounted) {
      return;
    }
    await Provider.of<FarmProvider>(context, listen: false)
        .deleteFarm(_farm.id!);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _setStartEarlyHarvest(bool value) {
    setState(() {
      _startEarlyHarvest = value;
    });
  }

  Future<void> _setEarlyHarvestEnabled(
    bool value, {
    FarmHarvestSession? activeSession,
  }) async {
    if (activeSession == null) {
      _setStartEarlyHarvest(value);
      return;
    }
    await _harvestProvider.updateEarlyStart(
      _farm,
      activeSession,
      isEarlyStart: value,
    );
    if (!mounted) {
      return;
    }
    _showMessage(
      value ? 'Early harvest enabled.' : 'Early harvest disabled.',
    );
  }

  void _setEntryType(String value) {
    setState(() {
      _entryType = value;
    });
  }

  void _selectPendingDeliveryId(int? value) {
    setState(() {
      _selectedPendingDeliveryId = value;
    });
  }

  void _setProfitCardVisible(bool value) {
    setState(() {
      _showProfitCard = value;
    });
  }

  String _normalizedValue(String input) => input.trim().toLowerCase();

  bool _matchesFarm(String value) =>
      _normalizedValue(value) == _normalizedValue(_farm.name);

  bool _deliveryMatchesFarm(Delivery delivery) {
    if (_matchesFarm(delivery.name)) {
      return true;
    }
    final note = _normalizedValue(delivery.note ?? '');
    final farmName = _normalizedValue(_farm.name);
    return note.contains('farm: $farmName') ||
        note.contains('farm/batch: $farmName') ||
        note.contains('farm name: $farmName');
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isWithinSession(DateTime value, FarmHarvestSession session) {
    final current = _dateOnly(value);
    final start = _dateOnly(session.startedAt);
    final end =
        session.completedAt == null ? null : _dateOnly(session.completedAt!);
    if (current.isBefore(start)) {
      return false;
    }
    if (end != null && current.isAfter(end)) {
      return false;
    }
    return true;
  }

  List<Delivery> _sessionSugarcaneDeliveries({
    required FarmHarvestSession session,
    required DeliveryProvider? deliveryProvider,
  }) {
    final deliveries =
        deliveryProvider?.sugarcaneDeliveries ?? const <Delivery>[];
    final filtered = deliveries.where((delivery) {
      return _deliveryMatchesFarm(delivery) &&
          _isWithinSession(delivery.date, session);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  List<SugarcaneProfit> _sessionSugarcaneProfits({
    required FarmHarvestSession session,
    required DeliveryProvider? deliveryProvider,
    required SugarcaneProfitProvider? profitProvider,
  }) {
    final sessionDeliveryIds = _sessionSugarcaneDeliveries(
      session: session,
      deliveryProvider: deliveryProvider,
    ).map((delivery) => delivery.delId).whereType<int>().toSet();

    final records = profitProvider?.records ?? const <SugarcaneProfit>[];
    final filtered = records.where((record) {
      if (!_isWithinSession(record.deliveryDate, session)) {
        return false;
      }
      final linkedByDelivery = record.deliveryId != null &&
          sessionDeliveryIds.contains(record.deliveryId);
      return linkedByDelivery || _matchesFarm(record.farmName);
    }).toList()
      ..sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));
    return filtered;
  }

  List<Delivery> _pendingSugarcaneDeliveries({
    required FarmHarvestSession session,
    required DeliveryProvider? deliveryProvider,
    required SugarcaneProfitProvider? profitProvider,
  }) {
    final linkedIds = profitProvider?.linkedDeliveryIds ?? const <int>{};
    return _sessionSugarcaneDeliveries(
      session: session,
      deliveryProvider: deliveryProvider,
    ).where((delivery) {
      final deliveryId = delivery.delId;
      if (deliveryId == null) {
        return false;
      }
      return !linkedIds.contains(deliveryId);
    }).toList(growable: false);
  }

  List<Activity> _preHarvestExpenses({
    required FarmHarvestSession session,
    required ActivityProvider? activityProvider,
  }) {
    final activities = activityProvider?.activities ?? const <Activity>[];
    final filtered = activities.where((activity) {
      return _matchesFarm(activity.farm) &&
          activity.total > 0 &&
          activity.date.isBefore(session.startedAt);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  double _sumActivityTotals(Iterable<Activity> activities) {
    return activities.fold<double>(
      0,
      (sum, activity) => sum + activity.total,
    );
  }

  String _extractTaggedValue(String? note, String tag) {
    final raw = note?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    for (final part in raw.split('|')) {
      final trimmed = part.trim();
      if (trimmed.toLowerCase().startsWith('${tag.toLowerCase()}:')) {
        return trimmed.substring(tag.length + 1).trim();
      }
    }
    return '';
  }

  String _deliveryReportLabel(Delivery delivery) {
    final batch = _extractTaggedValue(delivery.note, 'Batch');
    if (batch.isNotEmpty) {
      return batch;
    }
    return delivery.name;
  }

  void _toggleDeliveryForm() {
    setState(() {
      _showDeliveryForm = !_showDeliveryForm;
      if (_showDeliveryForm) {
        _showProfitCard = false;
      }
    });
  }

  // ignore: unused_element
  void _toggleProfitCard(List<Delivery> pendingDeliveries) {
    if (pendingDeliveries.isEmpty) {
      return;
    }
    setState(() {
      _showProfitCard = !_showProfitCard;
      if (_showProfitCard) {
        _showDeliveryForm = false;
        _selectedPendingDeliveryId ??= pendingDeliveries.first.delId;
      }
    });
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _deliveryDate = picked;
      });
    }
  }

  String _buildHarvestDeliveryNote({
    required String company,
    required String batch,
    required String tracking,
    required String note,
  }) {
    final parts = <String>[
      'Created from Harvest Board',
      'Farm: ${_farm.name}',
      if (batch.isNotEmpty) 'Batch: $batch',
      if (company.isNotEmpty) 'Company: $company',
      if (tracking.isNotEmpty) 'Tracking #: $tracking',
      if (note.isNotEmpty) note,
    ];
    return parts.join(' | ');
  }

  Future<void> _saveSugarcaneDelivery() async {
    final session = _harvestProvider.activeSession;
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Harvest inputs are locked until this farm reaches harvest status.',
      );
      return;
    }
    final batch = _deliveryBatchController.text.trim();
    final tracking = _deliveryTrackingController.text.trim();
    final company = _deliveryCompanyController.text.trim();
    final cost = _parseNumber(_deliveryCostController.text);
    final note = _deliveryNoteController.text.trim();

    if (batch.isEmpty) {
      _showMessage('Delivery / batch name is required.');
      return;
    }
    if (tracking.isEmpty) {
      _showMessage('Trucking / tracking number is required.');
      return;
    }
    if (cost <= 0) {
      _showMessage('Total cost must be greater than zero.');
      return;
    }

    final deliveryNote = _buildHarvestDeliveryNote(
      company: company,
      batch: batch,
      tracking: tracking,
      note: note,
    );
    final activity = Activity(
      jobId:
          'TRK-${tracking.isEmpty ? DateTime.now().millisecondsSinceEpoch : tracking}',
      tag: 'Logistics',
      date: _deliveryDate,
      farm: _farm.name,
      name: 'Trucking: ${company.isEmpty ? 'Unspecified' : company}',
      labor: 'Logistics',
      assetUsed: tracking,
      costType: 'Expense',
      duration: 1,
      cost: cost,
      total: cost,
      worker: company,
      note: deliveryNote,
    );
    final delivery = Delivery(
      date: _deliveryDate,
      type: 'Sugarcane',
      name: _farm.name,
      ticketNo: tracking,
      cost: null,
      quantity: 0,
      total: 0,
      note: deliveryNote,
    );

    await DatabaseHelper.instance.runInTransaction((txn) async {
      await txn.insert(DatabaseHelper.tableActivities, activity.toMap());
      await txn.insert(DatabaseHelper.tableDeliveries, delivery.toMap());
    });

    await _loadBoardData();
    if (!mounted) {
      return;
    }
    setState(() {
      _deliveryDate = DateTime.now();
      _deliveryBatchController.clear();
      _deliveryTrackingController.clear();
      _deliveryCompanyController.clear();
      _deliveryCostController.clear();
      _deliveryNoteController.clear();
      _showDeliveryForm = false;
    });
    _showMessage('Sugarcane delivery added to the harvest board queue.');
  }

  void _applyPendingDelivery(Delivery? delivery) {
    if (delivery == null) {
      return;
    }
    if (delivery.quantity > 0) {
      _netTonsCaneController.text = delivery.quantity.toStringAsFixed(
        delivery.quantity.truncateToDouble() == delivery.quantity ? 0 : 2,
      );
    }
  }

  _SugarcaneProfitDraft _profitDraftForInput() {
    final netTonsCane = _parseNumber(_netTonsCaneController.text);
    final lkgPerTc = _parseNumber(_lkgPerTcController.text);
    final planterShare = _parseNumber(_planterShareController.text);
    final sugarPricePerLkg = _parseNumber(_sugarPricePerLkgController.text);
    final molassesKg = _parseNumber(_molassesKgController.text);
    final molassesPricePerKg = _parseNumber(_molassesPricePerKgController.text);
    final productionCosts = _parseNumber(_productionCostsController.text);
    final planterShareDecimal = planterShare / 100;
    final sugarProceeds =
        netTonsCane * lkgPerTc * planterShareDecimal * sugarPricePerLkg;
    final molassesProceeds = molassesKg * molassesPricePerKg;
    final totalRevenue = sugarProceeds + molassesProceeds;
    final netProfit = totalRevenue - productionCosts;

    return _SugarcaneProfitDraft(
      netTonsCane: netTonsCane,
      lkgPerTc: lkgPerTc,
      planterShare: planterShare,
      sugarPricePerLkg: sugarPricePerLkg,
      molassesKg: molassesKg,
      molassesPricePerKg: molassesPricePerKg,
      productionCosts: productionCosts,
      sugarProceeds: sugarProceeds,
      molassesProceeds: molassesProceeds,
      totalRevenue: totalRevenue,
      netProfit: netProfit,
    );
  }

  Future<void> _savePendingSugarcaneProfit(
      List<Delivery> pendingDeliveries) async {
    final session = _harvestProvider.activeSession;
    if (!_canEditHarvestBoard(session)) {
      _showMessage(
        'Harvest inputs are locked until this farm reaches harvest status.',
      );
      return;
    }
    final selectedDelivery = pendingDeliveries.cast<Delivery?>().firstWhere(
          (delivery) => delivery?.delId == _selectedPendingDeliveryId,
          orElse: () => null,
        );
    if (selectedDelivery == null) {
      _showMessage('Select a pending delivery first.');
      return;
    }

    final draft = _profitDraftForInput();
    if (draft.netTonsCane <= 0) {
      _showMessage('Net Weight of Cane must be greater than zero.');
      return;
    }
    if (draft.lkgPerTc <= 0) {
      _showMessage('LKG/TC must be greater than zero.');
      return;
    }
    if (draft.planterShare <= 0) {
      _showMessage('Planter Share must be greater than zero.');
      return;
    }
    if (draft.sugarPricePerLkg <= 0) {
      _showMessage('Sugar Price per LKG must be greater than zero.');
      return;
    }
    if (draft.productionCosts <= 0) {
      _showMessage('Production Costs Per Delivery must be greater than zero.');
      return;
    }

    final profitRecord = SugarcaneProfit(
      deliveryId: selectedDelivery.delId,
      sourceType: 'harvest_board',
      sourceLabel: _deliveryReportLabel(selectedDelivery),
      sourceStatus: 'completed',
      farmName: _farm.name,
      deliveryDate: selectedDelivery.date,
      netTonsCane: draft.netTonsCane,
      lkgPerTc: draft.lkgPerTc,
      planterShare: draft.planterShare,
      sugarPricePerLkg: draft.sugarPricePerLkg,
      molassesKg: draft.molassesKg,
      molassesPricePerKg: draft.molassesPricePerKg,
      productionCosts: draft.productionCosts,
      sugarProceeds: draft.sugarProceeds,
      molassesProceeds: draft.molassesProceeds,
      totalRevenue: draft.totalRevenue,
      netProfit: draft.netProfit,
      note: selectedDelivery.note,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.runInTransaction((txn) async {
      await txn.insert(
        DatabaseHelper.tableSugarcaneProfits,
        profitRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        DatabaseHelper.tableDeliveries,
        <String, Object?>{
          'Quantity': draft.netTonsCane,
          'Total': draft.totalRevenue,
        },
        where: 'DelID = ?',
        whereArgs: <Object?>[selectedDelivery.delId],
      );
    });

    await _loadBoardData();
    if (!mounted) {
      return;
    }
    final remainingPending = _pendingSugarcaneDeliveries(
      session: _harvestProvider.activeSession!,
      deliveryProvider: Provider.of<DeliveryProvider?>(context, listen: false),
      profitProvider:
          Provider.of<SugarcaneProfitProvider?>(context, listen: false),
    );
    setState(() {
      _netTonsCaneController.clear();
      _lkgPerTcController.clear();
      _planterShareController.clear();
      _sugarPricePerLkgController.clear();
      _molassesKgController.clear();
      _molassesPricePerKgController.clear();
      _productionCostsController.clear();
      _selectedPendingDeliveryId =
          remainingPending.isEmpty ? null : remainingPending.first.delId;
      _showProfitCard = remainingPending.isNotEmpty;
    });
    _showMessage('Pending delivery posted to the harvest board.');
  }
}

extension on _FarmHarvestBoardScreenState {
  Widget _buildHeader(ThemeData theme) {
    final targetTons = FarmOperationsService.projectedYieldTons(_farm);
    final ageInDays = FarmOperationsService.cropAgeInDays(_farm.date);
    final stage = FarmOperationsService.growthStage(_farm.type, ageInDays);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: 'Return to the farm list.',
          child: FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_farm.type.toUpperCase()} HARVEST BOARD',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _farm.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppVisuals.textForest,
                ),
              ),
              if (!_isSugarcane) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetaPill(
                      label: 'Season ${_farm.seasonNumber}',
                      icon: Icons.timeline_rounded,
                    ),
                    _MetaPill(
                      label: '${targetTons.toStringAsFixed(1)} t target',
                      icon: Icons.flag_rounded,
                    ),
                    _MetaPill(
                      label: stage,
                      icon: Icons.auto_graph_rounded,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHarvestAccessCard(
    ThemeData theme,
    FarmHarvestSession? activeSession,
  ) {
    final showDetails = _showInteractionDetails;
    final targetWindow = FarmOperationsService.harvestWindow(_farm);
    final earlyHarvestEnabled =
        activeSession?.isEarlyStart ?? _startEarlyHarvest;
    final accessLabel = _isFarmInHarvestStatus
        ? 'Harvest Status Active'
        : earlyHarvestEnabled
            ? 'Early Harvest Ready'
            : 'Pre-Harvest Lock';
    final accessMessage = _isFarmInHarvestStatus
        ? 'This farm is already in harvest status. Harvest Board inputs are enabled.'
        : earlyHarvestEnabled
            ? 'Harvest Now is enabled. You can start and manage the board before the normal harvest status window.'
            : 'This farm is not yet in harvest status. Inputs stay disabled until the farm reaches harvest status or Harvest Now is enabled.';

    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harvest access',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              accessMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InlineTag(label: accessLabel),
              if (targetWindow != null)
                _InlineTag(
                  label:
                      'Window ${DateFormat('MMM d').format(targetWindow.start)} - ${DateFormat('MMM d, y').format(targetWindow.end)}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: earlyHarvestEnabled,
            contentPadding: EdgeInsets.zero,
            title: const Text('Harvest Now'),
            subtitle: showDetails
                ? Text(
                    _isFarmInHarvestStatus
                        ? 'This flag can still be reviewed for the current board.'
                        : earlyHarvestEnabled
                            ? 'The board can be started before the normal harvest window.'
                            : 'Turn this on to allow harvest before the normal harvest status window.',
                  )
                : null,
            onChanged: (value) => _setEarlyHarvestEnabled(
              value,
              activeSession: activeSession,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartCard(ThemeData theme) {
    final showDetails = _showInteractionDetails;
    final targetWindow = FarmOperationsService.harvestWindow(_farm);
    final canStartHarvest = _canEditHarvestBoard();
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.86),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start harvest tracking',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              _isSugarcane
                  ? 'This is the official harvest calculation and recording board for the farm, including tons delivered, live income, expenses, previous seasons, and target performance.'
                  : 'This is the official harvest calculation and recording board for the farm, with history, target yield, and live variance per season.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),
          if (targetWindow != null)
            Text(
              'Standard harvest window: ${DateFormat('MMM d, y').format(targetWindow.start)} to ${DateFormat('MMM d, y').format(targetWindow.end)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppVisuals.textForestMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 16),
          if (!canStartHarvest)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Harvest controls unlock only after this farm reaches harvest status, unless Harvest Now is turned on.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (!canStartHarvest) const SizedBox(height: 10),
          Tooltip(
            message: 'Create the live harvest board for this farm and season.',
            child: FilledButton.icon(
              onPressed: canStartHarvest ? _startHarvest : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Harvest Board'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme, _HarvestSummary summary) {
    final profitPositive = summary.netProfit >= 0;
    final variancePositive = summary.profitGap >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: profitPositive
              ? <Color>[
                  theme.colorScheme.secondary,
                  theme.colorScheme.primary,
                ]
              : <Color>[
                  theme.colorScheme.error,
                  theme.colorScheme.errorContainer,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroTag(
                  label: summary.session.isCompleted ? 'Completed' : 'Ongoing'),
              if (summary.session.isEarlyStart)
                const _HeroTag(label: 'Early Harvest'),
              _HeroTag(label: 'Season ${summary.session.seasonNumber}'),
              if (_isSugarcane)
                _HeroTag(label: 'Ratoon ${summary.session.ratoonCount}'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Live Net Harvest',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currency.format(summary.netProfit),
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${summary.deliveredTons.toStringAsFixed(2)} tons delivered so far. ${variancePositive ? 'Ahead' : 'Behind'} target profit by ${_currency.format(summary.profitGap.abs())}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme, _HarvestSummary summary) {
    final metrics = <_MetricItem>[
      _MetricItem(
        label: 'Delivered Tons',
        value: summary.deliveredTons.toStringAsFixed(2),
        icon: Icons.local_shipping_rounded,
      ),
      _MetricItem(
        label: 'Live Income',
        value: _currency.format(summary.income),
        icon: Icons.payments_rounded,
      ),
      _MetricItem(
        label: 'Expenses',
        value: _currency.format(summary.expenses),
        icon: Icons.receipt_long_rounded,
      ),
      _MetricItem(
        label: 'Target Yield',
        value: '${summary.targetTons.toStringAsFixed(1)} t',
        icon: Icons.flag_rounded,
      ),
      _MetricItem(
        label: 'Yield Difference',
        value:
            '${summary.tonsGap >= 0 ? '+' : '-'}${summary.tonsGap.abs().toStringAsFixed(2)} t',
        icon: Icons.compare_arrows_rounded,
      ),
      _MetricItem(
        label: 'Target Profit',
        value: _currency.format(summary.targetProfit),
        icon: Icons.trending_up_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920 ? 3 : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: FrostedPanel(
                    radius: 24,
                    padding: const EdgeInsets.all(18),
                    color: theme.colorScheme.surface.withValues(alpha: 0.88),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(metric.icon, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          metric.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppVisuals.textForestMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          metric.value,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppVisuals.textForest,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildSugarcaneActionsCard(
    ThemeData theme, {
    required List<Delivery> pendingDeliveries,
    required bool canEdit,
  }) {
    final showDetails = _showInteractionDetails;
    final pendingCount = pendingDeliveries.length;
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harvest actions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              'Use Sell Cane to record one sugarcane truckload for this farm. Open Pending Payment to complete the sugarcane income and trucking expense entry on a separate screen.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: canEdit ? _openSugarcaneDeliveryScreen : null,
                icon: const Icon(Icons.local_shipping_rounded),
                label: const Text('Sell Cane'),
              ),
              FilledButton.tonalIcon(
                onPressed: !canEdit || pendingCount == 0
                    ? null
                    : () => _openSugarcaneProfitCalculator(pendingDeliveries),
                icon: const Icon(Icons.request_quote_rounded),
                label: Text(
                  pendingCount == 0
                      ? 'Pending Payment'
                      : 'Pending Payment ($pendingCount)',
                ),
              ),
            ],
          ),
          if (!canEdit) ...[
            const SizedBox(height: 12),
            Text(
              'Inputs are locked because this farm is not yet in harvest status.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSugarcaneDeliveryFormCard(ThemeData theme) {
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery option',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These are the sugarcane delivery fields used in the deliveries screen, now available directly inside the harvest board.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Date',
                  child: InkWell(
                    onTap: _pickDeliveryDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(),
                      child: Text(DateFormat('MMM d, y').format(_deliveryDate)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: 'Farm',
                  child: InputDecorator(
                    decoration: const InputDecoration(),
                    child: Text(_farm.name),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Delivery / Batch Name',
            child: TextField(
              controller: _deliveryBatchController,
              decoration: const InputDecoration(
                hintText: 'Enter the delivery or batch name',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Trucking / Tracking Number',
                  child: TextField(
                    controller: _deliveryTrackingController,
                    decoration: const InputDecoration(
                      hintText: 'Tracking number',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: 'Association/Buyer',
                  child: TextField(
                    controller: _deliveryCompanyController,
                    decoration: const InputDecoration(
                      hintText: 'Association or buyer',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Total Cost (Fuel, Allowance, etc.)',
            child: TextField(
              controller: _deliveryCostController,
              inputFormatters: <TextInputFormatter>[
                _FarmHarvestBoardScreenState._numberFormatter,
              ],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Enter total delivery cost',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Notes / Comments',
            child: TextField(
              controller: _deliveryNoteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Optional notes for this dispatch',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _saveSugarcaneDelivery,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Queue Delivery'),
              ),
              TextButton(
                onPressed: _toggleDeliveryForm,
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSugarcaneDeliveryReportCard(
    ThemeData theme, {
    required List<Delivery> deliveries,
    required List<SugarcaneProfit> completedProfits,
  }) {
    final showDetails = _showInteractionDetails;
    final completedIds = completedProfits
        .map((record) => record.deliveryId)
        .whereType<int>()
        .toSet();
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery report',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              'Live report for the farm being harvested, including queued and completed sugarcane dispatches.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),
          if (deliveries.isEmpty)
            Text(
              'No delivery records are queued for this harvest yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            )
          else
            ...deliveries.map((delivery) {
              final isCompleted = delivery.delId != null &&
                  completedIds.contains(delivery.delId);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppVisuals.cloudGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCompleted
                        ? theme.colorScheme.primary.withValues(alpha: 0.18)
                        : theme.colorScheme.tertiary.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          _deliveryReportLabel(delivery),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppVisuals.textForest,
                          ),
                        ),
                        _InlineTag(
                          label: isCompleted ? 'Completed' : 'Pending',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${DateFormat('MMM d, y').format(delivery.date)}  |  Tracking ${delivery.ticketNo?.trim().isEmpty ?? true ? 'Pending' : delivery.ticketNo!.trim()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForestMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((delivery.note?.trim().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 6),
                      Text(
                        delivery.note!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppVisuals.textForestMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreHarvestExpenseFeedCard(
    ThemeData theme, {
    required FarmHarvestSession session,
    required List<Activity> expenses,
  }) {
    final showDetails = _showInteractionDetails;
    final totalExpenses = _sumActivityTotals(expenses);
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pre-harvest expense feed',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              'Live feed of expenses that were recorded before this harvest started on ${DateFormat('MMM d, y').format(session.startedAt)}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 10),
          Text(
            _currency.format(totalExpenses),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          if (expenses.isEmpty)
            Text(
              'No pre-harvest expenses are recorded for this farm.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            )
          else
            ...expenses.take(5).map(
                  (activity) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppVisuals.cloudGlass,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppVisuals.textForest,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('MMM d, y').format(activity.date)}  |  ${_currency.format(activity.total)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppVisuals.textForestMuted,
                                ),
                              ),
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

  // ignore: unused_element
  Widget _buildSugarcaneProfitCard(
    ThemeData theme, {
    required List<Delivery> pendingDeliveries,
  }) {
    final selectedDelivery = pendingDeliveries.cast<Delivery?>().firstWhere(
          (delivery) => delivery?.delId == _selectedPendingDeliveryId,
          orElse: () => null,
        );
    final draft = _profitDraftForInput();
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sugarcane profit calculator',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This card is enabled because pending deliveries exist. The fields below match the sugarcane profit tools.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SearchableDropdownFormField<int>(
            initialValue: pendingDeliveries.any(
              (delivery) => delivery.delId == _selectedPendingDeliveryId,
            )
                ? _selectedPendingDeliveryId
                : null,
            decoration: const InputDecoration(
              labelText: 'Pending delivery',
            ),
            items: pendingDeliveries
                .where((delivery) => delivery.delId != null)
                .map(
                  (delivery) => DropdownMenuItem<int>(
                    value: delivery.delId!,
                    child: Text(
                      '${_deliveryReportLabel(delivery)} | ${delivery.ticketNo?.trim().isEmpty ?? true ? 'Tracking pending' : delivery.ticketNo!.trim()} | ${DateFormat('MMM d, y').format(delivery.date)}',
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              final delivery = pendingDeliveries.cast<Delivery?>().firstWhere(
                    (item) => item?.delId == value,
                    orElse: () => null,
                  );
              _selectPendingDeliveryId(value);
              _applyPendingDelivery(delivery);
            },
          ),
          const SizedBox(height: 16),
          _buildSugarcaneProfitInputs(theme),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppVisuals.cloudGlass,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedDelivery == null
                      ? 'Select a pending delivery to complete the profit entry.'
                      : 'Linked to ${_deliveryReportLabel(selectedDelivery)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppVisuals.textForest,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sugar Proceeds: ${_currency.format(draft.sugarProceeds)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
                Text(
                  'Molasses Proceeds: ${_currency.format(draft.molassesProceeds)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
                Text(
                  'Total Revenue: ${_currency.format(draft.totalRevenue)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
                Text(
                  'Net Profit: ${_currency.format(draft.netProfit)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _savePendingSugarcaneProfit(pendingDeliveries),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Post to Harvest Board'),
              ),
              TextButton(
                onPressed: () {
                  _setProfitCardVisible(false);
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSugarcaneProfitInputs(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Net Weight of Cane',
                child: TextField(
                  controller: _netTonsCaneController,
                  inputFormatters: <TextInputFormatter>[
                    _FarmHarvestBoardScreenState._numberFormatter,
                  ],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Example: 100',
                    suffixText: 'tons',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LabeledField(
                label: 'LKG/TC',
                child: TextField(
                  controller: _lkgPerTcController,
                  inputFormatters: <TextInputFormatter>[
                    _FarmHarvestBoardScreenState._numberFormatter,
                  ],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Example: 1.90',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Planter Share',
                child: TextField(
                  controller: _planterShareController,
                  inputFormatters: <TextInputFormatter>[
                    _FarmHarvestBoardScreenState._numberFormatter,
                  ],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Example: 70',
                    suffixText: '%',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LabeledField(
                label: 'Sugar Price per LKG',
                child: TextField(
                  controller: _sugarPricePerLkgController,
                  inputFormatters: <TextInputFormatter>[
                    _FarmHarvestBoardScreenState._numberFormatter,
                  ],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Example: 50',
                    prefixText: _currency.currencySymbol,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Molasses Quantity',
                child: TextField(
                  controller: _molassesKgController,
                  inputFormatters: <TextInputFormatter>[
                    _FarmHarvestBoardScreenState._numberFormatter,
                  ],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Optional',
                    suffixText: 'kg',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LabeledField(
                label: 'Molasses Price per kg',
                child: TextField(
                  controller: _molassesPricePerKgController,
                  inputFormatters: <TextInputFormatter>[
                    _FarmHarvestBoardScreenState._numberFormatter,
                  ],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Optional',
                    prefixText: _currency.currencySymbol,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LabeledField(
          label: 'Production Costs Per Delivery',
          child: TextField(
            controller: _productionCostsController,
            inputFormatters: <TextInputFormatter>[
              _FarmHarvestBoardScreenState._numberFormatter,
            ],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Example: 35000',
              prefixText: _currency.currencySymbol,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeProfitCards(
    ThemeData theme, {
    required bool canEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfitToolSectionCard(
          theme,
          title: 'Harvest Inputs',
          subtitle: 'Production volume and planter share',
          children: [
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'Net Weight of Cane',
                    child: TextField(
                      controller: _netTonsCaneController,
                      enabled: canEdit,
                      inputFormatters: <TextInputFormatter>[
                        _FarmHarvestBoardScreenState._numberFormatter,
                      ],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Example: 100',
                        suffixText: 'tons',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledField(
                    label: 'LKG/TC',
                    child: TextField(
                      controller: _lkgPerTcController,
                      enabled: canEdit,
                      inputFormatters: <TextInputFormatter>[
                        _FarmHarvestBoardScreenState._numberFormatter,
                      ],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Example: 1.90',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'Planter Share',
              child: TextField(
                controller: _planterShareController,
                enabled: canEdit,
                inputFormatters: <TextInputFormatter>[
                  _FarmHarvestBoardScreenState._numberFormatter,
                ],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'Example: 70',
                  suffixText: '%',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildProfitToolSectionCard(
          theme,
          title: 'Market Returns',
          subtitle: 'Sugar and optional molasses pricing',
          children: [
            _LabeledField(
              label: 'Sugar Price per LKG',
              child: TextField(
                controller: _sugarPricePerLkgController,
                enabled: canEdit,
                inputFormatters: <TextInputFormatter>[
                  _FarmHarvestBoardScreenState._numberFormatter,
                ],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Example: 50',
                  prefixText: _currency.currencySymbol,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'Molasses Quantity',
                    child: TextField(
                      controller: _molassesKgController,
                      enabled: canEdit,
                      inputFormatters: <TextInputFormatter>[
                        _FarmHarvestBoardScreenState._numberFormatter,
                      ],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Optional',
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledField(
                    label: 'Molasses Price per kg',
                    child: TextField(
                      controller: _molassesPricePerKgController,
                      enabled: canEdit,
                      inputFormatters: <TextInputFormatter>[
                        _FarmHarvestBoardScreenState._numberFormatter,
                      ],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Optional',
                        prefixText: _currency.currencySymbol,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfitToolSectionCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputCard(
    ThemeData theme,
    FarmHarvestSession session, {
    required bool canEdit,
  }) {
    final showDetails = _showInteractionDetails;
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _editingEntry == null
                      ? 'Harvest inputs'
                      : 'Edit harvest input',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppVisuals.textForest,
                  ),
                ),
              ),
              if (_editingEntry != null)
                Tooltip(
                  message:
                      'Stop editing this input and restore the form for a new entry.',
                  child: TextButton(
                    onPressed: canEdit ? _clearForm : null,
                    child: const Text('Cancel Edit'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!canEdit && showDetails) ...[
            Text(
              'This farm is not yet in harvest status. Harvest inputs stay read-only until the farm reaches harvest status.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <String>['delivery', 'income', 'expense', 'note']
                .map(
                  (type) => ChoiceChip(
                    tooltip:
                        'Switch the entry form to ${_entryTypeLabel(type).toLowerCase()} mode.',
                    label: Text(_entryTypeLabel(type)),
                    selected: _entryType == type,
                    onSelected: canEdit ? (_) => _setEntryType(type) : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Association/Buyer',
                  child: TextField(
                    controller: _labelController,
                    enabled: canEdit,
                    decoration: const InputDecoration(
                      hintText: 'Association, buyer, or income source',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: 'Date',
                  child: InkWell(
                    onTap: canEdit ? _pickEntryDate : null,
                    child: InputDecorator(
                      decoration: const InputDecoration(),
                      child: Text(DateFormat('MMM d, y').format(_entryDate)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'Tons',
                  child: TextField(
                    controller: _tonsController,
                    enabled: canEdit && _entryType == 'delivery',
                    inputFormatters: <TextInputFormatter>[
                      _FarmHarvestBoardScreenState._numberFormatter,
                    ],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: _entryType == 'delivery'
                          ? 'Delivered tons'
                          : 'Only used for delivery',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledField(
                  label: 'Amount',
                  child: TextField(
                    controller: _amountController,
                    enabled: canEdit && _entryType != 'note',
                    inputFormatters: <TextInputFormatter>[
                      _FarmHarvestBoardScreenState._numberFormatter,
                    ],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: _entryType == 'note'
                          ? 'Notes only'
                          : 'Income, expense, or delivery amount',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Note',
            child: TextField(
              controller: _noteController,
              enabled: canEdit,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Additional expense details, delivery remarks, or harvest notes',
              ),
            ),
          ),
          if (_entryType == 'income') ...[
            const SizedBox(height: 18),
            _buildIncomeProfitCards(theme, canEdit: canEdit),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Tooltip(
                message: _editingEntry == null
                    ? 'Add this harvest input to the live board totals.'
                    : 'Save changes to the selected harvest input.',
                child: FilledButton.icon(
                  onPressed: canEdit ? () => _saveEntry(session) : null,
                  icon: Icon(
                    _editingEntry == null
                        ? Icons.add_circle_outline_rounded
                        : Icons.save_rounded,
                  ),
                  label: Text(
                    _editingEntry == null ? 'Add Input' : 'Update Input',
                  ),
                ),
              ),
              Tooltip(
                message:
                    'Temporarily remove the latest active harvest input from the totals.',
                child: OutlinedButton.icon(
                  onPressed: canEdit
                      ? () => _toggleUndoRedo(session, redo: false)
                      : null,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Undo Last'),
                ),
              ),
              Tooltip(
                message: 'Restore the most recently undone harvest input.',
                child: OutlinedButton.icon(
                  onPressed: canEdit
                      ? () => _toggleUndoRedo(session, redo: true)
                      : null,
                  icon: const Icon(Icons.redo_rounded),
                  label: const Text('Redo Last'),
                ),
              ),
              Tooltip(
                message:
                    'Clear the current form fields without changing saved inputs.',
                child: TextButton(
                  onPressed: canEdit ? _clearForm : null,
                  child: const Text('Clear Form'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesCard(
    ThemeData theme,
    List<FarmHarvestEntry> entries, {
    required bool canEdit,
  }) {
    final showDetails = _showInteractionDetails;
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent inputs',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              'Use edit for corrections, disable an entry to remove it from the live totals, and use undo/redo for the latest entry sequence.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'No harvest inputs recorded yet for this season.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            )
          else
            ...entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: entry.isActive
                      ? AppVisuals.cloudGlass
                      : AppVisuals.cloudGlass.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: entry.isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.22)
                        : theme.colorScheme.outline.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                      foregroundColor: theme.colorScheme.primary,
                      child: Icon(_entryTypeIcon(entry.entryType), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Text(
                                entry.label,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppVisuals.textForest,
                                  decoration: entry.isActive
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              _InlineTag(
                                  label: _entryTypeLabel(entry.entryType)),
                              if (!entry.isActive)
                                const _InlineTag(label: 'Excluded'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${DateFormat('MMM d, y').format(entry.entryDate)}'
                            '${entry.quantityTons > 0 ? '  |  ${entry.quantityTons.toStringAsFixed(2)} tons' : ''}'
                            '${entry.amount > 0 ? '  |  ${_currency.format(entry.amount)}' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppVisuals.textForestMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if ((entry.note ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              entry.note!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppVisuals.textForestMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        IconButton(
                          tooltip: 'Edit input',
                          onPressed:
                              canEdit ? () => _loadEntryForEdit(entry) : null,
                          icon: const Icon(Icons.edit_rounded),
                        ),
                        IconButton(
                          tooltip: entry.isActive
                              ? 'Disable input'
                              : 'Restore input',
                          onPressed: canEdit ? () => _toggleEntry(entry) : null,
                          icon: Icon(
                            entry.isActive
                                ? Icons.remove_circle_outline_rounded
                                : Icons.restore_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinishCard(ThemeData theme, FarmHarvestSession session) {
    final showDetails = _showInteractionDetails;
    final canManageHarvest = _canEditHarvestBoard(session);
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.isCompleted ? 'Harvest completed' : 'Finish this harvest',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              session.isCompleted
                  ? 'This season is already closed. You can restart the board if it needs to be re-entered, or move the farm to the next season.'
                  : 'Close the board when the harvest is complete. The season stays in history for comparison against the next harvest.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 12),
          if (!canManageHarvest && !session.isCompleted) ...[
            Text(
              'Finish Harvest and Restart Board stay disabled until this farm reaches harvest status.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!session.isCompleted)
                Tooltip(
                  message:
                      'Mark this harvest as complete and move it into season history.',
                  child: FilledButton.icon(
                    onPressed:
                        canManageHarvest ? () => _finishHarvest(session) : null,
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Finish Harvest'),
                  ),
                ),
              Tooltip(
                message:
                    'Clear the current board entries and restart harvest tracking for this season.',
                child: OutlinedButton.icon(
                  onPressed:
                      canManageHarvest ? () => _restartHarvest(session) : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Restart Board'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    ThemeData theme,
    List<_HarvestSummary> previousSummaries,
  ) {
    final showDetails = _showInteractionDetails;
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Previous harvests',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              'Compare completed seasons against the current target tons per hectare and target profit.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),
          if (previousSummaries.isEmpty)
            Text(
              'No completed harvest season is stored yet for this farm.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
              ),
            )
          else
            ...previousSummaries.map(
              (summary) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppVisuals.cloudGlass,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Season ${summary.session.seasonNumber}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppVisuals.textForest,
                          ),
                        ),
                        if (_isSugarcane)
                          _InlineTag(
                            label: 'Ratoon ${summary.session.ratoonCount}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${summary.deliveredTons.toStringAsFixed(2)} tons  |  ${_currency.format(summary.netProfit)} net  |  ${summary.tonsGap >= 0 ? '+' : '-'}${summary.tonsGap.abs().toStringAsFixed(2)} t vs target',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppVisuals.textForestMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (summary.session.completedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Completed ${DateFormat('MMM d, y').format(summary.session.completedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppVisuals.textForestMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeasonActionsCard(
    ThemeData theme,
    FarmHarvestSession? activeSession,
  ) {
    final showDetails = _showInteractionDetails;
    final showResetFarmAction =
        !_isFarmInHarvestStatus && activeSession == null;
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Season controls',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: 8),
            Text(
              showResetFarmAction
                  ? 'Reset Farm restarts the current season timeline from today. Next Season moves the farm into a brand-new season. Remove the farm only if the field should leave the app entirely.'
                  : 'Continue to the next season to reset the farm age, guidance windows, and harvest timeline. Remove the farm only if the field should leave the app entirely.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (showResetFarmAction)
                Tooltip(
                  message:
                      'Reset the planting date to today and restart the current farm timeline without moving to the next season.',
                  child: FilledButton.icon(
                    onPressed: _resetFarmTimeline,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset Farm'),
                  ),
                ),
              Tooltip(
                message:
                    'Close the current season, reset the farm timeline, and continue to the next season.',
                child: FilledButton.tonalIcon(
                  onPressed: _advanceToNextSeason,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Next Season'),
                ),
              ),
              Tooltip(
                message:
                    'Delete this farm and remove its stored harvest board history.',
                child: OutlinedButton.icon(
                  onPressed: _deleteFarm,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Remove Farm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _entryTypeLabel(String type) {
  switch (type) {
    case 'delivery':
      return 'Delivery';
    case 'income':
      return 'Income';
    case 'expense':
      return 'Expense';
    case 'note':
      return 'Note';
    default:
      return type;
  }
}

IconData _entryTypeIcon(String type) {
  switch (type) {
    case 'delivery':
      return Icons.local_shipping_rounded;
    case 'income':
      return Icons.payments_rounded;
    case 'expense':
      return Icons.receipt_long_rounded;
    case 'note':
      return Icons.sticky_note_2_rounded;
    default:
      return Icons.circle_rounded;
  }
}

double _defaultPricePerTon(String cropType) {
  final normalized = cropType.toLowerCase();
  if (normalized.contains('rice')) {
    return 18000;
  }
  if (normalized.contains('corn')) {
    return 12000;
  }
  return 2200;
}

class _HarvestSummary {
  const _HarvestSummary({
    required this.session,
    required this.deliveredTons,
    required this.income,
    required this.expenses,
    required this.netProfit,
    required this.targetTons,
    required this.targetProfit,
    required this.tonsGap,
    required this.profitGap,
  });

  final FarmHarvestSession session;
  final double deliveredTons;
  final double income;
  final double expenses;
  final double netProfit;
  final double targetTons;
  final double targetProfit;
  final double tonsGap;
  final double profitGap;

  factory _HarvestSummary.fromSession({
    required FarmHarvestSession session,
    required List<FarmHarvestEntry> entries,
    required double targetTons,
    required double fallbackPricePerTon,
  }) {
    double deliveredTons = 0;
    double income = 0;
    double expenses = 0;

    for (final entry in entries) {
      if (!entry.isActive) {
        continue;
      }
      if (entry.entryType == 'delivery') {
        deliveredTons += entry.quantityTons;
        income += entry.amount;
      } else if (entry.entryType == 'income') {
        income += entry.amount;
      } else if (entry.entryType == 'expense') {
        expenses += entry.amount;
      }
    }

    final pricePerTon = deliveredTons > 0 && income > 0
        ? income / deliveredTons
        : fallbackPricePerTon;
    final netProfit = income - expenses;
    final targetProfit = (targetTons * pricePerTon) - expenses;

    return _HarvestSummary(
      session: session,
      deliveredTons: deliveredTons,
      income: income,
      expenses: expenses,
      netProfit: netProfit,
      targetTons: targetTons,
      targetProfit: targetProfit,
      tonsGap: deliveredTons - targetTons,
      profitGap: netProfit - targetProfit,
    );
  }

  factory _HarvestSummary.fromSugarcaneProfitRecords({
    required FarmHarvestSession session,
    required List<SugarcaneProfit> records,
    required double targetTons,
    required double fallbackPricePerTon,
  }) {
    double deliveredTons = 0;
    double income = 0;
    double expenses = 0;
    double netProfit = 0;

    for (final record in records) {
      deliveredTons += record.netTonsCane;
      income += record.totalRevenue;
      expenses += record.productionCosts;
      netProfit += record.netProfit;
    }

    final pricePerTon = deliveredTons > 0 && income > 0
        ? income / deliveredTons
        : fallbackPricePerTon;
    final targetProfit = (targetTons * pricePerTon) - expenses;

    return _HarvestSummary(
      session: session,
      deliveredTons: deliveredTons,
      income: income,
      expenses: expenses,
      netProfit: netProfit,
      targetTons: targetTons,
      targetProfit: targetProfit,
      tonsGap: deliveredTons - targetTons,
      profitGap: netProfit - targetProfit,
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _SugarcaneProfitDraft {
  const _SugarcaneProfitDraft({
    required this.netTonsCane,
    required this.lkgPerTc,
    required this.planterShare,
    required this.sugarPricePerLkg,
    required this.molassesKg,
    required this.molassesPricePerKg,
    required this.productionCosts,
    required this.sugarProceeds,
    required this.molassesProceeds,
    required this.totalRevenue,
    required this.netProfit,
  });

  final double netTonsCane;
  final double lkgPerTc;
  final double planterShare;
  final double sugarPricePerLkg;
  final double molassesKg;
  final double molassesPricePerKg;
  final double productionCosts;
  final double sugarProceeds;
  final double molassesProceeds;
  final double totalRevenue;
  final double netProfit;
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  const _InlineTag({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        FocusTooltip(
          message: 'Enter $label.',
          child: child,
        ),
      ],
    );
  }
}
