import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supplies_provider.dart';
import '../screens/frm_add_sup_screen.dart';

class UserStockGrid extends StatefulWidget {
  const UserStockGrid({super.key});

  @override
  State<UserStockGrid> createState() => _UserStockGridState();
}

class _UserStockGridState extends State<UserStockGrid> {
  String? _selectedSupplyId;

  @override
  void initState() {
    super.initState();
    final supplies =
        Provider.of<SuppliesProvider>(context, listen: false).items;
    if (supplies.isNotEmpty) {
      _selectedSupplyId = supplies.first.id;
    }
  }

  void _navigateToAddSup({bool isEdit = false}) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FrmAddSupScreen(
                editSupplyId: isEdit ? _selectedSupplyId : null)));
  }

  void _deleteSupply() {
    if (_selectedSupplyId != null) {
      Provider.of<SuppliesProvider>(context, listen: false)
          .deleteSupply(_selectedSupplyId!);
      setState(() {
        _selectedSupplyId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliesProvider = Provider.of<SuppliesProvider>(context);
    final supplies = suppliesProvider.items;

    if (supplies.isEmpty) {
      return Center(
          child: GestureDetector(
              onTap: () => _navigateToAddSup(),
              child: const Text(
                  'You have no Supplies yet. Click here to Add New…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline))));
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: supplies.map((supply) {
                final isSelected = _selectedSupplyId == supply.id;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                    title: Text(supply.name),
                    subtitle: Text('Quantity: ${supply.quantity}'),
                    onTap: () => setState(() => _selectedSupplyId = supply.id),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () => _navigateToAddSup(),
                      tooltip: 'Add'),
                  IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _navigateToAddSup(isEdit: true),
                      tooltip: 'Edit'),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _deleteSupply,
                      tooltip: 'Delete')
                ])),
      ],
    );
  }
}
