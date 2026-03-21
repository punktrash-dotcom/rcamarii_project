import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/def_sup_model.dart';
import '../providers/data_provider.dart';
import '../screens/frm_add_def_sup_screen.dart';
import '../widgets/searchable_dropdown.dart';

class DefSupBrowser extends StatefulWidget {
  const DefSupBrowser({super.key});

  @override
  State<DefSupBrowser> createState() => _DefSupBrowserState();
}

class _DefSupBrowserState extends State<DefSupBrowser> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    if (dataProvider.defSups.isNotEmpty) {
      final types = dataProvider.defSups.map((e) => e.type).toSet().toList();
      _selectedType = types.first;
    }
  }

  void _navigateToAddDefSup() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const FrmAddDefSupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final theme = Theme.of(context);
    final uniqueTypes =
        dataProvider.defSups.map((e) => e.type).toSet().toList();
    final itemsForType = _selectedType == null
        ? <DefSup>[]
        : dataProvider.defSups.where((d) => d.type == _selectedType).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchableDropdownFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                  labelText: 'Filter Catalog',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none),
              items: uniqueTypes
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t,
                          style: const TextStyle(fontWeight: FontWeight.bold))))
                  .toList(),
              onChanged: (val) => setState(() {
                _selectedType = val;
              }),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: itemsForType.isEmpty
                ? Center(
                    child: ElevatedButton.icon(
                      onPressed: _navigateToAddDefSup,
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Definition'),
                    ),
                  )
                : GridView.builder(
                    itemCount: itemsForType.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16),
                    itemBuilder: (ctx, i) {
                      final item = itemsForType[i];
                      return GestureDetector(
                        onDoubleTap: _navigateToAddDefSup,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.inventory_2_rounded,
                                      size: 20,
                                      color: theme.colorScheme.primary),
                                ),
                                const Spacer(),
                                Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(
                                  _catalogSubtitle(item),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Colors.black.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _catalogSubtitle(DefSup item) {
    final lines = <String>[];
    final description = item.description.trim();
    if (description.isNotEmpty) {
      lines.add(description);
    }
    if (item.cost > 0) {
      lines.add('Price: ₱${item.cost.toStringAsFixed(2)}');
    } else {
      lines.add('Price: No price yet');
    }
    return lines.join('\n');
  }
}
