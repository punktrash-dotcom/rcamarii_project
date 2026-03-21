import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/delivery_model.dart';
import '../providers/activity_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/ftracker_provider.dart';
import '../providers/voice_command_provider.dart';
import '../models/activity_model.dart';
import '../services/database_helper.dart';
import '../services/transaction_log_service.dart';
import '../themes/custom_themes.dart';
import '../utils/validation_utils.dart';
import '../widgets/searchable_dropdown.dart';

class FrmLogistics extends StatefulWidget {
  const FrmLogistics({super.key});

  @override
  State<FrmLogistics> createState() => _FrmLogisticsState();
}

class _FrmLogisticsState extends State<FrmLogistics> {
  static const _lastTruckingIdKey = 'last_trucking_id';
  static const _legacyLastTruckingNumKey = 'last_trucking_num';
  final _formKey = GlobalKey<FormState>();

  // State Variables
  DateTime _selectedDate = DateTime.now();
  String? _selectedCrop;
  bool _autoIncrement = true;
  bool _isAdvanceScheduling = false;

  // Historical data for auto-complete
  List<String> _historicalCompanies = [];
  List<String> _historicalCosts = [];

  // Controllers
  final _truckingNumController = TextEditingController();
  final _companyController = TextEditingController();
  final _costController = TextEditingController();
  final _deliveryNameController = TextEditingController();
  final _noteController = TextEditingController();

  final List<String> _cropOptions = ['Sugarcane', 'Rice', 'Corn', 'Coconut'];
  String? _selectedFarmName;

  @override
  void initState() {
    super.initState();
    // Ensure all initial data loading happens after the first build frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadHistory();
        _initTruckingNumber();
        Provider.of<FarmProvider>(context, listen: false).refreshFarms();
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
    super.dispose();
  }

  Future<void> _initTruckingNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTrackingId = _readLastTrackingId(prefs);
    if (_autoIncrement && mounted) {
      setState(() {
        _truckingNumController.text = _incrementTrackingNumber(lastTrackingId);
      });
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _historicalCompanies = prefs.getStringList('history_companies') ?? [];
        _historicalCosts = prefs.getStringList('history_costs') ?? [];

        if (prefs.getBool('save_for_next') ?? false) {
          _companyController.text = prefs.getString('last_company') ?? '';
          String? lastCrop = prefs.getString('last_crop');
          // Validation: Ensure the loaded crop is in our valid options
          if (lastCrop != null && _cropOptions.contains(lastCrop)) {
            _selectedCrop = lastCrop;
          } else {
            _selectedCrop = null;
          }
        }
      });
    }
  }

  Future<void> _saveToHistory() async {
    final prefs = await SharedPreferences.getInstance();

    // Update company history
    if (!_historicalCompanies.contains(_companyController.text) &&
        _companyController.text.isNotEmpty) {
      _historicalCompanies.add(_companyController.text);
      await prefs.setStringList('history_companies', _historicalCompanies);
    }

    // Update cost history
    if (!_historicalCosts.contains(_costController.text) &&
        _costController.text.isNotEmpty) {
      _historicalCosts.add(_costController.text);
      await prefs.setStringList('history_costs', _historicalCosts);
    }

    await prefs.setString(
      _lastTruckingIdKey,
      _normalizeTrackingValue(_truckingNumController.text),
    );
    await prefs.setString('last_company', _companyController.text);
    await prefs.setString('last_crop', _selectedCrop ?? '');
  }

  String _readLastTrackingId(SharedPreferences prefs) {
    final storedTrackingId = prefs.getString(_lastTruckingIdKey);
    if (storedTrackingId != null && storedTrackingId.trim().isNotEmpty) {
      return storedTrackingId.trim();
    }

    final legacyNumber = prefs.getInt(_legacyLastTruckingNumKey);
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isAdvanceScheduling = _selectedDate.isAfter(DateTime.now());
      });
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
    final trackerRecord = ftrackerProvider.buildRecord(
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
        await txn.insert(DatabaseHelper.tableFtracker, trackerRecord.toMap());
        await txn.insert(DatabaseHelper.tableDeliveries, delivery.toMap());
      });
    } else {
      await DatabaseHelper.instance.runInTransaction((txn) async {
        await txn.insert(DatabaseHelper.tableActivities, activity.toMap());
        await txn.insert(DatabaseHelper.tableFtracker, trackerRecord.toMap());
      });
    }

    final reloads = <Future<void>>[
      activityProvider.loadActivities(),
      ftrackerProvider.loadFtrackerRecords(),
    ];
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('save_for_next', saveForNext);
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
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(voiceProvider),
                    const SizedBox(height: 14),
                    _buildLogisticsChips(),
                    const SizedBox(height: 18),
                    Material(
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
                              _buildDropdown('Crop Involved', _cropOptions),
                              if (_selectedCrop == 'Sugarcane') ...[
                                const SizedBox(height: 18),
                                if (sugarcaneFarmNames.isNotEmpty)
                                  SearchableDropdownFormField<String>(
                                    initialValue: sugarcaneFarmNames
                                            .contains(_selectedFarmName)
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
                                if (sugarcaneFarmNames.isNotEmpty)
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
                                    if (_selectedCrop == 'Sugarcane' &&
                                        (value?.trim().isEmpty ?? true)) {
                                      return 'Required for sugarcane deliveries';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Sugarcane deliveries saved here will appear in the profit calculator as recent or pending delivery sources. Enter the actual weight later when the weekly report arrives.',
                                  style: deliveryTheme.textTheme.bodySmall
                                      ?.copyWith(
                                    color: deliveryTheme
                                        .colorScheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              _buildTruckingRow(),
                              const SizedBox(height: 20),
                              _buildAutocompleteField(
                                label: 'Association/Buyer',
                                controller: _companyController,
                                optionsBuilder: (editing) {
                                  if (editing.text.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  return _historicalCompanies.where((c) => c
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
                                keyboardType: TextInputType.number,
                                optionsBuilder: (editing) {
                                  if (editing.text.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  return _historicalCosts
                                      .where((c) => c.contains(editing.text));
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
                              _buildFormActions(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeaderRow(VoiceCommandProvider voiceProvider) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logistics & Trucking',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Deliveries, haulage and freight intelligence',
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

  Widget _buildFormActions() {
    final cancelButton = OutlinedButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancel'),
    );
    final saveButton = ElevatedButton.icon(
      onPressed: _saveLogistics,
      icon: const Icon(Icons.save),
      label: const Text('Save & Log'),
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
          decoration: InputDecoration(labelText: label),
          onChanged: (value) {
            controller.text = value;
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

  Widget _buildDropdown(String label, List<String> items) {
    final currentValue = items.contains(_selectedCrop) ? _selectedCrop : null;
    return SearchableDropdownFormField<String>(
      initialValue: currentValue,
      decoration: InputDecoration(labelText: label),
      items:
          items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: (v) {
        setState(() {
          _selectedCrop = v;
          if (_selectedCrop != 'Sugarcane') {
            _selectedFarmName = null;
            _deliveryNameController.clear();
          }
        });
      },
    );
  }
}
