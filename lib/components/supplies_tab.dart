import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/def_sup_model.dart';
import '../models/supply_model.dart';
import '../providers/data_provider.dart';
import '../providers/supplies_provider.dart';
import '../screens/frm_add_def_sup_screen.dart';
import '../screens/frm_add_sup_screen.dart';

class SuppliesTab extends StatefulWidget {
  final SuppliesTabController? controller;

  const SuppliesTab({super.key, this.controller});

  @override
  State<SuppliesTab> createState() => _SuppliesTabState();
}

class _SuppliesTabState extends State<SuppliesTab>
    with TickerProviderStateMixin {
  bool _showScr2 = false;

  void _popScr1AndPushScr2() => setState(() => _showScr2 = true);
  void _popScr2AndPushScr1() => setState(() => _showScr2 = false);

  @override
  void initState() {
    super.initState();
    widget.controller?.bind(_popScr1AndPushScr2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SuppliesProvider>(context, listen: false).loadSupplies();
    });
  }

  @override
  void didUpdateWidget(covariant SuppliesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.bind(null);
      widget.controller?.bind(_popScr1AndPushScr2);
    }
  }

  @override
  void dispose() {
    widget.controller?.bind(null);
    super.dispose();
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
              child: _showScr2 ? _buildScr2() : _buildScr1(),
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

  Widget _buildScr2() {
    final scheme = Theme.of(context).colorScheme;
    final dataProvider = Provider.of<DataProvider>(context);
    final defSups = dataProvider.defSups;
    final groupedSupplies = <String, List<DefSup>>{};

    for (final item in defSups) {
      groupedSupplies.putIfAbsent(item.type, () => []).add(item);
    }
    final types = groupedSupplies.keys.toList();

    return Column(
      children: [
        AppBar(
          title: const Text(
            'CATALOG BROWSER',
            style: TextStyle(
              color: Color(0xFFEAC435),
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: scheme.onSurface,
              size: 18,
            ),
            onPressed: _popScr2AndPushScr1,
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add_box_outlined, color: scheme.secondary),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FrmAddDefSupScreen()),
              ),
            ),
          ],
        ),
        if (types.isNotEmpty)
          DefaultTabController(
            length: types.length,
            child: Expanded(
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    indicatorColor: scheme.primary,
                    labelColor: scheme.primary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    tabs: types.map((t) => Tab(text: t.toUpperCase())).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: types.map((type) {
                        final items = groupedSupplies[type]!;
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (ctx, i) {
                            final item = items[i];
                            return Card(
                              elevation: 0,
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.88,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: scheme.outline.withValues(alpha: 0.35),
                                ),
                              ),
                              child: ListTile(
                                title: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: scheme.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  _catalogSubtitle(item),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.add_circle_outline,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Center(
              child: Text(
                'Database empty',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
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
            color: Color(0xFFEAC435),
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

  String _catalogSubtitle(DefSup item) {
    final lines = <String>[];
    final description = item.description.trim();
    if (description.isNotEmpty) {
      lines.add(description);
    }
    lines.add(_catalogPriceLabel(item));
    return lines.join('\n');
  }

  String _catalogPriceLabel(DefSup item) {
    if (item.cost > 0) {
      return 'Price: \u20B1${item.cost.toStringAsFixed(2)}';
    }
    return 'Price: No price yet';
  }
}

class SuppliesTabController {
  VoidCallback? _handler;

  void bind(VoidCallback? handler) {
    _handler = handler;
  }

  void showDatabase() {
    _handler?.call();
  }
}

enum SupplyCardAction { addNew, edit, delete }
