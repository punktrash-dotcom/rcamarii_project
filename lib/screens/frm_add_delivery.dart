import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';
import '../providers/ftracker_provider.dart';
import '../themes/custom_themes.dart';
import '../widgets/searchable_dropdown.dart';

class FrmAddDelivery extends StatefulWidget {
  const FrmAddDelivery({super.key});

  @override
  State<FrmAddDelivery> createState() => _FrmAddDeliveryState();
}

class _FrmAddDeliveryState extends State<FrmAddDelivery> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ticketNoController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _totalController =
      TextEditingController(text: '0.00');
  final TextEditingController _noteController = TextEditingController();

  String _selectedType = 'Sugarcane';
  final List<String> _types = ['Sugarcane', 'Rice', 'Corn', 'Other'];

  @override
  void initState() {
    super.initState();
    _costController.addListener(_updateTotal);
    _quantityController.addListener(_updateTotal);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ticketNoController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _totalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    final double cost = double.tryParse(_costController.text) ?? 0.0;
    final double qty = double.tryParse(_quantityController.text) ?? 0.0;
    setState(() {
      _totalController.text = (cost * qty).toStringAsFixed(2);
    });
  }

  Future<void> _saveDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final deliveryNote = _noteController.text.trim();
      final delivery = Delivery(
        date: DateTime.now(),
        type: _selectedType,
        name: _nameController.text,
        ticketNo: _ticketNoController.text,
        cost: double.tryParse(_costController.text),
        quantity: double.tryParse(_quantityController.text) ?? 0.0,
        total: double.tryParse(_totalController.text) ?? 0.0,
        note: deliveryNote.isNotEmpty ? deliveryNote : null,
      );

      final deliveryProvider =
          Provider.of<DeliveryProvider>(context, listen: false);
      final ftrackerProvider =
          Provider.of<FtrackerProvider>(context, listen: false);

      await deliveryProvider.addDelivery(delivery, ftrackerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Delivery recorded and financial entry created.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CustomThemes.delivery(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NEW PRODUCTION DELIVERY'),
          centerTitle: true,
          elevation: 0,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('PRODUCT DETAILS'),
                    SearchableDropdownFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(labelText: 'CROP TYPE'),
                      items: _types
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedType = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      stylusHandwritingEnabled: false,
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'FARM / BATCH NAME'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      stylusHandwritingEnabled: false,
                      controller: _ticketNoController,
                      decoration:
                          const InputDecoration(labelText: 'TICKET / REF NO.'),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('QUANTITY & VALUATION'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            stylusHandwritingEnabled: false,
                            controller: _quantityController,
                            decoration:
                                const InputDecoration(labelText: 'QUANTITY'),
                            keyboardType: TextInputType.number,
                            validator: (v) => double.tryParse(v ?? '') == null
                                ? 'Invalid'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            stylusHandwritingEnabled: false,
                            controller: _costController,
                            decoration:
                                const InputDecoration(labelText: 'UNIT COST'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      stylusHandwritingEnabled: false,
                      controller: _totalController,
                      decoration: const InputDecoration(
                          labelText: 'TOTAL VALUE', filled: true),
                      readOnly: true,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      stylusHandwritingEnabled: false,
                      controller: _noteController,
                      decoration: const InputDecoration(labelText: 'REMARKS'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveDelivery,
                      child: const Text('RECORD DELIVERY',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSaving)
              Center(
                  child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.black54,
            letterSpacing: 1.5),
      ),
    );
  }
}
