import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_audio_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/activity_provider.dart';
import '../providers/data_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/ftracker_provider.dart';
import '../providers/worker_provider.dart';
import '../models/activity_model.dart';
import '../models/work_def_model.dart';
import '../models/supply_model.dart';
import '../services/database_helper.dart';
import '../services/app_route_observer.dart';
import '../services/transaction_log_service.dart';
import '../utils/app_number_input_formatter.dart';
import '../utils/validation_utils.dart';
import '../widgets/focus_tooltip.dart';
import '../widgets/searchable_dropdown.dart';
import 'scr_workers.dart';

class FrmAddJob2 extends StatefulWidget {
  final String? editJobId;
  final String? initialFName;

  const FrmAddJob2({super.key, this.editJobId, this.initialFName});

  @override
  State<FrmAddJob2> createState() => _FrmAddJob2State();
}

class _FrmAddJob2State extends State<FrmAddJob2> with RouteAware {
  static const String _kAddWorkerOption = '__add_worker__';
  static const String _kManualWorkerOption = '__manual_worker__';

  // Logical Variables
  String _rdo = ''; // Manual or Equipment
  bool _isJobFrameLocked = true;
  bool _manualWorkerEntryEnabled = false;
  String _wName = '';
  double? _hectareRate;
  WorkDef? _selectedManualWorkDef;
  Supply? _selectedSupplyItem;
  int? _supplyUsedQty;
  bool _playedScreenOpenAudio = false;
  bool _isRouteObserverSubscribed = false;

  AppSettingsProvider? _appSettings;
  AppAudioProvider? _appAudio;
  static final _numberInputFormatter = AppNumberInputFormatter();

