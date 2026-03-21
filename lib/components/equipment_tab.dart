import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/data_provider.dart';
import '../models/equipment_model.dart';
import '../screens/frm_add_equip_screen.dart';

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
                  color: Colors.black,
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
          child: CircularProgressIndicator(color: Color(0xFF004D40)));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: OutlinedButton.icon(
            onPressed: _toggleScreen,
            icon: const Icon(Icons.storage, color: Color(0xFF004D40)),
            label: const Text('EQUIPMENT CATALOG',
                style: TextStyle(
                    color: Color(0xFF004D40),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF004D40), width: 1.5),
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
                color: Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
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
                      color:
                          isSelected ? const Color(0xFF004D40) : Colors.black38,
                    ),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  subtitle: Text(
                      'Type: ${item.type}\nValue: ₱${item.total.toStringAsFixed(2)} | Qty: ${item.quantity}',
                      style: const TextStyle(
                          color: Colors.black87,
                          height: 1.4,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Color(0xFF004D40), size: 24),
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
            color: Colors.white.withValues(alpha: 0.1),
            border: Border(
                top: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
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
                  color: Color(0xFFB71C1C),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.black, size: 18),
              onPressed: _toggleScreen),
        ),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 120,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border(
                        right: BorderSide(
                            color: Colors.black.withValues(alpha: 0.05)))),
                child: ListView.builder(
                  itemCount: types.length,
                  itemBuilder: (context, i) {
                    final type = types[i];
                    final isSelected = _selectedType == type;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      tileColor: isSelected
                          ? Colors.white.withValues(alpha: 0.1)
                          : null,
                      title: Text(type.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? const Color(0xFF004D40)
                                  : Colors.black38,
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
                                color: Colors.black26,
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
                                  color: Colors.black.withValues(alpha: 0.05)),
                            ),
                            color: Colors.white.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(def['Name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                          fontSize: 14)),
                                  const SizedBox(height: 6),
                                  Text(
                                      def['Description'] ??
                                          'Tactical equipment unit.',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54)),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      icon: const Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: Color(0xFF004D40)),
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
        backgroundColor: const Color(0xFF004D40),
        title: Text('RESTOCK ${item.name.toUpperCase()}?',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14)),
        content: const Text('Add one additional unit to your farm inventory?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('CONFIRM', style: TextStyle(color: Colors.white))),
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
          backgroundColor: const Color(0xFF004D40),
          title: Text("ADD ${def['Name'].toUpperCase()}",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    stylusHandwritingEnabled: false,
                    controller: qController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'QUANTITY',
                      labelStyle:
                          TextStyle(fontSize: 10, color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                    ),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextField(
                    stylusHandwritingEnabled: false,
                    controller: costController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'UNIT COST',
                      labelStyle:
                          TextStyle(fontSize: 10, color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                    ),
                    keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL',
                    style: TextStyle(color: Colors.white38))),
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
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF004D40)),
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
                backgroundColor: const Color(0xFF004D40),
                title: const Text('REMOVE EQUIPMENT?',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
                content: const Text(
                    'Are you sure you want to remove this unit from your inventory?',
                    style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('NO',
                          style: TextStyle(color: Colors.white38))),
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
