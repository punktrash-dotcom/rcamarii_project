import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/data_provider.dart';
import '../models/equipment_model.dart';
import '../screens/frm_add_equip_screen.dart';
import '../themes/app_visuals.dart';

class EquipmentTab extends StatefulWidget {
  const EquipmentTab({super.key});

  @override
  State<EquipmentTab> createState() => _EquipmentTabState();
}

class _EquipmentTabState extends State<EquipmentTab> {
  bool _showScr22 = false;
  String? _selectedEquipId;
  String? _selectedType;

  void _toggleScreen() {
    setState(() {
      _showScr22 = !_showScr22;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EquipmentProvider>(context, listen: false).loadEquipment();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showScr22 ? _buildScr22() : _buildScr11();
  }

  Widget _buildScr11() {
    final scheme = Theme.of(context).colorScheme;
    final provider = Provider.of<EquipmentProvider>(context);
    final equipment = provider.items;

    if (equipment.isEmpty && !provider.isLoading) {
      return Center(
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FrmAddEquipScreen())),
          child: const Padding(
            padding: EdgeInsets.all(40.0),
            child: Text(
              'You have no Equipment yet. Click here to Add…',
              style: TextStyle(
                  color: AppVisuals.textForest,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (provider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppVisuals.primaryGold));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: OutlinedButton.icon(
            onPressed: _toggleScreen,
            icon: const Icon(Icons.storage, color: AppVisuals.primaryGold),
            label: const Text('EQUIPMENT CATALOG',
                style: TextStyle(
                    color: AppVisuals.primaryGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppVisuals.primaryGold, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: equipment.length,
            itemBuilder: (context, index) {
              final item = equipment[index];
              final isSelected = _selectedEquipId == item.id;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                color: AppVisuals.cloudGlass.withValues(alpha: 0.76),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side:
                      BorderSide(color: scheme.outline.withValues(alpha: 0.18)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: IconButton(
                    onPressed: () => setState(() => _selectedEquipId = item.id),
                    icon: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? AppVisuals.primaryGold
                          : AppVisuals.textForest.withValues(alpha: 0.38),
                    ),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(
                          color: AppVisuals.textForest,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  subtitle: Text(
                      'Type: ${item.type}\nValue: ₱${item.total.toStringAsFixed(2)} | Qty: ${item.quantity}',
                      style: const TextStyle(
                          color: AppVisuals.textForestMuted,
                          height: 1.4,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppVisuals.primaryGold, size: 24),
                    onPressed: () => _incrementQuantity(item),
                  ),
                  onTap: () => setState(() => _selectedEquipId = item.id),
                ),
              );
            },
          ),
        ),

        // Action Buttons Frame
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppVisuals.cloudGlass.withValues(alpha: 0.4),
            border: Border(
                top: BorderSide(color: scheme.outline.withValues(alpha: 0.15))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLargeIconButton(
                  Icons.add_box_rounded,
                  Colors.green,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FrmAddEquipScreen()))),
              _buildLargeIconButton(
                  Icons.edit_note_rounded,
                  Colors.blueGrey,
                  _selectedEquipId == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FrmAddEquipScreen(
                                  equipmentId: _selectedEquipId)))),
              _buildLargeIconButton(
                  Icons.delete_sweep_rounded,
                  Colors.red,
                  _selectedEquipId == null
                      ? null
                      : () => _confirmDelete(provider)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeIconButton(
      IconData icon, Color color, VoidCallback? onTap) {
    return IconButton(
      icon: Icon(icon, color: onTap == null ? Colors.black12 : color, size: 36),
      onPressed: onTap,
    );
  }

  Widget _buildScr22() {
    final scheme = Theme.of(context).colorScheme;
    final data = Provider.of<DataProvider>(context);
    final types =
        data.equipmentDefs.map((e) => e['Type'] as String).toSet().toList();

    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('CATALOG BROWSER',
              style: TextStyle(
                  color: AppVisuals.brandRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppVisuals.textForest, size: 18),
              onPressed: _toggleScreen),
        ),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 120,
                decoration: BoxDecoration(
                    color: AppVisuals.cloudGlass.withValues(alpha: 0.35),
                    border: Border(
                        right: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.18)))),
                child: ListView.builder(
                  itemCount: types.length,
                  itemBuilder: (context, i) {
                    final type = types[i];
                    final isSelected = _selectedType == type;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      tileColor: isSelected
                          ? AppVisuals.panelSoftAlt.withValues(alpha: 0.55)
                          : null,
                      title: Text(type.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? AppVisuals.primaryGold
                                  : AppVisuals.textForest
                                      .withValues(alpha: 0.38),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                      onTap: () => setState(() => _selectedType = type),
                    );
                  },
                ),
              ),
              Expanded(
                child: _selectedType == null
                    ? const Center(
                        child: Text('SELECT CATEGORY',
                            style: TextStyle(
                                color: AppVisuals.textForestMuted,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1)))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: data.equipmentDefs
                            .where((e) => e['Type'] == _selectedType)
                            .map((def) {
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color:
                                      scheme.outline.withValues(alpha: 0.15)),
                            ),
                            color:
                                AppVisuals.cloudGlass.withValues(alpha: 0.68),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(def['Name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: AppVisuals.textForest,
                                          fontSize: 14)),
                                  const SizedBox(height: 6),
                                  Text(
                                      def['Description'] ??
                                          'Tactical equipment unit.',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppVisuals.textForestMuted)),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      icon: const Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: AppVisuals.primaryGold),
                                      onPressed: () => _addToFarm(def),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _incrementQuantity(Equipment item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppVisuals.cloudGlass,
        title: Text('RESTOCK ${item.name.toUpperCase()}?',
            style: const TextStyle(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.w900,
                fontSize: 14)),
        content: const Text('Add one additional unit to your farm inventory?',
            style: TextStyle(color: AppVisuals.textForestMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL',
                style: TextStyle(
                    color: AppVisuals.textForest.withValues(alpha: 0.45))),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('CONFIRM',
                  style: TextStyle(color: AppVisuals.textForest))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    Provider.of<EquipmentProvider>(context, listen: false)
        .incrementQuantity(item.id!);
  }

  void _addToFarm(Map<String, dynamic> def) async {
    final qController = TextEditingController(text: '1');
    final costController =
        TextEditingController(text: def['Cost']?.toString() ?? '0');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppVisuals.cloudGlass,
          title: Text("ADD ${def['Name'].toUpperCase()}",
              style: const TextStyle(
                  color: AppVisuals.textForest,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    stylusHandwritingEnabled: false,
                    controller: qController,
                    style: const TextStyle(color: AppVisuals.textForest),
                    decoration: InputDecoration(
                      labelText: 'QUANTITY',
                      labelStyle: TextStyle(
                          fontSize: 10,
                          color: AppVisuals.textForest.withValues(alpha: 0.65)),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: AppVisuals.textForest
                                  .withValues(alpha: 0.25))),
                    ),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextField(
                    stylusHandwritingEnabled: false,
                    controller: costController,
                    style: const TextStyle(color: AppVisuals.textForest),
                    decoration: InputDecoration(
                      labelText: 'UNIT COST',
                      labelStyle: TextStyle(
                          fontSize: 10,
                          color: AppVisuals.textForest.withValues(alpha: 0.65)),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: AppVisuals.textForest
                                  .withValues(alpha: 0.25))),
                    ),
                    keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL',
                  style: TextStyle(
                      color: AppVisuals.textForest.withValues(alpha: 0.45))),
            ),
            ElevatedButton(
                onPressed: () {
                  final quantity = int.tryParse(qController.text) ?? 1;
                  final cost = double.tryParse(costController.text) ?? 0.0;
                  final equipment = Equipment(
                    type: def['Type'],
                    name: def['Name'],
                    quantity: quantity,
                    cost: cost,
                    total: cost * quantity,
                    note: 'Added from Catalog',
                  );
                  Provider.of<EquipmentProvider>(context, listen: false)
                      .addEquipment(equipment);
                  Navigator.pop(ctx);
                  _toggleScreen();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppVisuals.primaryGold,
                    foregroundColor: AppVisuals.deepGreen),
                child: const Text('CONFIRM')),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(EquipmentProvider p) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: AppVisuals.cloudGlass,
                title: const Text('REMOVE EQUIPMENT?',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
                content: const Text(
                    'Are you sure you want to remove this unit from your inventory?',
                    style: TextStyle(color: AppVisuals.textForestMuted)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('NO',
                          style: TextStyle(
                              color: AppVisuals.textForest
                                  .withValues(alpha: 0.45)))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('REMOVE',
                          style: TextStyle(color: Colors.redAccent)))
                ]));
    if (confirm == true) {
      p.deleteEquipment(_selectedEquipId!);
      setState(() => _selectedEquipId = null);
    }
  }
}
