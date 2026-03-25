import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/supply_model.dart';
import '../providers/supplies_provider.dart';
import '../screens/frm_add_sup_screen.dart';
import '../themes/app_visuals.dart';

class SuppliesTab extends StatefulWidget {
  const SuppliesTab({super.key});

  @override
  State<SuppliesTab> createState() => _SuppliesTabState();
}

class _SuppliesTabState extends State<SuppliesTab>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SuppliesProvider>(context, listen: false).loadSupplies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
              child: _buildScr1(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScr1() {
    final provider = Provider.of<SuppliesProvider>(context);
    final supplies = provider.items;
    final theme = Theme.of(context);

    if (supplies.isEmpty && !provider.isLoading) {
      return Center(
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FrmAddSupScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'You have no supplies yet. Click here to add new...',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: supplies.length,
            itemBuilder: (context, index) {
              final item = supplies[index];
              return _buildSupplyCard(item, provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSupplyCard(Supply item, SuppliesProvider provider) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              item.name,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              'Quantity: ${item.quantity}\nTotal Value: \u20B1${item.total.toStringAsFixed(2)}',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                height: 1.4,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  padding: EdgeInsets.zero,
                  onPressed: () => _handleResupply(item),
                  icon: Icon(
                    Icons.add_shopping_cart_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                  tooltip: 'Resupply',
                ),
                PopupMenuButton<SupplyCardAction>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                  onSelected: (action) =>
                      _handleCardAction(action, item, provider),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: SupplyCardAction.addNew,
                      child: Text(
                        'Add New',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    PopupMenuItem(
                      value: SupplyCardAction.edit,
                      child: Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    PopupMenuItem(
                      value: SupplyCardAction.delete,
                      child: Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleCardAction(
    SupplyCardAction action,
    Supply item,
    SuppliesProvider provider,
  ) {
    switch (action) {
      case SupplyCardAction.addNew:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FrmAddSupScreen()),
        );
        break;
      case SupplyCardAction.edit:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FrmAddSupScreen(editSupplyId: item.id),
          ),
        );
        break;
      case SupplyCardAction.delete:
        _confirmDelete(provider, item.id);
        break;
    }
  }

  void _handleResupply(Supply item) async {
    final txtQ = TextEditingController();
    final txtCost = TextEditingController(text: item.cost.toString());
    final scheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'RESUPPLY ${item.name.toUpperCase()}',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              stylusHandwritingEnabled: false,
              controller: txtQ,
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                labelText: 'QUANTITY',
                labelStyle: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              stylusHandwritingEnabled: false,
              controller: txtCost,
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                labelText: 'UNIT COST',
                labelStyle: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final q = int.tryParse(txtQ.text) ?? 0;
              final cost = double.tryParse(txtCost.text) ?? 0.0;
              if (q > 0 && cost > 0) {
                final suppliesProvider =
                    Provider.of<SuppliesProvider>(context, listen: false);
                await suppliesProvider.resupply(item.id, q, cost);
                if (!ctx.mounted) {
                  return;
                }
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(SuppliesProvider provider, String supplyId) async {
    final scheme = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: const Text(
          'CONFIRM DELETE',
          style: TextStyle(
            color: AppVisuals.primaryGold,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        content: Text(
          'Remove this item from your active supplies?',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'NO',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'DELETE',
              style: TextStyle(
                color: scheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.deleteSupply(supplyId);
      setState(() {});
    }
  }
}

enum SupplyCardAction { addNew, edit, delete }