  // Controllers
  final Map<String, TextEditingController> _controllers = {
    'Date': TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now())),
    'Worker': TextEditingController(),
    'Duration': TextEditingController(text: '1'),
    'Cost': TextEditingController(),
    'Total': TextEditingController(),
    'Note': TextEditingController(),
  };

  // Focus Nodes
  final Map<String, FocusNode> _focusNodes = {
    'Worker': FocusNode(),
    'Duration': FocusNode(),
    'Cost': FocusNode(),
    'Note': FocusNode(),
    'save': FocusNode(),
  };

  // Selections
  String? _selectedFarm;
  String? _selectedBox;
  String? _selectedSup;
  String? _selectedE;
  String? _selectedRntl;

  bool get _isOwnedEquipmentJob =>
      _rdo == 'Equipment' && _selectedRntl == 'Owned';

  @override
  void initState() {
    super.initState();
    _selectedFarm = widget.initialFName;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SuppliesProvider>(context, listen: false).loadSupplies();
      Provider.of<WorkerProvider>(context, listen: false).loadWorkers();
      _playScreenOpenAudioIfNeeded();
      if (widget.editJobId != null) {
        _loadEditData();
      }
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
      screenKey: 'add_job',
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
      screenKey: 'add_job',
      style: appSettings.audioSoundStyle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _appSettings ??= Provider.of<AppSettingsProvider>(context, listen: false);
    _appAudio ??= Provider.of<AppAudioProvider>(context, listen: false);

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
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
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

  void _loadEditData() {
    final activityProvider =
        Provider.of<ActivityProvider>(context, listen: false);
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final job = activityProvider.activities
        .firstWhere((a) => a.jobId == widget.editJobId);
    final matchedWorkDef = _findWorkDef(
      defs: dataProvider.workDefs,
      name: job.name,
      modeOfWork: job.labor == 'Manual' ? job.costType : null,
    );

    setState(() {
      _selectedFarm = job.farm;
      _rdo = job.labor;
      _wName = job.name;
      _manualWorkerEntryEnabled = true;
      _selectedBox = job.name;
      _selectedManualWorkDef = matchedWorkDef;
      _selectedRntl = job.labor == 'Equipment' ? job.costType : null;
      _selectedE = job.assetUsed;

      _controllers['Date']!.text = DateFormat('yyyy-MM-dd').format(job.date);
      _controllers['Duration']!.text = job.duration.toString();
      _controllers['Cost']!.text = job.cost.toString();
      _controllers['Total']!.text = job.total.toString();
      _controllers['Worker']!.text = job.worker;
      _controllers['Note']!.text = job.note ?? '';

      _isJobFrameLocked = false;
    });

    _checkUnlock();
  }

  void _updateCalculations() {
    if (_isOwnedEquipmentJob) {
      _controllers['Cost']!.text = '0.00';
      _controllers['Total']!.text = '0.00';
      return;
    }
    double cost =
        double.tryParse(_controllers['Cost']!.text.replaceAll(',', '')) ?? 0.0;
    double duration =
        double.tryParse(_controllers['Duration']!.text.replaceAll(',', '')) ??
            0.0;
    _controllers['Total']!.text = (cost * duration).toStringAsFixed(2);
  }

  WorkDef? _findWorkDef({
    required List<WorkDef> defs,
    String? name,
    String? modeOfWork,
  }) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    if (modeOfWork != null && modeOfWork.trim().isNotEmpty) {
      for (final def in defs) {
        if (def.name == name && def.modeOfWork == modeOfWork) {
          return def;
        }
      }
    }
    for (final def in defs) {
      if (def.name == name) {
        return def;
      }
    }
    return null;
  }

  void _checkUnlock() {
    bool canUnlock = false;
    if (_rdo == 'Manual' &&
        _selectedBox != null &&
        _selectedManualWorkDef != null) {
      canUnlock = true;
      _wName = _selectedBox!;
    } else if (_rdo == 'Equipment' && _selectedRntl != null) {
      if (_selectedRntl == 'Owned') canUnlock = true;
      if (_selectedRntl == 'Rental' && _hectareRate != null) canUnlock = true;
      _wName = _selectedBox ?? 'Equipment Work';
    }

    _isJobFrameLocked = !canUnlock;
  }

  void _setLaborType(String laborType) {
    if (_rdo == laborType) {
      return;
    }

    setState(() {
      _rdo = laborType;
      _selectedBox = null;

      if (laborType == 'Manual') {
        _selectedRntl = null;
        _selectedE = null;
        _hectareRate = null;
        _selectedManualWorkDef = null;
        _wName = '';
      } else {
        _selectedSup = null;
        _selectedSupplyItem = null;
        _supplyUsedQty = null;
        _wName = 'Equipment Work';
      }

      _checkUnlock();
      _updateCalculations();
    });
  }

  /// Implementation of CHECKDATA
  bool _runCheckData() {
    // Validate Worker
    String? workerError = ValidationUtils.checkData(
        value: _controllers['Worker']!.text, fieldName: 'Worker');
    if (workerError != null) {
      _showFormatError('Worker', workerError);
      return false;
    }
    _controllers['Worker']!.text =
        ValidationUtils.toTitleCase(_controllers['Worker']!.text);

    // Validate Cost
    String? costError = ValidationUtils.checkData(
        value: _controllers['Cost']!.text,
        fieldName: 'Cost',
        isNumeric: true,
        allowZero: _isOwnedEquipmentJob);
    if (costError != null) {
      _showFormatError('Cost', costError);
      return false;
    }

    // Validate Duration
    String? durationError = ValidationUtils.checkData(
        value: _controllers['Duration']!.text,
        fieldName: 'Duration',
        isNumeric: true);
    if (durationError != null) {
      _showFormatError('Duration', durationError);
      return false;
    }

    return true;
  }

  void _showFormatError(String field, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Wrong format: $message'),
        backgroundColor: Colors.redAccent));
    final focusTarget = _focusNodes[field];
    if (focusTarget != null) {
      FocusScope.of(context).requestFocus(focusTarget);
    }
  }

  void _saveAction() async {
    final shouldContinue = await _promptToAddManualWorkerIfNeeded();
    if (!shouldContinue) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (!_runCheckData()) return;

    final costAmount = _isOwnedEquipmentJob
        ? 0.0
        : double.tryParse(_controllers['Cost']!.text.replaceAll(',', '')) ??
            0.0;
    final totalAmount = _isOwnedEquipmentJob
        ? 0.0
        : double.tryParse(_controllers['Total']!.text.replaceAll(',', '')) ??
            0.0;
    final trackerCategory = _rdo == 'Equipment' ? 'Equipment' : 'Labor';
    final trackerNote = _controllers['Note']!.text.trim();
    final activityNote = trackerNote.isNotEmpty ? trackerNote : null;
    final shouldRecordFinancials = totalAmount > 0;

    final activity = Activity(
      jobId:
          widget.editJobId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      tag: 'Job',
      date: DateFormat('yyyy-MM-dd').parse(_controllers['Date']!.text),
      farm: _selectedFarm!,
      name: _wName,
      labor: _rdo,
      assetUsed: _resolveAssetUsed(),
      costType: _rdo == 'Manual'
          ? (_selectedManualWorkDef?.modeOfWork ?? 'Manual')
          : (_selectedRntl ?? 'Manual'),
      duration:
          double.tryParse(_controllers['Duration']!.text.replaceAll(',', '')) ??
              0.0,
      cost: costAmount,
      total: totalAmount,
      worker: _controllers['Worker']!.text,
      note: activityNote,
    );

    final provider = Provider.of<ActivityProvider>(context, listen: false);
    final suppliesProvider =
        Provider.of<SuppliesProvider>(context, listen: false);
    final ftrackerProvider =
        Provider.of<FtrackerProvider>(context, listen: false);
    if (widget.editJobId == null) {
      final updatedSupply = _buildSupplyUsageUpdate();
      final trackerRecord = shouldRecordFinancials
          ? ftrackerProvider.buildRecord(
              dDate: _controllers['Date']!.text,
              dType: 'Expenses',
              dAmount: totalAmount,
              category: trackerCategory,
              name: activity.name,
              note: trackerNote.isNotEmpty ? trackerNote : null,
            )
          : null;

      await DatabaseHelper.instance.runInTransaction((txn) async {
        await txn.insert(DatabaseHelper.tableActivities, activity.toMap());

        if (updatedSupply != null) {
          await txn.update(
            DatabaseHelper.tableSupplies,
            updatedSupply.toMap(),
            where: 'id = ?',
            whereArgs: [updatedSupply.id],
          );
        }

        if (trackerRecord != null) {
          await txn.insert(DatabaseHelper.tableFtracker, trackerRecord.toMap());
        }
      });

      final reloads = <Future<void>>[provider.loadActivities()];
      if (updatedSupply != null) {
        reloads.add(suppliesProvider.loadSupplies());
      }
      if (trackerRecord != null) {
        reloads.add(ftrackerProvider.loadFtrackerRecords());
      }
      await Future.wait(reloads);

      TransactionLogService.instance.log(
        'Activity added',
        details:
            '${activity.name} @ ${activity.farm} | ${activity.labor} | PHP ${activity.total.toStringAsFixed(2)}',
      );
      if (updatedSupply != null) {
        TransactionLogService.instance.log(
          'Supply updated',
          details: '${updatedSupply.name} | qty=${updatedSupply.quantity}',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(shouldRecordFinancials
                ? 'New Job Order finalized & Financials updated'
                : 'New Job Order finalized')));
      }
    } else {
      await provider.updateActivity(activity);
      await provider.loadActivities();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job Order updated')),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  String _resolveAssetUsed() {
    if (_rdo == 'Equipment') {
      if ((_selectedE?.trim().isNotEmpty ?? false)) {
        return _selectedE!;
      }
      return _selectedRntl == 'Owned' ? 'Owned Equipment' : 'Rental Equipment';
    }
    if ((_selectedSup?.trim().isNotEmpty ?? false)) {
      return _selectedSup!;
    }
    return 'None';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = Provider.of<DataProvider>(context);
    final farms = Provider.of<FarmProvider>(context);
    final equips = Provider.of<EquipmentProvider>(context);
    final supplies = Provider.of<SuppliesProvider>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Job Order'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildFraWork(data, farms, equips, supplies),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(thickness: 1, color: Colors.black12),
              ),
              _buildFraJob(data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFraWork(DataProvider data, FarmProvider farmProv,
      EquipmentProvider equipProv, SuppliesProvider supProv) {
    final manualWorkDefs = data.workDefs
        .where((w) => w.type == 'Manual')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final selectedManualModes = <WorkDef>[
      if (_selectedBox != null)
        ...manualWorkDefs.where((def) => def.name == _selectedBox),
    ]..sort((a, b) => a.modeOfWork.compareTo(b.modeOfWork));
    final manualWorkDefNames =
        manualWorkDefs.map((w) => w.name).toSet().toList();
    final farmNames = farmProv.farms.map((f) => f.name).toSet().toList();
    final safeSelectedFarm =
        farmNames.contains(_selectedFarm) ? _selectedFarm : null;
    final manualSupplies = supProv.items;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. LABOR CONFIGURATION',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 16),
          SearchableDropdownFormField<String>(
            initialValue: safeSelectedFarm,
            decoration: const InputDecoration(labelText: 'ESTATE'),
            items: farmNames
                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedFarm = v;
              _checkUnlock();
            }),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildRdoTile('Manual', _rdo == 'Manual',
                      () => _setLaborType('Manual'))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildRdoTile('Equipment', _rdo == 'Equipment',
                      () => _setLaborType('Equipment'))),
            ],
          ),
          if (_rdo == 'Manual') ...[
            const SizedBox(height: 20),
            SearchableDropdownFormField<String>(
              isExpanded: true,
              initialValue: _selectedBox,
              decoration: const InputDecoration(labelText: 'TASK'),
              items: manualWorkDefNames
                  .map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name,
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedBox = v;
                _selectedManualWorkDef = null;
                _controllers['Cost']!.clear();
                _controllers['Total']!.clear();
                _checkUnlock();
              }),
            ),
            const SizedBox(height: 16),
            SearchableDropdownFormField<String>(
              isExpanded: true,
              initialValue: selectedManualModes.any(
                (def) => def.modeOfWork == _selectedManualWorkDef?.modeOfWork,
              )
                  ? _selectedManualWorkDef?.modeOfWork
                  : null,
              decoration: const InputDecoration(labelText: 'MODE OF WORK'),
              hint: _selectedBox == null
                  ? const Text('Select a task first')
                  : null,
              items: selectedManualModes
                  .map((def) => DropdownMenuItem(
                        value: def.modeOfWork,
                        child: Text(def.modeOfWork),
                      ))
                  .toList(),
              onChanged: _selectedBox == null
                  ? null
                  : (value) => setState(() {
                        _selectedManualWorkDef = _findWorkDef(
                          defs: selectedManualModes,
                          name: _selectedBox,
                          modeOfWork: value,
                        );
                        if (_selectedManualWorkDef != null) {
                          _controllers['Cost']!.text =
                              _selectedManualWorkDef!.cost.toStringAsFixed(2);
                          _updateCalculations();
                        }
                        _checkUnlock();
                      }),
            ),
            if (_selectedManualWorkDef != null) ...[
              const SizedBox(height: 12),
              _buildManualWorkSummary(_selectedManualWorkDef!),
            ],
            const SizedBox(height: 16),
            SearchableDropdownFormField<String>(
              initialValue: _selectedSup,
              decoration: const InputDecoration(labelText: 'Resources'),
              hint: manualSupplies.isEmpty
                  ? const Text('Add supplies in the Supplies tab')
                  : null,
              items: manualSupplies
                  .map((s) => DropdownMenuItem(
                        value: s.name,
                        child: Text('${s.name} (${s.quantity} left)'),
                      ))
                  .toList(),
              onChanged: manualSupplies.isEmpty
                  ? null
                  : (value) => _handleSupplySelection(value, supProv),
            ),
          ],
          if (_rdo == 'Equipment') ...[
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                RadioGroup<String>(
                  groupValue: _selectedRntl,
                  onChanged: _handleRentalSelection,
                  child: Column(
                    children: const [
                      RadioListTile<String>(
                        value: 'Rental',
                        title: Text('Rental'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        value: 'Owned',
                        title: Text('Owned'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRdoTile(String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11)),
      ),
    );
  }

  Widget _buildManualWorkSummary(WorkDef workDef) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MODE OF WORK',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            workDef.modeOfWork.isEmpty ? 'Not specified' : workDef.modeOfWork,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Default labor cost: ${workDef.cost.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _handleRentalSelection(String? value) async {
    if (value == null) return;
    if (value == 'Rental') {
      final rate = await _promptRentalRateDialog();
      if (rate == null) return;
      setState(() {
        _selectedRntl = value;
        _hectareRate = rate;
        _controllers['Cost']!.text = rate.toStringAsFixed(2);
        _updateCalculations();
        _checkUnlock();
      });
    } else {
      setState(() {
        _selectedRntl = value;
        _hectareRate = null;
        _controllers['Cost']!.text = '0.00';
        _controllers['Total']!.text = '0.00';
        _checkUnlock();
      });
    }
  }

  Future<double?> _promptRentalRateDialog() async {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('How much per hectare?'),
            content: TextField(
              stylusHandwritingEnabled: false,
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Rate',
                helperText: 'Enter a numeric value',
                prefixText: '₱ ',
                errorText: errorText,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final parsed =
                      double.tryParse(controller.text.replaceAll(',', ''));
                  if (parsed == null) {
                    setState(() => errorText = 'Enter a numeric value');
                    return;
                  }
                  if (parsed <= 0) {
                    setState(() => errorText = 'Rate must be above zero');
                    return;
                  }
                  Navigator.of(ctx).pop(parsed);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleSupplySelection(
      String? value, SuppliesProvider provider) async {
    if (value == null || value.isEmpty) return;
    Supply? selected;
    for (final item in provider.items) {
      if (item.name == value) {
        selected = item;
        break;
      }
    }
    if (selected == null) return;
    await _processSupplyUsage(selected);
  }

  Future<void> _processSupplyUsage(Supply supply) async {
    if (supply.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${supply.name} is out of stock.'),
          backgroundColor: Colors.redAccent));
      return;
    }

    final used = await _promptSupplyUsageDialog(supply);
    if (used == null) {
      return;
    }

    setState(() {
      _selectedSup = supply.name;
      _selectedSupplyItem = supply;
      _supplyUsedQty = used;
    });
  }

  Future<int?> _promptSupplyUsageDialog(Supply supply) async {
    final controller = TextEditingController(text: '1');
    String? errorText;

    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('How many ${supply.name}?'),
            content: TextField(
              stylusHandwritingEnabled: false,
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              decoration: InputDecoration(
                labelText: 'Quantity to use',
                helperText: 'Available ${supply.quantity}',
                errorText: errorText,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final parsed = int.tryParse(controller.text);
                  if (parsed == null || parsed <= 0) {
                    setState(() => errorText = 'Enter a positive number');
                    return;
                  }
                  if (parsed > supply.quantity) {
                    setState(() => errorText =
                        'Only ${supply.quantity} unit(s) available');
                    return;
                  }
                  Navigator.of(ctx).pop(parsed);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  Supply? _buildSupplyUsageUpdate() {
    if (_selectedSupplyItem == null ||
        _supplyUsedQty == null ||
        _supplyUsedQty! <= 0) {
      return null;
    }

    final used = _supplyUsedQty!;
    final remaining = _selectedSupplyItem!.quantity - used;
    final updatedQuantity = remaining < 0 ? 0 : remaining;

    return Supply(
      id: _selectedSupplyItem!.id,
      name: _selectedSupplyItem!.name,
      description: _selectedSupplyItem!.description,
      quantity: updatedQuantity,
      cost: _selectedSupplyItem!.cost,
      total: _selectedSupplyItem!.cost * updatedQuantity,
    );
  }

  Widget _buildFraJob(DataProvider data) {
    final workerProvider = Provider.of<WorkerProvider>(context);
    return AbsorbPointer(
      absorbing: _isJobFrameLocked,
      child: Opacity(
        opacity: _isJobFrameLocked ? 0.4 : 1.0,
        child: Column(
          children: [
            _buildWorkerDropdown(workerProvider),
            Row(
              children: [
                Expanded(
                    child: _buildJobField('Duration',
                        isNumeric: true, nextNode: _focusNodes['Cost'])),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildJobField('Cost',
                        isNumeric: true,
                        isReadOnly: _isOwnedEquipmentJob,
                        nextNode: _focusNodes['Note'])),
              ],
            ),
            _buildJobField('Total', isReadOnly: true),
            _buildJobField('Note', nextNode: _focusNodes['save']),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              focusNode: _focusNodes['save'],
              onPressed: _saveAction,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('FINALIZE TRANSACTION'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerDropdown(WorkerProvider workerProvider) {
    final workerNames = workerProvider.workers
        .map((worker) => worker.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final currentWorker = _controllers['Worker']!.text.trim();
    final showManualEntry = _manualWorkerEntryEnabled ||
        workerNames.isEmpty ||
        (currentWorker.isNotEmpty && !workerNames.contains(currentWorker));
    final dropdownOptions = <String>[
      ...workerNames,
      _kManualWorkerOption,
      _kAddWorkerOption,
    ];
    final selectedWorker =
        dropdownOptions.contains(currentWorker) ? currentWorker : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          SearchableDropdownFormField<String>(
            initialValue: selectedWorker,
            focusNode: _focusNodes['Worker'],
            decoration: const InputDecoration(labelText: 'WORKER'),
            hint: Text(
              workerNames.isEmpty
                  ? 'No employees yet. Add one or enter a name manually'
                  : 'Select a worker, enter manually, or add a new employee',
            ),
            items: dropdownOptions
                .map(
                  (workerName) => DropdownMenuItem(
                    value: workerName,
                    child: Text(_workerDropdownLabel(workerName)),
                  ),
                )
                .toList(),
            onChanged: (selection) =>
                _handleWorkerSelection(selection, workerProvider),
            validator: (_) {
              if (_controllers['Worker']!.text.trim().isEmpty) {
                return 'Select or enter a worker';
              }
              return null;
            },
          ),
          if (showManualEntry) ...[
            const SizedBox(height: 12),
            TextFormField(
              stylusHandwritingEnabled: false,
              controller: _controllers['Worker'],
              focusNode: _focusNodes['Worker'],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'WORKER NAME',
                helperText:
                    'Manual entry is allowed. You can add this name to Employees after typing it.',
              ),
              onChanged: (_) {
                if (!_manualWorkerEntryEnabled) {
                  setState(() {
                    _manualWorkerEntryEnabled = true;
                  });
                }
              },
              onFieldSubmitted: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    FocusScope.of(context)
                        .requestFocus(_focusNodes['Duration']);
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  String _workerDropdownLabel(String workerName) {
    switch (workerName) {
      case _kManualWorkerOption:
        return 'Enter employee name manually';
      case _kAddWorkerOption:
        return 'Add a new employee';
      default:
        return workerName;
    }
  }

  Future<void> _handleWorkerSelection(
    String? selection,
    WorkerProvider workerProvider,
  ) async {
    if (selection == null) {
      return;
    }
    if (selection == _kManualWorkerOption) {
      setState(() {
        _manualWorkerEntryEnabled = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).requestFocus(_focusNodes['Worker']);
        }
      });
      return;
    }
    if (selection == _kAddWorkerOption) {
      await _openAddWorkerScreen(
        initialName: _controllers['Worker']!.text.trim(),
        workerProvider: workerProvider,
      );
      return;
    }

    setState(() {
      _manualWorkerEntryEnabled = false;
      _controllers['Worker']!.text = selection;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNodes['Duration']);
      }
    });
  }

  Future<bool> _promptToAddManualWorkerIfNeeded() async {
    final rawWorker = _controllers['Worker']!.text.trim();
    if (rawWorker.isEmpty) {
      return true;
    }

    final normalizedWorker = ValidationUtils.toTitleCase(rawWorker);
    _controllers['Worker']!.text = normalizedWorker;
    final workerProvider = Provider.of<WorkerProvider>(context, listen: false);
    final workerExists = workerProvider.workers.any(
      (worker) =>
          worker.name.trim().toLowerCase() == normalizedWorker.toLowerCase(),
    );
    if (workerExists) {
      return true;
    }

    final shouldAdd = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add this worker to Employees?'),
            content: Text(
              '$normalizedWorker is not in the employee database yet. Do you want to add a new employee record now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldAdd) {
      return true;
    }

    await _openAddWorkerScreen(
      initialName: normalizedWorker,
      workerProvider: workerProvider,
    );
    return true;
  }

  Future<void> _openAddWorkerScreen({
    required WorkerProvider workerProvider,
    String? initialName,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrmAddEditWorker(initialName: initialName),
      ),
    );
    await workerProvider.loadWorkers();
    if (!mounted) {
      return;
    }
    setState(() {
      _manualWorkerEntryEnabled =
          _controllers['Worker']!.text.trim().isNotEmpty &&
              !workerProvider.workers.any(
                (worker) =>
                    worker.name.trim().toLowerCase() ==
                    _controllers['Worker']!.text.trim().toLowerCase(),
              );
    });
  }

  Widget _buildJobField(String label,
      {bool isNumeric = false, bool isReadOnly = false, FocusNode? nextNode}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FocusTooltip(
        message: isReadOnly ? '$label is auto-computed.' : 'Enter $label.',
        child: TextFormField(
          stylusHandwritingEnabled: false,
          controller: _controllers[label],
          focusNode: _focusNodes[label],
          readOnly: isReadOnly,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters:
              isNumeric ? <TextInputFormatter>[_numberInputFormatter] : null,
          onChanged: (_) => _updateCalculations(),
          decoration: InputDecoration(labelText: label.toUpperCase()),
          onFieldSubmitted: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (nextNode != null) {
                  FocusScope.of(context).requestFocus(nextNode);
                } else if (label == 'Note') {
                  _saveAction();
                }
              }
            });
          },
        ),
      ),
    );
  }
}
