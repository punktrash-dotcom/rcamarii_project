import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../models/produce_delivery_model.dart';
import '../providers/activity_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/ftracker_provider.dart';
import '../providers/voice_command_provider.dart';
import '../models/activity_model.dart';
import '../services/app_properties_store.dart';
import '../services/database_helper.dart';
import '../services/transaction_log_service.dart';
import '../themes/custom_themes.dart';
import '../utils/validation_utils.dart';
import '../widgets/searchable_dropdown.dart';
import '../models/farm_model.dart';

class FrmLogistics extends StatefulWidget {
  const FrmLogistics({super.key});

  @override
  State<FrmLogistics> createState() => _FrmLogisticsState();
}

enum _LogisticsFlow { chooser, sugarcane, produce }

enum _RiceFarmResetAction { zero, prePlanting }

class _FrmLogisticsState extends State<FrmLogistics> {
  static const _lastTruckingIdKey = 'last_trucking_id';
  static const _legacyLastTruckingNumKey = 'last_trucking_num';
  static const _lastProduceDeliveryNoKey = 'last_produce_delivery_no';
  final _formKey = GlobalKey<FormState>();
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  // State Variables
  DateTime _selectedDate = DateTime.now();
  String? _selectedCrop;
  bool _autoIncrement = true;
  bool _isAdvanceScheduling = false;
  bool _includeOverallExpenses = false;
  _LogisticsFlow _flow = _LogisticsFlow.chooser;
  final _scrollController = ScrollController();

  // Historical data for auto-complete
  List<String> _historicalCompanies = [];
  List<String> _historicalCosts = [];
  String? _lastCompanyHint;
  String? _lastCostHint;

  // Controllers
  final _truckingNumController = TextEditingController();
  final _companyController = TextEditingController();
  final _costController = TextEditingController();
  final _deliveryNameController = TextEditingController();
  final _noteController = TextEditingController();
  final _produceDeliveryNoController = TextEditingController();
  final _totalSacksController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _deductionsController = TextEditingController();
  final _maintainerShareController = TextEditingController();
  final _harvesterShareController = TextEditingController();
  final _priceOfProduceController = TextEditingController();
  final _overallExpensesController = TextEditingController();

  String? _selectedFarmName;
  _SavedProduceSummary? _savedProduceSummary;

