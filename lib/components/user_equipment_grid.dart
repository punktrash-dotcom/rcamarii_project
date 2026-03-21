import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../screens/frm_add_equip_screen.dart';

class UserEquipmentGrid extends StatefulWidget {
  const UserEquipmentGrid({super.key});

  @override
  State<UserEquipmentGrid> createState() => _UserEquipmentGridState();
}

class _UserEquipmentGridState extends State<UserEquipmentGrid> {
  String? _selectedEquipmentId;

  @override
  void initState() {
    super.initState();
    final equipment =
        Provider.of<EquipmentProvider>(context, listen: false).items;
    if (equipment.isNotEmpty) {
      _selectedEquipmentId = equipment.first.id;
    }
  }

  void _navigateToAddEquip({bool isEdit = false}) {
    // Note: The edit functionality needs to be fully implemented in FrmAddEquipScreen
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const FrmAddEquipScreen()));
  }

  void _deleteEquipment() {
    if (_selectedEquipmentId != null) {
      Provider.of<EquipmentProvider>(context, listen: false)
          .deleteEquipment(_selectedEquipmentId!);
      // Select the first item if the list is not empty, otherwise null
      final equipment =
          Provider.of<EquipmentProvider>(context, listen: false).items;
      setState(() {
        _selectedEquipmentId = equipment.isNotEmpty ? equipment.first.id : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final equipment = equipmentProvider.items;

    if (equipment.isEmpty) {
      return Center(
          child: GestureDetector(
              onTap: () => _navigateToAddEquip(),
              child: const Text('You have no Equipment yet. Click here to Add…',
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
              children: equipment.map((equip) {
                final isSelected = _selectedEquipmentId == equip.id;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                    title: Text(equip.name),
                    subtitle: Text(equip.type), // Changed from quantity to type
                    onTap: () =>
                        setState(() => _selectedEquipmentId = equip.id),
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
                      onPressed: () => _navigateToAddEquip(),
                      tooltip: 'Add'),
                  IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _navigateToAddEquip(isEdit: true),
                      tooltip: 'Edit'),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _deleteEquipment,
                      tooltip: 'Delete')
                ])),
      ],
    );
  }
}
