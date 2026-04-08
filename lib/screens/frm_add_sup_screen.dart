import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/def_sup_model.dart';
import '../models/supply_model.dart';
import '../providers/data_provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/ftracker_provider.dart';
import '../services/database_helper.dart';
import '../services/transaction_log_service.dart';
import '../themes/app_visuals.dart';
import '../utils/app_number_input_formatter.dart';
import '../utils/validation_utils.dart';
import '../widgets/focus_tooltip.dart';
import '../widgets/searchable_dropdown.dart';

class FrmAddSupScreen extends StatefulWidget {
  final String? editSupplyId;
  const FrmAddSupScreen({super.key, this.editSupplyId});

  @override
  State<FrmAddSupScreen> createState() => _FrmAddSupScreenState();
}

class _FrmAddSupScreenState extends State<FrmAddSupScreen>
    with TickerProviderStateMixin {
  static final _numberInputFormatter = AppNumberInputFormatter();
  late TabController _mainTabController;
  TabController? _defSupTabController;
  int _defSupTabLength = 0;

  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  String? _selectedName;
  bool _isDefFrameUnlocked = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController();
  final _quantityController = TextEditingController();
  final _totalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _costController.addListener(_calculateTotal);
    _quantityController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final cost =
        double.tryParse(_costController.text.replaceAll(',', '')) ?? 0.0;
    final quantity =
        int.tryParse(_quantityController.text.replaceAll(',', '')) ?? 0;
    _totalController.text = (cost * quantity).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _defSupTabController?.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _onDefSupTypeChanged(String? newType) {
    setState(() {
      _selectedType = newType;
      _selectedName = null;
      _isDefFrameUnlocked = false;
      _clearForm();
    });
  }

  void _onDefSupNameChanged(String? newName, List<DefSup> allDefs) {
    setState(() {
      _selectedName = newName;
      if (newName == 'New Item...') {
        _isDefFrameUnlocked = true;
        _clearForm();
      } else if (newName != null) {
        final def = allDefs.firstWhere((d) => d.name == newName,
            orElse: () => allDefs.first);
        _nameController.text = def.name;
        _descriptionController.text = def.description;
        _costController.text = def.cost.toString();
        _isDefFrameUnlocked = true;
      } else {
        _isDefFrameUnlocked = false;
        _clearForm();
      }
    });
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _costController.clear();
    _quantityController.clear();
    _totalController.clear();
  }

  void _saveSupply() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final totalCost = double.parse(_totalController.text.replaceAll(',', ''));
    final supplyCategory = (_selectedType?.trim().isNotEmpty ?? false)
        ? _selectedType!.trim()
        : 'Supplies';
    final supplyDescription = _descriptionController.text.trim();
    final suppliesProvider =
        Provider.of<SuppliesProvider>(context, listen: false);
    final ftrackerProvider =
        Provider.of<FtrackerProvider>(context, listen: false);

    final newSupply = Supply(
      id: 'SUP-${DateTime.now().millisecondsSinceEpoch}',
      name: ValidationUtils.toTitleCase(_nameController.text),
      description: _descriptionController.text,
      quantity: int.parse(_quantityController.text.replaceAll(',', '')),
      cost: double.parse(_costController.text.replaceAll(',', '')),
      total: totalCost,
    );

    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final trackerRecord = ftrackerProvider.buildRecord(
      dDate: currentDate,
      dType: 'Expenses',
      dAmount: totalCost,
      category: supplyCategory,
      name: newSupply.name,
      note: supplyDescription.isNotEmpty ? supplyDescription : null,
    );

    await DatabaseHelper.instance.runInTransaction((txn) async {
      await txn.insert(DatabaseHelper.tableSupplies, newSupply.toMap());
      await txn.insert(DatabaseHelper.tableFtracker, trackerRecord.toMap());
    });

    await Future.wait([
      suppliesProvider.loadSupplies(),
      ftrackerProvider.loadFtrackerRecords(),
    ]);
    TransactionLogService.instance.log(
      'Supply added',
      details:
          '${newSupply.name} | qty=${newSupply.quantity} | total=PHP ${newSupply.total.toStringAsFixed(2)}',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entry finalized & Financial Record updated'),
          backgroundColor: AppVisuals.primaryGold));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Add Supplies'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: theme.colorScheme.onPrimary,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor:
              theme.colorScheme.onPrimary.withValues(alpha: 0.7),
          tabs: const [Tab(text: 'Management'), Tab(text: 'Catalog')],
        ),
      ),
      body: TabBarView(
          controller: _mainTabController,
          children: [_buildT1(context), _buildT2(context)]),
    );
  }

  Widget _buildT1(BuildContext context) {
    final defSups = Provider.of<DataProvider>(context).defSups;
    final uniqueTypes = defSups.map((e) => e.type).toSet().toList();
    final namesForType = _selectedType == null
        ? <String>[]
        : [
            'New Item...',
            ...defSups
                .where((d) => d.type == _selectedType)
                .map((e) => e.name)
                .toSet()
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. IDENTIFY SUPPLY',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueGrey,
                  letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(children: [
                SearchableDropdownFormField<String>(
                    initialValue: _selectedType,
                    decoration:
                        const InputDecoration(labelText: 'SUPPLY CATEGORY'),
                    items: uniqueTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: _onDefSupTypeChanged),
                const SizedBox(height: 20),
                SearchableDropdownFormField<String>(
                    initialValue: _selectedName,
                    decoration: const InputDecoration(labelText: 'ITEM NAME'),
                    items: namesForType
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (val) => _onDefSupNameChanged(val, defSups)),
                const SizedBox(height: 20),
                FocusTooltip(
                  message: 'Enter the supply name.',
                  child: TextFormField(
                      stylusHandwritingEnabled: false,
                      controller: _nameController,
                      decoration: const InputDecoration(
                          labelText: 'MANUAL NAME ENTRY')),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 32),
          if (_isDefFrameUnlocked) ...[
            const Text('2. INVENTORY DETAILS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey,
                    letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                    key: _formKey,
                    child: Column(children: [
                      FocusTooltip(
                        message: 'Enter the supply description.',
                        child: TextFormField(
                            stylusHandwritingEnabled: false,
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                                labelText: 'DESCRIPTION')),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FocusTooltip(
                              message: 'Enter the unit cost.',
                              child: TextFormField(
                                  stylusHandwritingEnabled: false,
                                  controller: _costController,
                                  decoration: const InputDecoration(
                                      labelText: 'UNIT COST'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: <TextInputFormatter>[
                                    _numberInputFormatter,
                                  ],
                                  validator: (v) => ValidationUtils.checkData(
                                      value: (v ?? '').replaceAll(',', ''),
                                      fieldName: 'Cost',
                                      isNumeric: true)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FocusTooltip(
                              message: 'Enter the quantity.',
                              child: TextFormField(
                                  stylusHandwritingEnabled: false,
                                  controller: _quantityController,
                                  decoration: const InputDecoration(
                                      labelText: 'QUANTITY'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: false),
                                  inputFormatters: <TextInputFormatter>[
                                    AppNumberInputFormatter(
                                        allowDecimal: false),
                                  ],
                                  validator: (v) => ValidationUtils.checkData(
                                      value: (v ?? '').replaceAll(',', ''),
                                      fieldName: 'Quantity',
                                      isNumeric: true)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                          stylusHandwritingEnabled: false,
                          controller: _totalController,
                          decoration: const InputDecoration(
                              labelText: 'TOTAL VALUATION', filled: true),
                          readOnly: true),
                      const SizedBox(height: 32),
                      Tooltip(
                        message: 'Save this supply entry.',
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_task_rounded),
                          label: const Text('CONFIRM ENTRY'),
                          onPressed: _saveSupply,
                        ),
                      ),
                    ])),
              ),
            ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildT2(BuildContext context) {
    final theme = Theme.of(context);
    final dataProvider = Provider.of<DataProvider>(context);
    final defSups = dataProvider.defSups;
    final groupedSupplies = <String, List<DefSup>>{};

    for (var item in defSups) {
      final type = item.type;
      if (!groupedSupplies.containsKey(type)) {
        groupedSupplies[type] = [];
      }
      groupedSupplies[type]!.add(item);
    }
    final types = groupedSupplies.keys.toList();

    if (_defSupTabController == null || _defSupTabLength != types.length) {
      _defSupTabController?.dispose();
      _defSupTabLength = types.length;
      _defSupTabController =
          TabController(length: _defSupTabLength, vsync: this);
    }

    return Column(
      children: [
        Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          child: TabBar(
            controller: _defSupTabController,
            isScrollable: true,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor:
                theme.colorScheme.primary.withValues(alpha: 0.4),
            tabs: types.map((type) => Tab(text: type.toUpperCase())).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _defSupTabController,
            children: types.map((type) {
              final items = groupedSupplies[type]!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                      subtitle: Text(item.description,
                          style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded,
                              color: theme.colorScheme.primary),
                          onPressed: () => _showAddFromDefSupDialog(item)),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddFromDefSupDialog(DefSup defSup) async {
    final quantityController = TextEditingController();
    final costController = TextEditingController(text: defSup.cost.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Add ${defSup.name}?',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  stylusHandwritingEnabled: false,
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(
                  stylusHandwritingEnabled: false,
                  controller: costController,
                  decoration: const InputDecoration(labelText: 'Unit Cost'),
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL')),
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('PROCEED')),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        _mainTabController.index = 0;
        _nameController.text = defSup.name;
        _descriptionController.text = defSup.description;
        _costController.text = costController.text;
        _quantityController.text = quantityController.text;
        _isDefFrameUnlocked = true;
      });
    }
  }
}
