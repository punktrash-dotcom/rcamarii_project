// lib/screens/frm_add_def_sup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/def_sup_model.dart';
import '../providers/data_provider.dart';
import '../utils/validation_utils.dart';
import '../widgets/searchable_dropdown.dart';

class FrmAddDefSupScreen extends StatefulWidget {
  const FrmAddDefSupScreen({super.key});

  @override
  State<FrmAddDefSupScreen> createState() => _FrmAddDefSupScreenState();
}

class _FrmAddDefSupScreenState extends State<FrmAddDefSupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formData = <String, dynamic>{};

  // Focus Nodes for Enter key navigation
  final _nameFocus = FocusNode();
  final _descFocus = FocusNode();
  final _costFocus = FocusNode();
  final _saveFocus = FocusNode();

  @override
  void dispose() {
    _nameFocus.dispose();
    _descFocus.dispose();
    _costFocus.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final newDef = DefSup(
      id: '',
      name: ValidationUtils.toTitleCase(_formData['Name']),
      type: _formData['Type'],
      description: _formData['Description'] ?? '',
      cost: _formData['Cost'],
    );

    final success = await Provider.of<DataProvider>(context, listen: false)
        .addDefSup(newDef);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Recorded'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Item Exists'),
            content: Text(
                'A supply definition with the name "${newDef.name}" already exists.'),
            actions: [
              TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(ctx).pop())
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uniqueTypes = Provider.of<DataProvider>(context, listen: false)
        .defSups
        .map((e) => e.type)
        .toSet()
        .toList();

    // Set initial default type if not already set
    if (_formData['Type'] == null && uniqueTypes.isNotEmpty) {
      _formData['Type'] = uniqueTypes.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Supply Definition')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchableDropdownFormField<String>(
                initialValue: _formData['Type'],
                decoration: const InputDecoration(labelText: 'Type'),
                items: uniqueTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  setState(() => _formData['Type'] = val);
                  FocusScope.of(context).requestFocus(_nameFocus);
                },
                onSaved: (val) => _formData['Type'] = val,
              ),
              const SizedBox(height: 16),
              TextFormField(
                stylusHandwritingEnabled: false,
                focusNode: _nameFocus,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (val) =>
                    ValidationUtils.checkData(value: val, fieldName: 'Name'),
                onSaved: (val) => _formData['Name'] = val,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_descFocus),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                stylusHandwritingEnabled: false,
                focusNode: _descFocus,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (val) => ValidationUtils.checkData(
                    value: val,
                    fieldName: 'Description',
                    canBeBlank: true), // Corrected parameter
                onSaved: (val) => _formData['Description'] = val,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_costFocus),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                stylusHandwritingEnabled: false,
                focusNode: _costFocus,
                decoration: const InputDecoration(labelText: 'Cost'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) => ValidationUtils.checkData(
                    value: val, fieldName: 'Cost', isNumeric: true),
                onSaved: (val) =>
                    _formData['Cost'] = double.tryParse(val ?? '0'),
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_saveFocus),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 16),
                  ElevatedButton(
                      focusNode: _saveFocus,
                      onPressed: _saveForm,
                      child: const Text('Save')),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
