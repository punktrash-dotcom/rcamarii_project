import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/equipment_model.dart';
import '../providers/data_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/ftracker_provider.dart';
import '../utils/app_number_input_formatter.dart';
import '../utils/validation_utils.dart';
import '../widgets/focus_tooltip.dart';
import '../widgets/searchable_dropdown.dart';

class FrmAddEquipScreen extends StatefulWidget {
  final String? equipmentId;
  const FrmAddEquipScreen({super.key, this.equipmentId});

  @override
  State<FrmAddEquipScreen> createState() => _FrmAddEquipScreenState();
}

class _FrmAddEquipScreenState extends State<FrmAddEquipScreen>
    with TickerProviderStateMixin {
  static final _numberInputFormatter = AppNumberInputFormatter();
  late TabController _mainTabController;

  final _formKey = GlobalKey<FormState>();
  String? _selectedDefType;
  String? _selectedDefName;
  bool _isDefFrameUnlocked = false;

  final _typeController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _totalController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _quantityController.addListener(_calculateTotal);
    _costController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _typeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _totalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final quantity =
        int.tryParse(_quantityController.text.replaceAll(',', '')) ?? 0;
    final cost =
        double.tryParse(_costController.text.replaceAll(',', '')) ?? 0.0;
    _totalController.text = (cost * quantity).toStringAsFixed(2);
  }

  void _onDefTypeChanged(String? newType, List<dynamic> allDefs) {
    setState(() {
      _selectedDefType = newType;
      _typeController.text = newType ?? '';
      _selectedDefName = null;
      _isDefFrameUnlocked = false;
    });
  }

  void _onDefNameChanged(String? newName, List<dynamic> allDefs) {
    setState(() {
      _selectedDefName = newName;
      if (newName == 'New Item...') {
        _isDefFrameUnlocked = true;
        _nameController.clear();
        _noteController.clear();
        _costController.clear();
      } else if (newName != null) {
        final def = allDefs.firstWhere((d) => d['Name'] == newName);
        _nameController.text = def['Name'] ?? '';
        _noteController.text = def['Note'] ?? '';
        _costController.text = def['Cost']?.toString() ?? '0.0';
        _isDefFrameUnlocked = true;
      }
    });
  }

  void _saveEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    final equipmentProvider =
        Provider.of<EquipmentProvider>(context, listen: false);
    final ftrackerProvider =
        Provider.of<FtrackerProvider>(context, listen: false);

    final didConfirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Add this equipment to your inventory?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('No')),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Yes')),
            ],
          ),
        ) ??
        false;

    if (!didConfirm) return;

    _formKey.currentState!.save();

    final quantity =
        int.tryParse(_quantityController.text.replaceAll(',', '')) ?? 0;
    final cost =
        double.tryParse(_costController.text.replaceAll(',', '')) ?? 0.0;
    final total =
        double.tryParse(_totalController.text.replaceAll(',', '')) ?? 0.0;
    final equipmentCategory = _typeController.text.trim().isEmpty
        ? 'Equipment'
        : _typeController.text.trim();
    final equipmentNote = _noteController.text.trim();

    final equipment = Equipment(
      id: widget.equipmentId,
      type: _typeController.text,
      name: _nameController.text,
      quantity: quantity,
      cost: cost,
      total: total,
      note: equipmentNote.isNotEmpty ? equipmentNote : null,
    );

    if (widget.equipmentId != null) {
      await equipmentProvider.updateEquipment(equipment);
    } else {
      await equipmentProvider.addEquipment(equipment);

      // Auto-record financial transaction (TRANSREC logic)
      final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (!mounted) return;
      await ftrackerProvider.transRec(
        dDate: currentDate,
        dType: 'Expenses',
        dAmount: total,
        category: equipmentCategory,
        name: equipment.name,
        note: equipmentNote.isNotEmpty ? equipmentNote : null,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Equipment saved & Financial Record updated')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
          title: const Text('Add Equipment'),
          centerTitle: true,
          bottom: TabBar(controller: _mainTabController, tabs: const [
            Tab(text: 'Manage Equipment'),
            Tab(text: 'Equipment Database')
          ])),
      body: TabBarView(
          controller: _mainTabController,
          children: [_buildT1(context), _buildT2(context)]),
    );
  }

  Widget _buildT1(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final defs = dataProvider.equipmentDefs;
    final uniqueTypes = defs.map((e) => e['Type'] as String).toSet().toList();
    final namesForType = _selectedDefType == null
        ? <String>[]
        : [
            'New Item...',
            ...defs
                .where((d) => d['Type'] == _selectedDefType)
                .map((e) => e['Name'] as String)
                .toSet()
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. IDENTIFY EQUIPMENT',
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
                SearchableDropdownFormField<String?>(
                  initialValue: _selectedDefType,
                  decoration:
                      const InputDecoration(labelText: 'EQUIPMENT TYPE'),
                  items: uniqueTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => _onDefTypeChanged(val, defs),
                ),
                const SizedBox(height: 20),
                FocusTooltip(
                  message: 'Enter the equipment type.',
                  child: TextFormField(
                      stylusHandwritingEnabled: false,
                      controller: _typeController,
                      decoration: const InputDecoration(
                          labelText: 'MANUAL TYPE ENTRY')),
                ),
                const SizedBox(height: 20),
                SearchableDropdownFormField<String?>(
                  initialValue: _selectedDefName,
                  decoration:
                      const InputDecoration(labelText: 'EQUIPMENT NAME'),
                  items: namesForType
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (val) => _onDefNameChanged(val, defs),
                ),
                const SizedBox(height: 20),
                FocusTooltip(
                  message: 'Enter the equipment name.',
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
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    Row(
                      children: [
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
                                  AppNumberInputFormatter(allowDecimal: false),
                                ],
                                validator: (v) => ValidationUtils.checkData(
                                    value: (v ?? '').replaceAll(',', ''),
                                    fieldName: 'Quantity',
                                    isNumeric: true)),
                          ),
                        ),
                        const SizedBox(width: 16),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                        stylusHandwritingEnabled: false,
                        controller: _totalController,
                        decoration: const InputDecoration(
                            labelText: 'TOTAL VALUATION', filled: true),
                        readOnly: true),
                    const SizedBox(height: 16),
                    FocusTooltip(
                      message: 'Enter equipment notes.',
                      child: TextFormField(
                          stylusHandwritingEnabled: false,
                          controller: _noteController,
                          decoration: const InputDecoration(labelText: 'NOTE'),
                          maxLines: 2),
                    ),
                  ]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Close this form without saving changes.',
                  child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CANCEL')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Tooltip(
                  message: 'Save this equipment entry.',
                  child: ElevatedButton(
                      onPressed: _saveEquipment,
                      child: Text(widget.equipmentId != null
                          ? 'UPDATE'
                          : 'ADD TO INVENTORY')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildT2(BuildContext context) {
    final theme = Theme.of(context);
    final dataProvider = Provider.of<DataProvider>(context);
    final types = dataProvider.equipmentDefs
        .map((e) => e['Type'] as String)
        .toSet()
        .toList();

    if (types.isEmpty) {
      return const Center(child: Text('Database empty'));
    }

    return DefaultTabController(
      length: types.length,
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: TabBar(
                isScrollable: true,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor:
                    theme.colorScheme.primary.withValues(alpha: 0.4),
                tabs: types
                    .map((type) => Tab(text: type.toUpperCase()))
                    .toList()),
          ),
          Expanded(
            child: TabBarView(
              children: types.map((type) {
                final items = dataProvider.equipmentDefs
                    .where((d) => d['Type'] == type)
                    .toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(item['Name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 15)),
                        subtitle: Text(item['Description'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        trailing: Icon(Icons.add_circle_outline_rounded,
                            color: theme.colorScheme.primary),
                        onTap: () => _showAddFromDefDialog(item),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFromDefDialog(Map<String, dynamic> def) async {
    final quantityController = TextEditingController();
    final costController =
        TextEditingController(text: def['Cost']?.toString() ?? '0.0');
    String ownership = 'Owned';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Text('Add ${def['Name']}?',
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ownership',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      RadioGroup<String>(
                        groupValue: ownership,
                        onChanged: (value) =>
                            setState(() => ownership = value!),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              value: 'Owned',
                              title: const Text('Owned'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            RadioListTile<String>(
                              value: 'Rental',
                              title: const Text('Rental'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (ownership == 'Rental')
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FocusTooltip(
                        message: 'Enter the rent cost.',
                        child: TextField(
                          stylusHandwritingEnabled: false,
                          controller: costController,
                          decoration:
                              const InputDecoration(labelText: 'Rent Cost'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            _numberInputFormatter,
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('CANCEL')),
                ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('PROCEED')),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        _mainTabController.index = 0;
        _selectedDefType = def['Type'];
        _selectedDefName = def['Name'];
        _typeController.text = def['Type'] ?? '';
        _nameController.text = def['Name'] ?? '';
        _noteController.text = def['Note'] ?? '';
        _quantityController.text = quantityController.text;
        _costController.text =
            ownership == 'Rental' ? costController.text : '0.0';
        _isDefFrameUnlocked = true;
      });
    }
  }
}
