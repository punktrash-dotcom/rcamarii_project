import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/data_provider.dart';
import '../screens/frm_add_equip_screen.dart';
import '../screens/frm_add_equip_defs_screen.dart';
import '../models/equipment_model.dart';
import '../widgets/searchable_dropdown.dart';
import '../themes/app_visuals.dart';

class UserEquipmentView extends StatefulWidget {
  const UserEquipmentView({super.key});

  @override
  State<UserEquipmentView> createState() => _UserEquipmentViewState();
}

class _UserEquipmentViewState extends State<UserEquipmentView>
    with TickerProviderStateMixin {
  bool _showScr22 = false;
  String? _selectedEquipmentId;
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _toggleScreen() {
    setState(() {
      _showScr22 = !_showScr22;
      if (_showScr22) {
        final dataProvider = Provider.of<DataProvider>(context, listen: false);
        final types = dataProvider.equipmentDefs
            .map((e) => e['Type'] as String)
            .toSet()
            .toList();
        _tabController = TabController(length: types.length, vsync: this);
      }
    });
  }

  void _showAddMoreDialog(Equipment equipment) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add more ${equipment.name}?'),
        content: TextField(
            stylusHandwritingEnabled: false,
            controller: quantityController,
            decoration: const InputDecoration(labelText: 'How many:'),
            keyboardType: TextInputType.number),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                Provider.of<EquipmentProvider>(context, listen: false)
                    .addQuantity(equipment.id!, quantity);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteEquipment() {
    if (_selectedEquipmentId != null) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: const Text(
                      'Are you sure you want to delete this equipment?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('No')),
                    TextButton(
                        onPressed: () {
                          Provider.of<EquipmentProvider>(context, listen: false)
                              .deleteEquipment(_selectedEquipmentId!);
                          setState(() => _selectedEquipmentId = null);
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Yes'))
                  ]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    if (equipmentProvider.items.isNotEmpty && _selectedEquipmentId == null) {
      _selectedEquipmentId = equipmentProvider.items.first.id;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _showScr22 ? _buildScr22() : _buildScr11(),
    );
  }

  Widget _buildScr11() {
    final equipmentProvider = Provider.of<EquipmentProvider>(context);
    final equipment = equipmentProvider.items;

    if (equipment.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have no Equipment yet.',
                style: TextStyle(fontSize: 18, color: AppVisuals.textForest)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Click here to Add'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FrmAddEquipScreen())),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: OutlinedButton.icon(
              icon: const Icon(Icons.inventory_2),
              label: const Text('Equipment Database'),
              onPressed: _toggleScreen),
        ),
        Divider(
            color: AppVisuals.textForest.withValues(alpha: 0.22)),
        Expanded(
          child: ListView.builder(
            itemCount: equipment.length,
            itemBuilder: (context, index) {
              final equip = equipment[index];
              final isSelected = _selectedEquipmentId == equip.id;
              return Card(
                child: ListTile(
                  leading: IconButton(
                    onPressed: () =>
                        setState(() => _selectedEquipmentId = equip.id),
                    icon: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                    ),
                  ),
                  title: Text(equip.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Quantity: ${equip.quantity}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final equipmentProvider = Provider.of<EquipmentProvider>(
                          context,
                          listen: false);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Add this equipment to your farm?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('No')),
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Yes')),
                          ],
                        ),
                      );
                      if (confirm != true || !context.mounted) return;
                      equipmentProvider.incrementQuantity(equip.id!);
                    },
                  ),
                  onTap: () {
                    setState(() => _selectedEquipmentId = equip.id);
                    _showAddMoreDialog(equip);
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                  child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add New'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FrmAddEquipScreen())))),
              const SizedBox(width: 8),
              Expanded(
                  child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: _selectedEquipmentId == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => FrmAddEquipScreen(
                                      equipmentId: _selectedEquipmentId))))),
              const SizedBox(width: 8),
              Expanded(
                  child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      onPressed: _selectedEquipmentId == null
                          ? null
                          : _deleteEquipment)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScr22() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final types = dataProvider.equipmentDefs
        .map((e) => e['Type'] as String)
        .toSet()
        .toList();
    String? selectedType = types.isNotEmpty ? types.first : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to My Equipment'),
              onPressed: _toggleScreen),
        ),
        Divider(
            color: AppVisuals.textForest.withValues(alpha: 0.22)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SearchableDropdownFormField<String>(
            initialValue: selectedType,
            decoration:
                const InputDecoration(labelText: 'Filter by Equipment Type'),
            items: types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => selectedType = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: dataProvider.equipmentDefs
                .where((e) => e['Type'] == selectedType)
                .length,
            itemBuilder: (context, index) {
              final item = dataProvider.equipmentDefs
                  .where((e) => e['Type'] == selectedType)
                  .toList()[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.precision_manufacturing_outlined),
                  title: Text(item['Name']),
                  subtitle: Text(item['Description'] ?? 'Equipment definition'),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                  child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Def'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FrmAddEquipDefsScreen())))),
              const SizedBox(width: 8),
              Expanded(
                  child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Def'),
                      onPressed: () {})),
            ],
          ),
        ),
      ],
    );
  }
}
