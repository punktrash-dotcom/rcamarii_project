import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../utils/validation_utils.dart';
import '../widgets/searchable_dropdown.dart';

class FrmAddEquipDefsScreen extends StatefulWidget {
  const FrmAddEquipDefsScreen({super.key});

  @override
  State<FrmAddEquipDefsScreen> createState() => _FrmAddEquipDefsScreenState();
}

class _FrmAddEquipDefsScreenState extends State<FrmAddEquipDefsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formData = <String, dynamic>{};
  String? _selectedType;

  final _nameFocus = FocusNode();
  final _descFocus = FocusNode();
  final _filipinoNameFocus = FocusNode();
  final _costFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _saveFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final types = Provider.of<DataProvider>(context, listen: false)
        .equipmentDefs
        .map((e) => e['Type'] as String)
        .toSet()
        .toList();
    if (types.isNotEmpty) {
      _selectedType = types.first;
    }
    _formData['Type'] = _selectedType;
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _descFocus.dispose();
    _filipinoNameFocus.dispose();
    _costFocus.dispose();
    _notesFocus.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final success = await dataProvider.addEquipmentDef(_formData);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Recorded'), backgroundColor: Colors.green));
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Item already exists.'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final uniqueTypes = dataProvider.equipmentDefs
        .map((e) => e['Type'] as String)
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Equipment Definition'), actions: [
        IconButton(
            icon: const Icon(Icons.save), onPressed: _saveForm, tooltip: 'Save')
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SearchableDropdownFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: uniqueTypes
                      .map((value) => DropdownMenuItem<String>(
                          value: value, child: Text(value)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v),
                  onSaved: (v) {
                    _formData['Type'] = v;
                  }),
              TextFormField(
                  stylusHandwritingEnabled: false,
                  focusNode: _nameFocus,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      ValidationUtils.checkData(value: v, fieldName: 'Name'),
                  onSaved: (v) =>
                      _formData['Name'] = ValidationUtils.toTitleCase(v!),
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_descFocus),
                  textInputAction: TextInputAction.next),
              TextFormField(
                  stylusHandwritingEnabled: false,
                  focusNode: _descFocus,
                  decoration: const InputDecoration(labelText: 'Description'),
                  onSaved: (v) => _formData['Description'] = v ?? '',
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_filipinoNameFocus),
                  textInputAction: TextInputAction.next),
              TextFormField(
                  stylusHandwritingEnabled: false,
                  focusNode: _filipinoNameFocus,
                  decoration: const InputDecoration(labelText: 'Filipino Name'),
                  onSaved: (v) => _formData['FilipinoName'] =
                      ValidationUtils.toTitleCase(v!),
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_costFocus),
                  textInputAction: TextInputAction.next),
              TextFormField(
                  stylusHandwritingEnabled: false,
                  focusNode: _costFocus,
                  decoration: const InputDecoration(labelText: 'Cost'),
                  keyboardType: TextInputType.number,
                  validator: (v) => ValidationUtils.checkData(
                      value: v, fieldName: 'Cost', isNumeric: true),
                  onSaved: (v) => _formData['Cost'] = double.tryParse(v!),
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_notesFocus),
                  textInputAction: TextInputAction.next),
              TextFormField(
                  stylusHandwritingEnabled: false,
                  focusNode: _notesFocus,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  onSaved: (v) => _formData['Note'] = v ?? '',
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_saveFocus),
                  textInputAction: TextInputAction.done),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                const SizedBox(width: 16),
                ElevatedButton(
                    focusNode: _saveFocus,
                    onPressed: _saveForm,
                    child: const Text('Save'))
              ])
            ],
          ),
        ),
      ),
    );
  }
}
