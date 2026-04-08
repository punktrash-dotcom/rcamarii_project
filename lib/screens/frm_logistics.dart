import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../models/farm_income_model.dart';
import '../models/produce_delivery_model.dart';
import '../providers/activity_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/farm_income_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/ftracker_provider.dart';
import '../models/activity_model.dart';
import '../services/app_properties_store.dart';
import '../services/app_localization_service.dart';
import '../services/database_helper.dart';
import '../services/transaction_log_service.dart';
import '../themes/app_visuals.dart';
import '../themes/custom_themes.dart';
import '../utils/app_number_input_formatter.dart';
import '../utils/validation_utils.dart';
import '../widgets/focus_tooltip.dart';
import '../widgets/searchable_dropdown.dart';
import '../models/farm_model.dart';

class FrmLogistics extends StatefulWidget {
  const FrmLogistics({
    super.key,
    this.initialFarmName,
    this.sugarcaneOnlyMode = false,
  });

  final String? initialFarmName;
  final bool sugarcaneOnlyMode;

  @override
  State<FrmLogistics> createState() => _FrmLogisticsState();
}

enum _LogisticsFlow { sugarcane, produce, farmIncome }

enum _FarmIncomeType { equipmentRental, itemSale, otherIncome }

enum _RiceFarmResetAction { zero, prePlanting }

enum _TruckingOwnership { owned, rental }

class _FrmLogisticsState extends State<FrmLogistics> {
  static const _lastTruckingIdKey = 'last_trucking_id';
  static const _legacyLastTruckingNumKey = 'last_trucking_num';
  static const _lastProduceDeliveryNoKey = 'last_produce_delivery_no';
  static const _lastFarmIncomeNoKey = 'last_farm_income_no';
  static const _lastSugarcaneCompanyKey = 'last_sugarcane_company';
  static const _lastSugarcaneCostKey = 'last_sugarcane_cost';
  static const _lastSugarcaneDeliveryNameKey = 'last_sugarcane_delivery_name';
  static const _lastSugarcaneFarmNameKey = 'last_sugarcane_farm_name';
  final _formKey = GlobalKey<FormState>();
  final AppPropertiesStore _store = AppPropertiesStore.instance;

  // State Variables
  DateTime _selectedDate = DateTime.now();
  String? _selectedCrop = 'Sugarcane';
  bool _autoIncrement = true;
  bool _isAdvanceScheduling = false;
  bool _includeOverallExpenses = false;
  _LogisticsFlow _flow = _LogisticsFlow.sugarcane;
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
  final _rentalCostController = TextEditingController();
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
  final _incomeNoController = TextEditingController();
  final _incomeAssetController = TextEditingController();
  final _incomeClientController = TextEditingController();
  final _incomeAmountController = TextEditingController();
  static final _numberInputFormatter = AppNumberInputFormatter();

  String? _selectedFarmName;
  _SavedProduceSummary? _savedProduceSummary;
  _FarmIncomeType _selectedFarmIncomeType = _FarmIncomeType.equipmentRental;
  _TruckingOwnership _truckingOwnership = _TruckingOwnership.owned;

  bool get _showInteractionDetails =>
      Provider.of<AppSettingsProvider>(context, listen: false)
          .showDetailedDescriptions;

