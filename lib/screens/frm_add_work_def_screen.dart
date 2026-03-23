// lib/screens/frm_add_work_def_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/work_def_model.dart';
import '../providers/data_provider.dart';
import '../utils/validation_utils.dart';
import '../widgets/searchable_dropdown.dart';

class FrmAddWorkDefScreen extends StatefulWidget {
  final String? workDefId;

  const FrmAddWorkDefScreen({super.key, this.workDefId});

  @override
  State<FrmAddWorkDefScreen> createState() => _FrmAddWorkDefScreenState();
}

class _FrmAddWorkDefScreenState extends State<FrmAddWorkDefScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  final Map<String, dynamic> _formData = {
    'Type': 'Manual',
    'ModeOfWork': 'Per Hour',
  };
  bool _didLoadInitialData = false;

  final List<String> _modes = [
    'Per Hour',
    'Per Day',
    'Per Bag',
    'Per Tank',
    'Per Hectare (Pakyaw)',
  ];

  bool get _isEditing => widget.workDefId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitialData || widget.workDefId == null) {
      _didLoadInitialData = true;
      return;
    }

    final provider = Provider.of<DataProvider>(context, listen: false);
    final existing =
        provider.workDefs.where((def) => def.id == widget.workDefId);
    if (existing.isNotEmpty) {
      final workDef = existing.first;
      _nameController.text = workDef.name;
      _costController.text = workDef.cost.toString();
      _formData['Type'] = workDef.type;
      _formData['ModeOfWork'] = workDef.modeOfWork;
    }

    _didLoadInitialData = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _saveWorkDef() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final workDef = WorkDef(
      id: widget.workDefId ?? '',
      name: ValidationUtils.toTitleCase(_formData['Name'] ?? ''),
      type: _formData['Type'],
      modeOfWork: _formData['ModeOfWork'],
      cost: _formData['Cost'] ?? 0.0,
    );

    final provider = Provider.of<DataProvider>(context, listen: false);
    final success = _isEditing
        ? await provider.updateWorkDef(workDef)
        : await provider.addWorkDef(workDef);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
              _isEditing
                  ? 'Work definition updated!'
                  : 'New work definition added!',
            ),
            backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
              _isEditing
                  ? 'Unable to update. A definition with this name already exists.'
                  : 'A definition with this name already exists.',
            ),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Work Definition' : 'Add New Work Definition',
        ),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                stylusHandwritingEnabled: false,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    ValidationUtils.checkData(value: value, fieldName: 'Name'),
                onSaved: (value) => _formData['Name'] = value,
              ),
              const SizedBox(height: 16),
              SearchableDropdownFormField<String>(
                initialValue: _formData['Type'],
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['Manual', 'Equipment'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) =>
                    setState(() => _formData['Type'] = newValue),
                onSaved: (value) => _formData['Type'] = value,
              ),
              const SizedBox(height: 16),
              SearchableDropdownFormField<String>(
                initialValue: _formData['ModeOfWork'],
                decoration: const InputDecoration(labelText: 'Mode of Work'),
                items: _modes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) =>
                    setState(() => _formData['ModeOfWork'] = newValue),
                onSaved: (value) => _formData['ModeOfWork'] = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                stylusHandwritingEnabled: false,
                decoration: const InputDecoration(labelText: 'Cost'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    ValidationUtils.checkData(value: value, fieldName: 'Cost'),
                onSaved: (value) =>
                    _formData['Cost'] = double.tryParse(value ?? '0.0'),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Update Definition' : 'Save Definition'),
                onPressed: _saveWorkDef,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
