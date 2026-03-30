import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/supply_model.dart';
import '../providers/supplies_provider.dart';
import '../screens/frm_add_sup_screen.dart';
import '../themes/app_visuals.dart';

class SuppliesTab extends StatefulWidget {
  final String? selectedSupplyId;
  final ValueChanged<String?>? onSelectedSupplyChanged;

  const SuppliesTab({
    super.key,
    this.selectedSupplyId,
    this.onSelectedSupplyChanged,
  });

  @override
  State<SuppliesTab> createState() => _SuppliesTabState();
}

class _SuppliesTabState extends State<SuppliesTab> {
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
              return _buildSupplyCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSupplyCard(Supply item) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = widget.selectedSupplyId == item.id;

    return GestureDetector(
      onTap: () => widget.onSelectedSupplyChanged
          ?.call(isSelected ? null : item.id),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.46)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.7)
                : scheme.outline.withValues(alpha: 0.35),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: IconButton(
                onPressed: () => widget.onSelectedSupplyChanged
                    ?.call(isSelected ? null : item.id),
                icon: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
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
                ],
              ),
            ),
            if (isSelected) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SupplyFieldRow(label: 'Name', value: item.name),
                    _SupplyFieldRow(
                      label: 'Description',
                      value: item.description.trim().isEmpty
                          ? 'None'
                          : item.description.trim(),
                    ),
                    _SupplyFieldRow(
                      label: 'Quantity',
                      value: '${item.quantity}',
                    ),
                    _SupplyFieldRow(
                      label: 'Cost',
                      value: '\u20B1${item.cost.toStringAsFixed(2)}',
                    ),
                    _SupplyFieldRow(
                      label: 'Total',
                      value: '\u20B1${item.total.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _editSupply(item),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit'),
                        ),
                        FilledButton.icon(
                          onPressed: () => _confirmDelete(item.id),
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editSupply(Supply item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrmAddSupScreen(editSupplyId: item.id),
      ),
    );
  }

  void _handleResupply(Supply item) async {
    final txtQ = TextEditingController();
    final txtCost = TextEditingController(text: item.cost.toString());
    final scheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
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

  Future<void> _confirmDelete(String supplyId) async {
    final scheme = Theme.of(context).colorScheme;
    final suppliesProvider = Provider.of<SuppliesProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
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

    if (confirm != true) return;

    await suppliesProvider.deleteSupply(supplyId);
    if (!mounted) return;

    widget.onSelectedSupplyChanged?.call(null);
  }
}

class _SupplyFieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _SupplyFieldRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