  @override
  void initState() {
    super.initState();
    // Ensure all initial data loading happens after the first build frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSugarcaneHistory();
        _initTruckingNumber();
        _initIncomeNumber();
        Provider.of<FarmProvider>(context, listen: false).refreshFarms();
        Provider.of<ActivityProvider>(context, listen: false).loadActivities();
        Provider.of<FarmIncomeProvider>(context, listen: false).loadRecords();
      }
    });
  }

  @override
  void dispose() {
    _truckingNumController.dispose();
    _companyController.dispose();
    _costController.dispose();
    _rentalCostController.dispose();
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
    _incomeNoController.dispose();
    _incomeAssetController.dispose();
    _incomeClientController.dispose();
    _incomeAmountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initTruckingNumber() async {
    final lastTrackingId = await _readLastTrackingId();
    if (mounted) {
      setState(() {
        _truckingNumController.text = _autoIncrement
            ? _incrementTrackingNumber(lastTrackingId)
            : lastTrackingId;
      });
    }
  }

  Future<void> _loadSugarcaneHistory() async {
    if (mounted) {
      final historicalCompanies =
          await _store.getStringList('history_companies') ?? [];
      final historicalCosts = await _store.getStringList('history_costs') ?? [];
      final savedCompany =
          (await _store.getString(_lastSugarcaneCompanyKey))?.trim() ?? '';
      final savedCost =
          (await _store.getString(_lastSugarcaneCostKey))?.trim() ?? '';
      final savedDeliveryName =
          (await _store.getString(_lastSugarcaneDeliveryNameKey))?.trim() ?? '';
      final savedFarmName =
          (await _store.getString(_lastSugarcaneFarmNameKey))?.trim() ?? '';
      final initialFarmName = widget.initialFarmName?.trim() ?? '';

      setState(() {
        _historicalCompanies = historicalCompanies;
        _historicalCosts = historicalCosts;
        _lastCompanyHint = savedCompany.isEmpty ? null : savedCompany;
        _lastCostHint = savedCost.isEmpty ? null : savedCost;
        if (_flow == _LogisticsFlow.sugarcane) {
          if (_companyController.text.trim().isEmpty &&
              savedCompany.isNotEmpty) {
            _companyController.text = savedCompany;
          }
          if (_costController.text.trim().isEmpty && savedCost.isNotEmpty) {
            _costController.text = savedCost;
          }
          if (_deliveryNameController.text.trim().isEmpty &&
              savedDeliveryName.isNotEmpty) {
            _deliveryNameController.text = savedDeliveryName;
          }
          _selectedFarmName = savedFarmName.isEmpty ? null : savedFarmName;
          if (initialFarmName.isNotEmpty) {
            _selectedFarmName = initialFarmName;
            _deliveryNameController.text = initialFarmName;
          }
        }
      });
    }
  }

  Future<void> _saveSugarcaneHistory() async {
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
    await _store.setString(
      _lastSugarcaneCompanyKey,
      _companyController.text.trim(),
    );
    await _store.setString(
      _lastSugarcaneCostKey,
      _costController.text.trim(),
    );
    await _store.setString(
      _lastSugarcaneDeliveryNameKey,
      _deliveryNameController.text.trim(),
    );
    await _store.setString(
      _lastSugarcaneFarmNameKey,
      (_selectedFarmName ?? '').trim(),
    );
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

  Future<void> _initIncomeNumber() async {
    final lastIncomeNo =
        (await _store.getString(_lastFarmIncomeNoKey))?.trim() ?? '1000';
    if (!mounted) return;
    setState(() {
      _incomeNoController.text = _incrementTrackingNumber(lastIncomeNo);
    });
  }

  Future<void> _startSugarcaneFlow() async {
    await _loadSugarcaneHistory();
    await _initTruckingNumber();
    if (!mounted) return;
    setState(() {
      _flow = _LogisticsFlow.sugarcane;
      _selectedCrop = 'Sugarcane';
      _selectedDate = DateTime.now();
      _isAdvanceScheduling = false;
      _selectedFarmName =
          _selectedFarmName?.trim().isEmpty ?? true ? null : _selectedFarmName;
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

  Future<void> _startFarmIncomeFlow({
    _FarmIncomeType type = _FarmIncomeType.equipmentRental,
  }) async {
    await _initIncomeNumber();
    if (!mounted) return;
    setState(() {
      _flow = _LogisticsFlow.farmIncome;
      _selectedCrop = null;
      _selectedDate = DateTime.now();
      _isAdvanceScheduling = false;
      _selectedFarmName = null;
      _savedProduceSummary = null;
      _selectedFarmIncomeType = type;
      _incomeAssetController.clear();
      _incomeClientController.clear();
      _incomeAmountController.clear();
      _noteController.clear();
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
    final restrictFutureDates =
        _flow == _LogisticsFlow.produce || _flow == _LogisticsFlow.farmIncome;
    final today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: restrictFutureDates ? today : DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isAdvanceScheduling =
            !restrictFutureDates && _selectedDate.isAfter(DateTime.now());
      });
      if (_flow == _LogisticsFlow.produce &&
          (_selectedFarmName?.trim().isNotEmpty ?? false)) {
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
    final double allowance =
        double.tryParse(_costController.text.replaceAll(',', '').trim()) ?? 0.0;
    final double rentalCost = _truckingOwnership == _TruckingOwnership.rental
        ? (double.tryParse(
                _rentalCostController.text.replaceAll(',', '').trim()) ??
            0.0)
        : 0.0;
    final double totalTruckingExpense = allowance + rentalCost;
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
            allowance: allowance,
            rentalCost: rentalCost,
            ownership: _truckingOwnership,
          )
        : logisticsNote;
    final String? persistedLogisticsNote =
        enrichedLogisticsNote.isNotEmpty ? enrichedLogisticsNote : null;

    if (isSugarcaneDelivery && allowance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trucking allowance must be greater than zero.'),
        ),
      );
      return;
    }

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
      cost: totalTruckingExpense,
      total: totalTruckingExpense,
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
            dAmount: totalTruckingExpense,
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

    await _saveSugarcaneHistory();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isAdvanceScheduling
            ? 'Transaction scheduled and sugarcane delivery queued.'
            : isSugarcaneDelivery
                ? 'Logistics saved and sugarcane delivery is available for trial profit simulation. Use Harvest Board for official recording.'
                : 'Logistics Record Saved & Financials Updated!')));
    Navigator.pop(context);
  }

  String _buildSugarcaneDeliveryNote({
    required String company,
    required String deliveryName,
    required String note,
    required double allowance,
    required double rentalCost,
    required _TruckingOwnership ownership,
  }) {
    final parts = <String>[
      'Created from Logistics',
      if (company.isNotEmpty) 'Company: $company',
      'Farm/Batch: $deliveryName',
      'Trucking Type: ${ownership == _TruckingOwnership.owned ? 'Owned' : 'Rental'}',
      'Trucking Allowance: ${allowance.toStringAsFixed(2)}',
      if (ownership == _TruckingOwnership.rental)
        'Trucking Rental: ${rentalCost.toStringAsFixed(2)}',
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
        ratoonCount: farm.ratoonCount,
        seasonNumber: farm.seasonNumber + 1,
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

  String get _farmIncomeTypeLabel {
    switch (_selectedFarmIncomeType) {
      case _FarmIncomeType.equipmentRental:
        return 'Equipment Rental';
      case _FarmIncomeType.itemSale:
        return 'Item Sale';
      case _FarmIncomeType.otherIncome:
        return 'Other Income';
    }
  }

  String get _farmIncomeAssetLabel {
    switch (_selectedFarmIncomeType) {
      case _FarmIncomeType.equipmentRental:
        return 'Equipment / Asset';
      case _FarmIncomeType.itemSale:
        return 'Item Sold';
      case _FarmIncomeType.otherIncome:
        return 'Income Source';
    }
  }

  Future<void> _saveFarmIncome() async {
    if (!_formKey.currentState!.validate()) return;

    final income = FarmIncome(
      incomeNo: _incomeNoController.text.trim(),
      date: _selectedDate,
      incomeType: _farmIncomeTypeLabel,
      assetName: ValidationUtils.toTitleCase(_incomeAssetController.text),
      clientName: ValidationUtils.toTitleCase(_incomeClientController.text),
      amount: _parseNumber(_incomeAmountController),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      createdAt: DateTime.now(),
    );

    final summaryParts = <String>[
      'Created from Logistics income generation',
      'Income No: ${income.incomeNo}',
      'Type: ${income.incomeType}',
      'Asset/Item: ${income.assetName}',
      'Client: ${income.clientName}',
      'Amount: ${income.amount.toStringAsFixed(2)}',
      if ((income.note?.trim().isNotEmpty ?? false)) income.note!.trim(),
    ];

    final ftrackerProvider =
        Provider.of<FtrackerProvider>(context, listen: false);
    final farmIncomeProvider =
        Provider.of<FarmIncomeProvider>(context, listen: false);
    final trackerRecord = ftrackerProvider.buildRecord(
      dDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
      dType: 'Income',
      dAmount: income.amount,
      category: 'Farm Income',
      name: '${income.incomeType}: ${income.assetName}',
      note: summaryParts.join(' | '),
    );

    await DatabaseHelper.instance.runInTransaction((txn) async {
      await txn.insert(DatabaseHelper.tableFarmIncome, income.toMap());
      await txn.insert(DatabaseHelper.tableFtracker, trackerRecord.toMap());
    });

    await _store.setString(
      _lastFarmIncomeNoKey,
      _normalizeTrackingValue(_incomeNoController.text),
    );

    await Future.wait([
      farmIncomeProvider.loadRecords(),
      ftrackerProvider.loadFtrackerRecords(),
    ]);

    TransactionLogService.instance.log(
      'Farm income saved',
      details:
          '${income.incomeType} | ${income.assetName} | ${income.clientName} | PHP ${income.amount.toStringAsFixed(2)}',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Farm income saved.'),
      ),
    );

    final nextIncomeNo =
        _incrementTrackingNumber(_incomeNoController.text.trim());
    setState(() {
      _incomeNoController.text = nextIncomeNo;
      _incomeAssetController.clear();
      _incomeClientController.clear();
      _incomeAmountController.clear();
      _noteController.clear();
    });

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
        final farmIncomeProvider = Provider.of<FarmIncomeProvider>(context);
        final recentFarmIncomes = farmIncomeProvider.records.take(4).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: AppVisuals.mainTabBackgroundImageOpacity(
                    deliveryTheme.brightness == Brightness.dark,
                  ),
                  child: Image.asset(
                    'lib/assets/images/1.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppVisuals.mainTabImageOverlay(
                      deliveryTheme.brightness == Brightness.dark,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: _buildFlowContent(
                    deliveryTheme: deliveryTheme,
                    sugarcaneFarmNames: sugarcaneFarmNames,
                    produceFarmNames: produceFarmNames,
                    recentFarmIncomes: recentFarmIncomes,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFlowContent({
    required ThemeData deliveryTheme,
    required List<String> sugarcaneFarmNames,
    required List<String> produceFarmNames,
    required List<FarmIncome> recentFarmIncomes,
  }) {
    switch (_flow) {
      case _LogisticsFlow.sugarcane:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeaderRow(
              title: widget.sugarcaneOnlyMode
                  ? 'Sell Cane'
                  : 'Logistics & Trucking',
              subtitle: widget.sugarcaneOnlyMode
                  ? 'Record one sugarcane truckload for pending payment'
                  : 'Deliveries, haulage and freight intelligence',
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 14),
            if (!widget.sugarcaneOnlyMode) ...[
              _buildIncomeGenerationSection(deliveryTheme),
              const SizedBox(height: 18),
              _buildLogisticsChips(),
              const SizedBox(height: 18),
            ],
            _buildSugarcaneFormCard(deliveryTheme, sugarcaneFarmNames),
          ],
        );
      case _LogisticsFlow.produce:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeaderRow(
              title: '${_selectedCrop ?? 'Produce'} Delivery',
              subtitle:
                  'Capture sacks, weight, deductions, and farm-level profit',
            ),
            const SizedBox(height: 14),
            _buildIncomeGenerationSection(deliveryTheme),
            const SizedBox(height: 18),
            _buildLogisticsChips(),
            const SizedBox(height: 18),
            if (_savedProduceSummary != null) ...[
              _buildSavedProduceSummaryCard(),
              const SizedBox(height: 18),
            ],
            _buildProduceFormCard(deliveryTheme, produceFarmNames),
          ],
        );
      case _LogisticsFlow.farmIncome:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeaderRow(
              title: 'Farm Income Generation',
              subtitle:
                  'Track rental income, item sales, and other farm-generated revenue',
            ),
            const SizedBox(height: 14),
            _buildIncomeGenerationSection(deliveryTheme),
            const SizedBox(height: 18),
            _buildLogisticsChips(),
            const SizedBox(height: 18),
            _buildFarmIncomeFormCard(deliveryTheme),
            const SizedBox(height: 18),
            _buildRecentFarmIncomeCard(deliveryTheme, recentFarmIncomes),
          ],
        );
    }
  }

  Widget _buildIncomeGenerationSection(ThemeData theme) {
    final showDetails = _showInteractionDetails;
    final scheme = theme.colorScheme;
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(24),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Income Generation',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (showDetails) ...[
              const SizedBox(height: 6),
              Text(
                'Produce sales still go through the delivery workflow first. Use the farm income form for equipment rentals, item sales, and other direct income.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final buttons = [
                  _buildIncomeActionButton(
                    icon: Icons.local_shipping_rounded,
                    label: context.localizeText('Sugarcane Delivery'),
                    description: 'Use the trucking and dispatch flow.',
                    selected: _flow == _LogisticsFlow.sugarcane,
                    onPressed: _startSugarcaneFlow,
                  ),
                  _buildIncomeActionButton(
                    icon: Icons.sell_rounded,
                    label: 'Sell Produce',
                    description:
                        'Open the produce delivery form before posting income.',
                    selected: _flow == _LogisticsFlow.produce,
                    onPressed: () => _startProduceFlow(
                      _selectedCrop == 'Corn' ? 'Corn' : 'Rice',
                    ),
                  ),
                  _buildIncomeActionButton(
                    icon: Icons.paid_rounded,
                    label: 'Other Income',
                    description:
                        'Record rentals, item sales, and miscellaneous revenue.',
                    selected: _flow == _LogisticsFlow.farmIncome,
                    onPressed: _startFarmIncomeFlow,
                  ),
                ];

                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[
                        buttons[i],
                        if (i != buttons.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      Expanded(child: buttons[i]),
                      if (i != buttons.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeActionButton({
    required IconData icon,
    required String label,
    required String description,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final showDetails = _showInteractionDetails;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outline.withValues(alpha: 0.28),
        ),
        backgroundColor: selected
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surface.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                if (showDetails) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow({
    required String title,
    required String subtitle,
    VoidCallback? onBack,
  }) {
    final showDetails = _showInteractionDetails;
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: onBack ?? () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (showDetails) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
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
        ChoiceChip(
          label: Text(context.localizeText('Sugarcane Dispatch')),
          selected: _flow == _LogisticsFlow.sugarcane,
          onSelected: (_) {
            if (_flow != _LogisticsFlow.sugarcane) {
              _startSugarcaneFlow();
            }
          },
          selectedColor: scheme.primary.withValues(alpha: 0.18),
          backgroundColor: scheme.surface,
        ),
        ChoiceChip(
          label: Text(context.localizeText('Rice Sale')),
          selected: _flow == _LogisticsFlow.produce && _selectedCrop == 'Rice',
          onSelected: (_) {
            if (!(_flow == _LogisticsFlow.produce && _selectedCrop == 'Rice')) {
              _startProduceFlow('Rice');
            }
          },
          selectedColor: scheme.primary.withValues(alpha: 0.18),
          backgroundColor: scheme.surface,
        ),
        ChoiceChip(
          label: Text(context.localizeText('Corn Sale')),
          selected: _flow == _LogisticsFlow.produce && _selectedCrop == 'Corn',
          onSelected: (_) {
            if (!(_flow == _LogisticsFlow.produce && _selectedCrop == 'Corn')) {
              _startProduceFlow('Corn');
            }
          },
          selectedColor: scheme.primary.withValues(alpha: 0.18),
          backgroundColor: scheme.surface,
        ),
        ChoiceChip(
          label: const Text('Other Income'),
          selected: _flow == _LogisticsFlow.farmIncome,
          onSelected: (_) {
            if (_flow != _LogisticsFlow.farmIncome) {
              _startFarmIncomeFlow();
            }
          },
          selectedColor: scheme.primary.withValues(alpha: 0.18),
          backgroundColor: scheme.surface,
        ),
        Chip(
          label: Text(
            _flow == _LogisticsFlow.farmIncome
                ? 'Posts to income ledger'
                : _autoIncrement
                    ? 'Auto ID mode'
                    : 'Manual entry',
          ),
          backgroundColor: scheme.primary.withValues(alpha: 0.15),
        ),
        if (_flow != _LogisticsFlow.farmIncome)
          Chip(
            label: Text(
                _isAdvanceScheduling ? 'Advance schedule' : 'Dispatch today'),
            backgroundColor: scheme.secondary.withValues(alpha: 0.12),
          ),
      ],
    );
  }

  Widget _buildFarmIncomeTypeChips() {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ChoiceChip(
          label: const Text('Equipment Rental'),
          selected: _selectedFarmIncomeType == _FarmIncomeType.equipmentRental,
          onSelected: (_) {
            setState(() {
              _selectedFarmIncomeType = _FarmIncomeType.equipmentRental;
            });
          },
          selectedColor: scheme.primary.withValues(alpha: 0.18),
        ),
        ChoiceChip(
          label: const Text('Item Sale'),
          selected: _selectedFarmIncomeType == _FarmIncomeType.itemSale,
          onSelected: (_) {
            setState(() {
              _selectedFarmIncomeType = _FarmIncomeType.itemSale;
            });
          },
          selectedColor: scheme.primary.withValues(alpha: 0.18),
        ),
        ChoiceChip(
          label: const Text('Other Income'),
          selected: _selectedFarmIncomeType == _FarmIncomeType.otherIncome,
          onSelected: (_) {
            setState(() {
              _selectedFarmIncomeType = _FarmIncomeType.otherIncome;
            });
          },
          selectedColor: scheme.primary.withValues(alpha: 0.18),
        ),
      ],
    );
  }

  Widget _buildSugarcaneFormCard(
    ThemeData deliveryTheme,
    List<String> sugarcaneFarmNames,
  ) {
    final showDetails = _showInteractionDetails;
    final lockFarmToInitial = widget.sugarcaneOnlyMode &&
        (widget.initialFarmName?.trim().isNotEmpty ?? false);
    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(28),
      color: deliveryTheme.cardColor.withValues(alpha: 0.84),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Income per Truckload',
                style: deliveryTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (showDetails) ...[
                const SizedBox(height: 6),
                Text(
                  widget.sugarcaneOnlyMode
                      ? 'Record the sugarcane truckload for this farm. Pending Payment will compute the harvest income and finalize trucking expenses.'
                      : 'Sugarcane deliveries saved here will appear in the profit tools as trial sources. Use the farm Harvest Board for the official profit record and season tally.',
                  style: deliveryTheme.textTheme.bodySmall?.copyWith(
                    color: deliveryTheme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 12),
              _buildDateRow(),
              const SizedBox(height: 18),
              if (lockFarmToInitial)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: deliveryTheme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: deliveryTheme.colorScheme.primary
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Farm',
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(
                        widget.initialFarmName!.trim(),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                )
              else if (sugarcaneFarmNames.isNotEmpty)
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
              if (lockFarmToInitial || sugarcaneFarmNames.isNotEmpty)
                const SizedBox(height: 18),
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
                label:
                    'Trucking Allowance (Fuel, Backing, Driver\'s share, etc.)',
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
              _buildTruckingOwnershipCard(),
              if (_truckingOwnership == _TruckingOwnership.rental) ...[
                const SizedBox(height: 18),
                FocusTooltip(
                  message: 'Enter the trucking rental cost.',
                  child: TextFormField(
                    stylusHandwritingEnabled: false,
                    controller: _rentalCostController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      _numberInputFormatter
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Trucking Rental Cost',
                      hintText: 'Enter trucking rental cost',
                    ),
                    validator: (value) {
                      if (_truckingOwnership != _TruckingOwnership.rental) {
                        return null;
                      }
                      final amount = double.tryParse(
                          (value ?? '').replaceAll(',', '').trim());
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid trucking rental cost';
                      }
                      return null;
                    },
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _buildNotesField(),
              const SizedBox(height: 24),
              _buildFormActions(
                onSave: _saveLogistics,
                saveLabel:
                    widget.sugarcaneOnlyMode ? 'Save Truckload' : 'Save & Log',
                onCancel: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTruckingOwnershipCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    void selectOwnership(_TruckingOwnership? value) {
      if (value == null) {
        return;
      }
      setState(() {
        _truckingOwnership = value;
        if (value == _TruckingOwnership.owned) {
          _rentalCostController.clear();
        }
      });
    }

    Widget buildOption(
      _TruckingOwnership value,
      String label,
      String description,
    ) {
      final selected = _truckingOwnership == value;
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => selectOwnership(value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.08)
                : scheme.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outline.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<_TruckingOwnership>(value: value),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RadioGroup<_TruckingOwnership>(
      groupValue: _truckingOwnership,
      onChanged: selectOwnership,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trucking',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    buildOption(
                      _TruckingOwnership.owned,
                      'Owned',
                      'No rental cost will be added.',
                    ),
                    const SizedBox(height: 12),
                    buildOption(
                      _TruckingOwnership.rental,
                      'Rental',
                      'Add the trucking rental cost for this load.',
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: buildOption(
                      _TruckingOwnership.owned,
                      'Owned',
                      'No rental cost will be added.',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: buildOption(
                      _TruckingOwnership.rental,
                      'Rental',
                      'Add the trucking rental cost for this load.',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
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
      color: theme.cardColor.withValues(alpha: 0.84),
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
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
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
    final showDetails = _showInteractionDetails;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasFarm = !(_selectedFarmName?.trim().isEmpty ?? true);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
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
          if (showDetails) ...[
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
          ] else
            const SizedBox(height: 10),
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
    final showDetails = _showInteractionDetails;
    return TextFormField(
      stylusHandwritingEnabled: false,
      controller: _overallExpensesController,
      inputFormatters: <TextInputFormatter>[_numberInputFormatter],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Total Recorded Expenses',
        helperText: showDetails
            ? 'Auto-filled from recorded supplies and jobs for this farm. You can edit it.'
            : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null;
        }
        if (double.tryParse(value.replaceAll(',', '').trim()) == null) {
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
      color: deliveryTheme.cardColor.withValues(alpha: 0.84),
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

  Widget _buildFarmIncomeFormCard(ThemeData deliveryTheme) {
    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(28),
      color: deliveryTheme.cardColor.withValues(alpha: 0.84),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                stylusHandwritingEnabled: false,
                controller: _incomeNoController,
                decoration: const InputDecoration(
                  labelText: 'Income No.',
                  helperText:
                      'Editable. The next entry auto-increments from the last saved value.',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Income number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _buildDateRow(),
              const SizedBox(height: 18),
              _buildFarmIncomeTypeChips(),
              const SizedBox(height: 18),
              TextFormField(
                stylusHandwritingEnabled: false,
                controller: _incomeAssetController,
                decoration: InputDecoration(
                  labelText: _farmIncomeAssetLabel,
                  helperText: _selectedFarmIncomeType ==
                          _FarmIncomeType.equipmentRental
                      ? 'Example: Hand tractor, thresher, trailer, water pump'
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                stylusHandwritingEnabled: false,
                controller: _incomeClientController,
                decoration: const InputDecoration(
                  labelText: 'Client Name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Client name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _buildNumericField(
                controller: _incomeAmountController,
                label: 'Income Generated',
              ),
              const SizedBox(height: 18),
              _buildNotesField(
                label: 'Notes / Terms',
                hint:
                    'Optional: include rental duration, sold item details, or client notes',
              ),
              const SizedBox(height: 24),
              _buildFormActions(
                onSave: _saveFarmIncome,
                saveLabel: 'Save Farm Income',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFarmIncomeCard(
    ThemeData deliveryTheme,
    List<FarmIncome> records,
  ) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(26),
      color: deliveryTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Income Entries',
              style: deliveryTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              records.isEmpty
                  ? 'No farm income entries recorded yet.'
                  : 'Latest rentals, item sales, and miscellaneous income posted from this tab.',
              style: deliveryTheme.textTheme.bodySmall?.copyWith(
                color: deliveryTheme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (records.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (var i = 0; i < records.length; i++) ...[
                _buildRecentFarmIncomeTile(deliveryTheme, records[i]),
                if (i != records.length - 1) const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentFarmIncomeTile(ThemeData theme, FarmIncome record) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.assetName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'PHP ${_formatAmount(record.amount)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${record.incomeType} | ${record.clientName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${record.incomeNo} • ${DateFormat.yMMMd().format(record.date)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (record.note?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              record.note!.trim(),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
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
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
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
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
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
    final showDetails = _showInteractionDetails;
    return TextFormField(
      stylusHandwritingEnabled: false,
      controller: _produceDeliveryNoController,
      decoration: InputDecoration(
        labelText: 'Delivery No.',
        helperText: showDetails
            ? 'Editable. The next entry auto-increments from the last saved value.'
            : null,
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
    final showDetails = _showInteractionDetails;
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
            });
            _initTruckingNumber();
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
            helperText: showDetails
                ? (_autoIncrement
                    ? 'Editable. Auto-increment uses the last digits in this value.'
                    : 'Manual entry mode.')
                : null,
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
    final cancelButton = Tooltip(
      message: 'Close this form without saving changes.',
      child: OutlinedButton(
        onPressed: onCancel ?? () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    );
    final saveButton = Tooltip(
      message: 'Save this form entry.',
      child: ElevatedButton.icon(
        onPressed: onSave,
        icon: const Icon(Icons.save),
        label: Text(saveLabel),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
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
        return FocusTooltip(
          message: 'Enter $label.',
          child: TextFormField(
            stylusHandwritingEnabled: false,
            controller: fieldController,
            focusNode: focusNode,
            keyboardType: keyboardType,
            inputFormatters: keyboardType == TextInputType.number
                ? <TextInputFormatter>[_numberInputFormatter]
                : null,
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
          ),
        );
      },
    );
  }

  Widget _buildNotesField({
    String label = 'Notes / Comments',
    String? hint,
  }) {
    return FocusTooltip(
      message: 'Enter $label.',
      child: TextFormField(
        stylusHandwritingEnabled: false,
        controller: _noteController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required String label,
    String? suffixText,
  }) {
    return FocusTooltip(
      message: 'Enter $label.',
      child: TextFormField(
        stylusHandwritingEnabled: false,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[_numberInputFormatter],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Required';
          }
          if (double.tryParse(value.replaceAll(',', '').trim()) == null) {
            return 'Enter a valid number';
          }
          return null;
        },
        onChanged: (_) => setState(() {}),
      ),
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