  @override
  void initState() {
    super.initState();
    // Ensure all initial data loading happens after the first build frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadHistory();
        _initTruckingNumber();
        Provider.of<FarmProvider>(context, listen: false).refreshFarms();
        Provider.of<ActivityProvider>(context, listen: false).loadActivities();
      }
    });
  }

  @override
  void dispose() {
    _truckingNumController.dispose();
    _companyController.dispose();
    _costController.dispose();
    _deliveryNameController.dispose();
    _noteController.dispose();
    _produceDeliveryNoController.dispose();
    _totalSacksController.dispose();
    _grossWeightController.dispose();
    _deductionsController.dispose();
    _maintainerShareController.dispose();
    _harvesterShareController.dispose();
    _priceOfProduceController.dispose();
    _overallExpensesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initTruckingNumber() async {
    final lastTrackingId = await _readLastTrackingId();
    if (_autoIncrement && mounted) {
      setState(() {
        _truckingNumController.text = _incrementTrackingNumber(lastTrackingId);
      });
    }
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      final historicalCompanies =
          await _store.getStringList('history_companies') ?? [];
      final historicalCosts = await _store.getStringList('history_costs') ?? [];
      final saveForNext = await _store.getBool('save_for_next') ?? false;
      final savedCompany =
          (await _store.getString('last_company'))?.trim() ?? '';
      final savedCost = (await _store.getString('last_cost'))?.trim() ?? '';

      setState(() {
        _historicalCompanies = historicalCompanies;
        _historicalCosts = historicalCosts;

        if (saveForNext) {
          _lastCompanyHint = savedCompany.isEmpty ? null : savedCompany;
          _lastCostHint = savedCost.isEmpty ? null : savedCost;
        } else {
          _lastCompanyHint = null;
          _lastCostHint = null;
        }
      });
    }
  }

  Future<void> _saveToHistory() async {
    // Update company history
    if (!_historicalCompanies.contains(_companyController.text) &&
        _companyController.text.isNotEmpty) {
      _historicalCompanies.add(_companyController.text);
      await _store.setStringList('history_companies', _historicalCompanies);
    }

    // Update cost history
    if (!_historicalCosts.contains(_costController.text) &&
        _costController.text.isNotEmpty) {
      _historicalCosts.add(_costController.text);
      await _store.setStringList('history_costs', _historicalCosts);
    }

    await _store.setString(
      _lastTruckingIdKey,
      _normalizeTrackingValue(_truckingNumController.text),
    );
    await _store.setString('last_company', _companyController.text);
    await _store.setString('last_cost', _costController.text);
    await _store.setString('last_crop', _selectedCrop ?? '');
  }

  Future<String> _readLastTrackingId() async {
    final storedTrackingId = await _store.getString(_lastTruckingIdKey);
    if (storedTrackingId != null && storedTrackingId.trim().isNotEmpty) {
      return storedTrackingId.trim();
    }

    final legacyNumber = await _store.getInt(_legacyLastTruckingNumKey);
    if (legacyNumber != null && legacyNumber > 0) {
      return legacyNumber.toString();
    }

    return '1000';
  }

  String _normalizeTrackingValue(String rawValue) {
    final trimmed = rawValue.trim();
    return trimmed.isEmpty ? '1000' : trimmed;
  }

  String _incrementTrackingNumber(String rawValue) {
    final normalized = _normalizeTrackingValue(rawValue);
    final match = RegExp(r'(\d+)(?!.*\d)').firstMatch(normalized);
    if (match == null) {
      return '$normalized-1';
    }

    final digits = match.group(1)!;
    final incremented = (int.tryParse(digits) ?? 0) + 1;
    final padded = incremented.toString().padLeft(digits.length, '0');
    return normalized.replaceRange(match.start, match.end, padded);
  }

  Future<void> _initProduceDeliveryNumber() async {
    final lastDeliveryNo =
        (await _store.getString(_lastProduceDeliveryNoKey))?.trim() ?? '1000';
    if (!mounted) return;
    setState(() {
      _produceDeliveryNoController.text =
          _incrementTrackingNumber(lastDeliveryNo);
    });
  }

  Future<void> _startSugarcaneFlow() async {
    await _initTruckingNumber();
    if (!mounted) return;
    setState(() {
      _flow = _LogisticsFlow.sugarcane;
      _selectedCrop = 'Sugarcane';
      _selectedDate = DateTime.now();
      _isAdvanceScheduling = false;
      _selectedFarmName = null;
    });
  }

  Future<void> _startProduceFlow(String crop) async {
    await _initProduceDeliveryNumber();
    if (!mounted) return;
    setState(() {
      _flow = _LogisticsFlow.produce;
      _selectedCrop = crop;
      _selectedDate = DateTime.now();
      _isAdvanceScheduling = false;
      _selectedFarmName = null;
      _includeOverallExpenses = false;
      _deliveryNameController.clear();
      _noteController.clear();
      _totalSacksController.clear();
      _grossWeightController.clear();
      _deductionsController.clear();
      _maintainerShareController.clear();
      _harvesterShareController.clear();
      _priceOfProduceController.clear();
      _overallExpensesController.clear();
      _savedProduceSummary = null;
    });
  }

  void _returnToCropChooser() {
    setState(() {
      _flow = _LogisticsFlow.chooser;
      _selectedCrop = null;
      _selectedFarmName = null;
      _includeOverallExpenses = false;
      _selectedDate = DateTime.now();
      _isAdvanceScheduling = false;
      _overallExpensesController.clear();
      _savedProduceSummary = null;
    });
  }

  void _syncOverallExpensesField() {
    final nextValue = _overallFarmExpenses.toStringAsFixed(2);
    _overallExpensesController.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final isProduceFlow = _flow == _LogisticsFlow.produce;
    final today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: isProduceFlow ? today : DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isAdvanceScheduling =
            !isProduceFlow && _selectedDate.isAfter(DateTime.now());
      });
      if (isProduceFlow && (_selectedFarmName?.trim().isNotEmpty ?? false)) {
        _syncOverallExpensesField();
      }
      if (_isAdvanceScheduling) _promptAdvanceScheduling();
    }
  }

  void _promptAdvanceScheduling() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advance Scheduling'),
        content: const Text(
            'The selected date is in the future. This will be saved as an advance schedule alert.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  void _saveLogistics() async {
    if (!_formKey.currentState!.validate()) return;

    final String company = ValidationUtils.toTitleCase(_companyController.text);
    final double cost = double.tryParse(_costController.text) ?? 0.0;
    final bool isSugarcaneDelivery =
        (_selectedCrop ?? '').toLowerCase().trim() == 'sugarcane';
    final String deliveryName = _deliveryNameController.text.trim();
    final String logisticsCategory = (_selectedCrop?.trim().isNotEmpty ?? false)
        ? _selectedCrop!.trim()
        : 'Logistics';
    final String logisticsNote = _noteController.text.trim();
    final String activityFarmName =
        isSugarcaneDelivery && deliveryName.isNotEmpty
            ? deliveryName
            : (_selectedCrop ?? 'General');
    final String enrichedLogisticsNote = isSugarcaneDelivery
        ? _buildSugarcaneDeliveryNote(
            company: company,
            deliveryName: deliveryName,
            note: logisticsNote,
          )
        : logisticsNote;
    final String? persistedLogisticsNote =
        enrichedLogisticsNote.isNotEmpty ? enrichedLogisticsNote : null;

    final activity = Activity(
      jobId: 'TRK-${_truckingNumController.text}',
      tag: _isAdvanceScheduling ? 'SCHEDULED' : 'Logistics',
      date: _selectedDate,
      farm: activityFarmName,
      name: 'Trucking: $company',
      labor: 'Logistics',
      assetUsed: _truckingNumController.text,
      costType: 'Expense',
      duration: 1.0,
      cost: cost,
      total: cost,
      worker: company,
      note: persistedLogisticsNote,
    );

    final ftrackerProvider =
        Provider.of<FtrackerProvider>(context, listen: false);
    final deliveryProvider =
        Provider.of<DeliveryProvider>(context, listen: false);
    final activityProvider =
        Provider.of<ActivityProvider>(context, listen: false);
    final trackerRecord = isSugarcaneDelivery
        ? null
        : ftrackerProvider.buildRecord(
            dDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
            dType: 'Expenses',
            dAmount: cost,
            category: logisticsCategory,
            name: activity.name,
            note: logisticsNote.isNotEmpty ? logisticsNote : null,
          );

    if (isSugarcaneDelivery) {
      final delivery = Delivery(
        date: _selectedDate,
        type: 'Sugarcane',
        name: deliveryName,
        ticketNo: _truckingNumController.text.trim(),
        cost: null,
        quantity: 0,
        total: 0,
        note: persistedLogisticsNote,
      );
      await DatabaseHelper.instance.runInTransaction((txn) async {
        await txn.insert(DatabaseHelper.tableActivities, activity.toMap());
        await txn.insert(DatabaseHelper.tableDeliveries, delivery.toMap());
      });
    } else {
      await DatabaseHelper.instance.runInTransaction((txn) async {
        await txn.insert(DatabaseHelper.tableActivities, activity.toMap());
        await txn.insert(DatabaseHelper.tableFtracker, trackerRecord!.toMap());
      });
    }

    final reloads = <Future<void>>[activityProvider.loadActivities()];
    if (trackerRecord != null) {
      reloads.add(ftrackerProvider.loadFtrackerRecords());
    }
    if (isSugarcaneDelivery) {
      reloads.add(deliveryProvider.loadDeliveries());
    }
    await Future.wait(reloads);
    TransactionLogService.instance.log(
      'Activity added',
      details:
          '${activity.name} @ ${activity.farm} | ${activity.labor} | PHP ${activity.total.toStringAsFixed(2)}',
    );

    if (!mounted) return;

    final bool saveForNext = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Save Details?'),
                  content: const Text(
                      'Save these details for future auto-complete?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('No')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Yes')),
                  ],
                )) ??
        false;
    if (!mounted) return;

    await _store.setBool('save_for_next', saveForNext);
    if (saveForNext) await _saveToHistory();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isAdvanceScheduling
            ? 'Transaction scheduled and sugarcane delivery queued.'
            : isSugarcaneDelivery
                ? 'Logistics saved and sugarcane delivery sent to the profit calculator queue.'
                : 'Logistics Record Saved & Financials Updated!')));
    Navigator.pop(context);
  }

  String _buildSugarcaneDeliveryNote({
    required String company,
    required String deliveryName,
    required String note,
  }) {
    final parts = <String>[
      'Created from Logistics',
      'Company: $company',
      'Farm/Batch: $deliveryName',
    ];

    final trackingNumber = _truckingNumController.text.trim();
    if (trackingNumber.isNotEmpty) {
      parts.add('Tracking #: $trackingNumber');
    }

    if ((_selectedFarmName?.trim().isNotEmpty ?? false) &&
        _selectedFarmName!.trim() != deliveryName) {
      parts.add('Farm: ${_selectedFarmName!.trim()}');
    }

    if (note.isNotEmpty) {
      parts.add(note);
    }

    return parts.join(' | ');
  }

  double _parseNumber(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0.0;
  }

  double get _totalSacks => _parseNumber(_totalSacksController);
  double get _grossWeight => _parseNumber(_grossWeightController);
  double get _deductionsPercent => _parseNumber(_deductionsController);
  double get _maintainerSharePercent =>
      _parseNumber(_maintainerShareController);
  double get _harvesterSharePercent => _parseNumber(_harvesterShareController);
  double get _priceOfProduce => _parseNumber(_priceOfProduceController);

  double get _grossSales => _grossWeight * _priceOfProduce;

  double get _deductionsAmount => _grossSales * (_deductionsPercent / 100);

  double get _maintainerShareAmount =>
      _grossSales * (_maintainerSharePercent / 100);

  double get _harvesterShareAmount =>
      _grossSales * (_harvesterSharePercent / 100);

  double get _totalDeductionsAmount =>
      _deductionsAmount + _maintainerShareAmount + _harvesterShareAmount;

  double get _averageWeightPerSack =>
      _totalSacks <= 0 ? 0.0 : _grossWeight / _totalSacks;

  double get _netProfitBeforeExpenses => _grossSales - _totalDeductionsAmount;

  Farm? get _selectedFarmRecord {
    final selectedFarm = _selectedFarmName?.trim();
    if (selectedFarm == null || selectedFarm.isEmpty) {
      return null;
    }

    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    for (final farm in farmProvider.farms) {
      if (farm.name.trim() == selectedFarm) {
        return farm;
      }
    }
    return null;
  }

  Iterable<Activity> get _farmExpenseActivities {
    final selectedFarm = _selectedFarmName?.trim();
    if (selectedFarm == null || selectedFarm.isEmpty) {
      return const <Activity>[];
    }

    final activityProvider =
        Provider.of<ActivityProvider>(context, listen: false);
    return activityProvider.activities.where((activity) {
      if (activity.farm.trim() != selectedFarm) {
        return false;
      }
      return !activity.date.isAfter(_selectedDate) && activity.total > 0;
    });
  }

  double _sumActivityTotals(Iterable<Activity> activities) {
    return activities.fold<double>(
        0.0, (sum, activity) => sum + activity.total);
  }

  double get _prePlantingExpenses {
    final farm = _selectedFarmRecord;
    if (farm == null) {
      return 0.0;
    }

    return _sumActivityTotals(
      _farmExpenseActivities
          .where((activity) => activity.date.isBefore(farm.date)),
    );
  }

  double get _postPlantingExpenses {
    final farm = _selectedFarmRecord;
    if (farm == null) {
      return 0.0;
    }

    return _sumActivityTotals(
      _farmExpenseActivities.where(
        (activity) =>
            !activity.date.isBefore(farm.date) &&
            !activity.date.isAfter(_selectedDate),
      ),
    );
  }

  double get _overallFarmExpenses {
    return _prePlantingExpenses + _postPlantingExpenses;
  }

  double get _enteredOverallExpenses {
    final parsed = double.tryParse(_overallExpensesController.text.trim());
    return parsed ?? _overallFarmExpenses;
  }

  double get _effectiveNetProfit =>
      _netProfitBeforeExpenses -
      (_includeOverallExpenses ? _enteredOverallExpenses : 0.0);

  String _formatAmount(double value) {
    return NumberFormat('#,##0.00').format(value);
  }

  Future<void> _promptRiceFarmResetAfterSave() async {
    final farm = _selectedFarmRecord;
    if (!mounted || farm == null || farm.type.toLowerCase().trim() != 'rice') {
      return;
    }

    final action = await showDialog<_RiceFarmResetAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rice Harvest Completed'),
        content: Text(
          '${farm.name} has been harvested. Do you want to reset this farm to zero days or move it to pre-planting?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Current'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _RiceFarmResetAction.prePlanting),
            child: const Text('Pre-Planting'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _RiceFarmResetAction.zero),
            child: const Text('Reset to Zero'),
          ),
        ],
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    final now = DateTime.now();
    final resetDate = switch (action) {
      _RiceFarmResetAction.zero => DateTime(
          now.year,
          now.month,
          now.day,
        ),
      _RiceFarmResetAction.prePlanting => DateTime(
          now.year,
          now.month,
          now.day + 1,
        ),
    };

    await farmProvider.updateFarm(
      Farm(
        id: farm.id,
        name: farm.name,
        type: farm.type,
        area: farm.area,
        city: farm.city,
        province: farm.province,
        date: resetDate,
        owner: farm.owner,
      ),
    );
  }

  Future<void> _saveProduceDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    final crop = _selectedCrop;
    final farmName = _selectedFarmName?.trim() ?? '';
    if (crop == null || (crop != 'Rice' && crop != 'Corn')) {
      return;
    }

    final note = _noteController.text.trim();
    final includeExpenses = _includeOverallExpenses;
    final prePlantingExpenses = _prePlantingExpenses;
    final postPlantingExpenses = _postPlantingExpenses;
    final overallExpenses = _enteredOverallExpenses;
    final createdAt = DateTime.now();
    final summaryParts = <String>[
      'Created from Logistics',
      'Crop: $crop',
      'Delivery No: ${_produceDeliveryNoController.text.trim()}',
      'Farm: $farmName',
      'Total sacks: ${_totalSacks.toStringAsFixed(_totalSacks % 1 == 0 ? 0 : 2)}',
      'Gross weight: ${_grossWeight.toStringAsFixed(2)}',
      'Price: ${_priceOfProduce.toStringAsFixed(2)}',
      'Gross sales: ${_grossSales.toStringAsFixed(2)}',
      'Deductions: ${_deductionsPercent.toStringAsFixed(2)}%',
      'Maintainer share: ${_maintainerSharePercent.toStringAsFixed(2)}%',
      'Harvester share: ${_harvesterSharePercent.toStringAsFixed(2)}%',
      'Total deductions: ${_totalDeductionsAmount.toStringAsFixed(2)}',
      'Net profit: ${_netProfitBeforeExpenses.toStringAsFixed(2)}',
    ];
    if (includeExpenses) {
      summaryParts.add(
        'Overall farm expenses included: ${overallExpenses.toStringAsFixed(2)}',
      );
      summaryParts.add(
        'Final profit: ${_effectiveNetProfit.toStringAsFixed(2)}',
      );
    }
    if (note.isNotEmpty) {
      summaryParts.add(note);
    }

    final delivery = Delivery(
      date: _selectedDate,
      type: crop,
      name: farmName,
      ticketNo: _produceDeliveryNoController.text.trim(),
      cost: _priceOfProduce,
      quantity: _grossWeight,
      total: _grossSales,
      note: summaryParts.join(' | '),
    );
    final produceDelivery = ProduceDelivery(
      deliveryNo: _produceDeliveryNoController.text.trim(),
      date: _selectedDate,
      crop: crop,
      farmName: farmName,
      totalSacks: _totalSacks,
      grossWeight: _grossWeight,
      deductionsPercent: _deductionsPercent,
      maintainerSharePercent: _maintainerSharePercent,
      harvesterSharePercent: _harvesterSharePercent,
      priceOfProduce: _priceOfProduce,
      grossSales: _grossSales,
      totalDeductions: _totalDeductionsAmount,
      averageWeightPerSack: _averageWeightPerSack,
      netProfit: _netProfitBeforeExpenses,
      includeOverallExpenses: includeExpenses,
      prePlantingExpenses: prePlantingExpenses,
      overallFarmExpenses: overallExpenses,
      postPlantingExpenses: postPlantingExpenses,
      finalProfit: _effectiveNetProfit,
      note: note.isNotEmpty ? note : null,
      createdAt: createdAt,
    );
    final ftrackerProvider =
        Provider.of<FtrackerProvider>(context, listen: false);
    final trackerRecord = ftrackerProvider.buildRecord(
      dDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
      dType: 'Income',
      dAmount: _grossSales,
      category: crop,
      name: '$crop Delivery: $farmName',
      note: summaryParts.join(' | '),
    );

    await DatabaseHelper.instance.runInTransaction((txn) async {
      final deliveryId = await txn.insert(
        DatabaseHelper.tableDeliveries,
        delivery.toMap(),
      );
      final produceMap = produceDelivery.toMap();
      produceMap['DeliveryRefID'] = deliveryId;
      await txn.insert(
        DatabaseHelper.tableProduceDeliveries,
        produceMap,
      );
      await txn.insert(DatabaseHelper.tableFtracker, trackerRecord.toMap());
    });

    await _store.setString(
      _lastProduceDeliveryNoKey,
      _normalizeTrackingValue(_produceDeliveryNoController.text),
    );

    if (!mounted) return;
    final deliveryProvider =
        Provider.of<DeliveryProvider>(context, listen: false);
    await deliveryProvider.loadDeliveries();
    await ftrackerProvider.loadFtrackerRecords();
    TransactionLogService.instance.log(
      'Produce delivery saved',
      details:
          '$crop @ $farmName | gross sales PHP ${_grossSales.toStringAsFixed(2)} | final PHP ${_effectiveNetProfit.toStringAsFixed(2)}',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          includeExpenses
              ? 'Produce delivery saved. Final profit includes recorded farm expenses.'
              : 'Produce delivery saved.',
        ),
      ),
    );
    final nextDeliveryNo =
        _incrementTrackingNumber(_produceDeliveryNoController.text.trim());
    setState(() {
      _savedProduceSummary = _SavedProduceSummary(
        deliveryNo: _produceDeliveryNoController.text.trim(),
        crop: crop,
        farmName: farmName,
        grossSales: _grossSales,
        averageWeightPerSack: _averageWeightPerSack,
        totalDeductions: _totalDeductionsAmount,
        netProfitExpected: _netProfitBeforeExpenses,
        finalProfit: _effectiveNetProfit,
        includeOverallExpenses: includeExpenses,
      );
      _produceDeliveryNoController.text = nextDeliveryNo;
      _totalSacksController.clear();
      _grossWeightController.clear();
      _deductionsController.clear();
      _maintainerShareController.clear();
      _harvesterShareController.clear();
      _priceOfProduceController.clear();
      _noteController.clear();
    });
    if (crop == 'Rice') {
      await _promptRiceFarmResetAfterSave();
    }
    if (_selectedFarmName?.trim().isNotEmpty ?? false) {
      _syncOverallExpensesField();
    }
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryTheme = CustomThemes.delivery(Theme.of(context));
    return Theme(
      data: deliveryTheme,
      child: Builder(builder: (context) {
        final voiceProvider =
            Provider.of<VoiceCommandProvider>(context, listen: false);
        final farmProvider = Provider.of<FarmProvider>(context);
        final sugarcaneFarmNames = farmProvider.farms
            .where((farm) => farm.type.toLowerCase().trim() == 'sugarcane')
            .map((farm) => farm.name)
            .toSet()
            .toList()
          ..sort();
        final produceFarmNames = farmProvider.farms
            .where((farm) =>
                farm.type.toLowerCase().trim() ==
                (_selectedCrop ?? '').toLowerCase().trim())
            .map((farm) => farm.name)
            .toSet()
            .toList()
          ..sort();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  deliveryTheme.colorScheme.primary.withValues(alpha: 0.2),
                  deliveryTheme.colorScheme.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: _buildFlowContent(
                  voiceProvider: voiceProvider,
                  deliveryTheme: deliveryTheme,
                  sugarcaneFarmNames: sugarcaneFarmNames,
                  produceFarmNames: produceFarmNames,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFlowContent({
    required VoiceCommandProvider voiceProvider,
    required ThemeData deliveryTheme,
    required List<String> sugarcaneFarmNames,
    required List<String> produceFarmNames,
  }) {
    switch (_flow) {
      case _LogisticsFlow.chooser:
        return _buildCropChooser(voiceProvider);
      case _LogisticsFlow.sugarcane:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeaderRow(
              voiceProvider,
              title: 'Logistics & Trucking',
              subtitle: 'Deliveries, haulage and freight intelligence',
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 14),
            _buildLogisticsChips(),
            const SizedBox(height: 18),
            _buildSugarcaneFormCard(deliveryTheme, sugarcaneFarmNames),
          ],
        );
      case _LogisticsFlow.produce:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeaderRow(
              voiceProvider,
              title: '${_selectedCrop ?? 'Produce'} Delivery',
              subtitle:
                  'Capture sacks, weight, deductions, and farm-level profit',
              allowBackToChooser: true,
            ),
            const SizedBox(height: 14),
            if (_savedProduceSummary != null) ...[
              _buildSavedProduceSummaryCard(),
              const SizedBox(height: 18),
            ],
            _buildProduceFormCard(deliveryTheme, produceFarmNames),
          ],
        );
    }
  }

  Widget _buildCropChooser(VoiceCommandProvider voiceProvider) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(
          voiceProvider,
          title: 'Start Logistics',
          subtitle: 'Choose which crop this delivery belongs to',
        ),
        const SizedBox(height: 18),
        Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(28),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which crop is involved?',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sugarcane keeps the current trucking flow. Rice and corn open the produce-delivery form with sacks, weight, deductions, and profit fields.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _buildCropChoiceButton(
                  icon: Icons.grass_rounded,
                  label: 'Sugarcane',
                  description: 'Open the current logistics and trucking flow.',
                  onPressed: _startSugarcaneFlow,
                ),
                const SizedBox(height: 12),
                _buildCropChoiceButton(
                  icon: Icons.rice_bowl_rounded,
                  label: 'Rice',
                  description:
                      'Open the produce-delivery form with profit calculations.',
                  onPressed: () => _startProduceFlow('Rice'),
                ),
                const SizedBox(height: 12),
                _buildCropChoiceButton(
                  icon: Icons.agriculture_rounded,
                  label: 'Corn',
                  description:
                      'Open the produce-delivery form with profit calculations.',
                  onPressed: () => _startProduceFlow('Corn'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropChoiceButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.28)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    VoiceCommandProvider voiceProvider, {
    required String title,
    required String subtitle,
    bool allowBackToChooser = false,
    VoidCallback? onBack,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: onBack ??
              (allowBackToChooser
                  ? _returnToCropChooser
                  : () => Navigator.pop(context)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.mic, color: theme.colorScheme.primary),
          onPressed: () => voiceProvider.requestCommand(context,
              hint: 'Summarize this delivery'),
        ),
      ],
    );
  }

  Widget _buildLogisticsChips() {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        Chip(
          label: Text(_autoIncrement ? 'Auto ID mode' : 'Manual entry'),
          backgroundColor: scheme.primary.withValues(alpha: 0.15),
        ),
        Chip(
          label: Text(
              _isAdvanceScheduling ? 'Advance schedule' : 'Dispatch today'),
          backgroundColor: scheme.secondary.withValues(alpha: 0.12),
        ),
      ],
    );
  }

  Widget _buildSugarcaneFormCard(
    ThemeData deliveryTheme,
    List<String> sugarcaneFarmNames,
  ) {
    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(28),
      color: deliveryTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateRow(),
              const SizedBox(height: 18),
              if (sugarcaneFarmNames.isNotEmpty)
                SearchableDropdownFormField<String>(
                  initialValue: sugarcaneFarmNames.contains(_selectedFarmName)
                      ? _selectedFarmName
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Farm',
                  ),
                  items: sugarcaneFarmNames
                      .map((farmName) => DropdownMenuItem(
                            value: farmName,
                            child: Text(farmName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFarmName = value;
                      if (value != null) {
                        _deliveryNameController.text = value;
                      }
                    });
                  },
                ),
              if (sugarcaneFarmNames.isNotEmpty) const SizedBox(height: 18),
              TextFormField(
                stylusHandwritingEnabled: false,
                controller: _deliveryNameController,
                decoration: InputDecoration(
                  labelText: sugarcaneFarmNames.isEmpty
                      ? 'Farm / Batch Name'
                      : 'Delivery / Batch Name',
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Required for sugarcane deliveries';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Sugarcane deliveries saved here will appear in the profit calculator as recent or pending delivery sources. Enter the actual weight later when the weekly report arrives.',
                style: deliveryTheme.textTheme.bodySmall?.copyWith(
                  color: deliveryTheme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              _buildTruckingRow(),
              const SizedBox(height: 20),
              _buildAutocompleteField(
                label: 'Association/Buyer',
                controller: _companyController,
                hintText: _lastCompanyHint,
                optionsBuilder: (editing) {
                  if (editing.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _historicalCompanies.where((company) => company
                      .toLowerCase()
                      .contains(editing.text.toLowerCase()));
                },
                onSelected: (selection) {
                  setState(() {
                    _companyController.text = selection;
                  });
                },
              ),
              const SizedBox(height: 18),
              _buildAutocompleteField(
                label: 'Total Cost (Fuel, Allowance, etc.)',
                controller: _costController,
                hintText: _lastCostHint,
                keyboardType: TextInputType.number,
                optionsBuilder: (editing) {
                  if (editing.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _historicalCosts.where((cost) => cost.contains(
                        editing.text,
                      ));
                },
                onSelected: (selection) {
                  setState(() {
                    _costController.text = selection;
                  });
                },
              ),
              const SizedBox(height: 18),
              _buildNotesField(),
              const SizedBox(height: 24),
              _buildFormActions(
                onSave: _saveLogistics,
                saveLabel: 'Save & Log',
                onCancel: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedProduceSummaryCard() {
    final summary = _savedProduceSummary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(26),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Latest Saved Delivery',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${summary.crop} • ${summary.farmName} • Delivery No. ${summary.deliveryNo}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = constraints.maxWidth < 560 ? 0.0 : 12.0;
                final cardWidth = constraints.maxWidth >= 900
                    ? ((constraints.maxWidth - (spacing * 2)) / 3)
                        .clamp(180.0, 240.0)
                    : constraints.maxWidth >= 560
                        ? ((constraints.maxWidth - spacing) / 2)
                            .clamp(180.0, 240.0)
                        : constraints.maxWidth;
                final cards = [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard('Gross Sales', summary.grossSales),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      'Average Wt. Per Sack',
                      summary.averageWeightPerSack,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      'Total Deductions',
                      summary.totalDeductions,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      'Net Profit (Expected)',
                      summary.netProfitExpected,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(
                      'Final Profit',
                      summary.finalProfit,
                    ),
                  ),
                ];

                return Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: spacing,
                  runSpacing: 12,
                  children: cards,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, double value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _formatAmount(value),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComputedExpenseCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasFarm = !(_selectedFarmName?.trim().isEmpty ?? true);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Computed Farm Expenses',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFarm
                ? 'This is auto-computed from recorded farm expenses up to the delivery date. You can adjust the total recorded expenses field below before saving.'
                : 'Select a farm to load the pre-planting and post-planting expense totals.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _buildExpenseBreakdownItem(
                  label: 'Pre-Planting',
                  value: _prePlantingExpenses,
                ),
                _buildExpenseBreakdownItem(
                  label: 'Post-Planting',
                  value: _postPlantingExpenses,
                ),
                _buildExpenseBreakdownItem(
                  label: 'Total Expenses',
                  value: _overallFarmExpenses,
                ),
              ];
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverallExpensesField() {
    return TextFormField(
      stylusHandwritingEnabled: false,
      controller: _overallExpensesController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Total Recorded Expenses',
        helperText:
            'Auto-filled from recorded supplies and jobs for this farm. You can edit it.',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }
        if (double.tryParse(value.trim()) == null) {
          return 'Enter a valid number';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildExpenseBreakdownItem({
    required String label,
    required double value,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProduceFormCard(
    ThemeData deliveryTheme,
    List<String> produceFarmNames,
  ) {
    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(28),
      color: deliveryTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProduceDeliveryNumberField(),
              const SizedBox(height: 18),
              _buildDateRow(),
              const SizedBox(height: 18),
              _buildCropPillField(),
              const SizedBox(height: 18),
              SearchableDropdownFormField<String>(
                initialValue: produceFarmNames.contains(_selectedFarmName)
                    ? _selectedFarmName
                    : null,
                decoration: const InputDecoration(labelText: 'Name'),
                items: produceFarmNames
                    .map((farmName) => DropdownMenuItem(
                          value: farmName,
                          child: Text(farmName),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedFarmName = value;
                    if (value == null || value.trim().isEmpty) {
                      _includeOverallExpenses = false;
                      _overallExpensesController.clear();
                    } else {
                      _syncOverallExpensesField();
                    }
                  });
                },
                validator: (value) {
                  if (produceFarmNames.isEmpty) {
                    return 'No farm found for this crop in the Farms database';
                  }
                  if (value == null || value.trim().isEmpty) {
                    return 'Select a farm name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _buildNumericField(
                controller: _totalSacksController,
                label: 'Total Sacks',
              ),
              const SizedBox(height: 18),
              _buildNumericField(
                controller: _grossWeightController,
                label: 'Gross Weight',
              ),
              const SizedBox(height: 18),
              _buildNumericField(
                controller: _deductionsController,
                label: 'Deductions (-%)',
                suffixText: '%',
              ),
              const SizedBox(height: 18),
              _buildNumericField(
                controller: _maintainerShareController,
                label: 'Maintainer\'s Share (-%)',
                suffixText: '%',
              ),
              const SizedBox(height: 18),
              _buildNumericField(
                controller: _harvesterShareController,
                label: 'Harvester\'s Share (-%)',
                suffixText: '%',
              ),
              const SizedBox(height: 18),
              _buildNumericField(
                controller: _priceOfProduceController,
                label: 'Price of Produce',
              ),
              const SizedBox(height: 18),
              _buildComputedExpenseCard(),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _includeOverallExpenses,
                title: const Text('Include computed farm expenses'),
                subtitle: Text(
                  _selectedFarmName?.trim().isEmpty ?? true
                      ? 'Select a farm to load pre-planting and post-planting expenses automatically.'
                      : 'Applied supplies and job-order costs recorded for this farm are already included in this computed amount.',
                ),
                onChanged: (_selectedFarmName?.trim().isEmpty ?? true)
                    ? null
                    : (value) {
                        setState(() {
                          _includeOverallExpenses = value;
                        });
                      },
              ),
              const SizedBox(height: 18),
              _buildNotesField(),
              const SizedBox(height: 18),
              _buildOverallExpensesField(),
              const SizedBox(height: 24),
              _buildFormActions(
                onSave: _saveProduceDelivery,
                saveLabel: 'Save Produce Delivery',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow() {
    final scheme = Theme.of(context).colorScheme;
    final dateSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date', style: Theme.of(context).textTheme.labelSmall),
        Text(
          DateFormat.yMMMMd().format(_selectedDate),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
    final changeButton = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_month, color: scheme.primary),
        const SizedBox(width: 6),
        Text('Change',
            style:
                TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
      ],
    );

    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dateSummary,
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: changeButton,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: dateSummary),
                const SizedBox(width: 12),
                Flexible(child: changeButton),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCropPillField() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Crop', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            _selectedCrop ?? '',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildProduceDeliveryNumberField() {
    return TextFormField(
      stylusHandwritingEnabled: false,
      controller: _produceDeliveryNoController,
      decoration: const InputDecoration(
        labelText: 'Delivery No.',
        helperText:
            'Editable. The next entry auto-increments from the last saved value.',
      ),
      style: const TextStyle(fontWeight: FontWeight.w700),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Delivery number is required';
        }
        return null;
      },
    );
  }

  Widget _buildTruckingRow() {
    final autoIdControl = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Auto ID', style: Theme.of(context).textTheme.labelMedium),
        Switch.adaptive(
          value: _autoIncrement,
          onChanged: (value) {
            setState(() {
              _autoIncrement = value;
              if (_autoIncrement &&
                  _truckingNumController.text.trim().isEmpty) {
                _initTruckingNumber();
              }
            });
          },
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackingField = TextFormField(
          stylusHandwritingEnabled: false,
          controller: _truckingNumController,
          decoration: InputDecoration(
            labelText: 'Trucking / Tracking Number',
            helperText: _autoIncrement
                ? 'Editable. Auto-increment uses the last digits in this value.'
                : 'Manual entry mode.',
          ),
          style: const TextStyle(fontWeight: FontWeight.w700),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Tracking number is required';
            }
            return null;
          },
        );

        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              trackingField,
              const SizedBox(height: 12),
              autoIdControl,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: trackingField),
            const SizedBox(width: 12),
            autoIdControl,
          ],
        );
      },
    );
  }

  Widget _buildFormActions({
    required VoidCallback onSave,
    required String saveLabel,
    VoidCallback? onCancel,
  }) {
    final cancelButton = OutlinedButton(
      onPressed: onCancel ?? _returnToCropChooser,
      child: const Text('Cancel'),
    );
    final saveButton = ElevatedButton.icon(
      onPressed: onSave,
      icon: const Icon(Icons.save),
      label: Text(saveLabel),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cancelButton,
              const SizedBox(height: 12),
              saveButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cancelButton),
            const SizedBox(width: 12),
            Expanded(child: saveButton),
          ],
        );
      },
    );
  }

  Widget _buildAutocompleteField({
    required String label,
    required TextEditingController controller,
    required Iterable<String> Function(TextEditingValue) optionsBuilder,
    required void Function(String) onSelected,
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: optionsBuilder,
      onSelected: (selection) {
        onSelected(selection);
      },
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && fieldController.text != controller.text) {
            fieldController.text = controller.text;
          }
        });
        return TextFormField(
          stylusHandwritingEnabled: false,
          controller: fieldController,
          focusNode: focusNode,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
          ),
          onChanged: (value) {
            controller.text = value;
          },
          onFieldSubmitted: (value) {
            final normalizedHint = hintText?.trim() ?? '';
            if (value.trim().isEmpty && normalizedHint.isNotEmpty) {
              fieldController.value = TextEditingValue(
                text: normalizedHint,
                selection:
                    TextSelection.collapsed(offset: normalizedHint.length),
              );
              controller.text = normalizedHint;
            }
            onFieldSubmitted();
          },
        );
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      stylusHandwritingEnabled: false,
      controller: _noteController,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Notes / Comments'),
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required String label,
    String? suffixText,
  }) {
    return TextFormField(
      stylusHandwritingEnabled: false,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        if (double.tryParse(value.trim()) == null) {
          return 'Enter a valid number';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }
}

class _SavedProduceSummary {
  final String deliveryNo;
  final String crop;
  final String farmName;
  final double grossSales;
  final double averageWeightPerSack;
  final double totalDeductions;
  final double netProfitExpected;
  final double finalProfit;
  final bool includeOverallExpenses;

  const _SavedProduceSummary({
    required this.deliveryNo,
    required this.crop,
    required this.farmName,
    required this.grossSales,
    required this.averageWeightPerSack,
    required this.totalDeductions,
    required this.netProfitExpected,
    required this.finalProfit,
    required this.includeOverallExpenses,
  });
}
