import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/data_provider.dart';
import '../screens/frm_add_sup_screen.dart';
import '../screens/frm_add_def_sup_screen.dart';
import '../models/supply_model.dart';
import '../models/def_sup_model.dart';

class UserSuppliesView extends StatefulWidget {
  const UserSuppliesView({super.key});

  @override
  State<UserSuppliesView> createState() => _UserSuppliesViewState();
}

class _UserSuppliesViewState extends State<UserSuppliesView>
    with TickerProviderStateMixin {
  bool _showScr2 = false;
  String? _selectedSupplyId;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    Provider.of<SuppliesProvider>(context, listen: false).loadSupplies();
  }

  void _toggleScreen() {
    setState(() {
      _showScr2 = !_showScr2;
      if (_showScr2) {
        final dataProvider = Provider.of<DataProvider>(context, listen: false);
        final types = dataProvider.defSups.map((e) => e.type).toSet().toList();
        _tabController = TabController(length: types.length, vsync: this);
      }
    });
  }

  void _showResupplyDialog(Supply supply) {
    final quantityController = TextEditingController();
    final costController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resupply ${supply.name}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  stylusHandwritingEnabled: false,
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'How many:'),
                  keyboardType: TextInputType.number),
              TextField(
                  stylusHandwritingEnabled: false,
                  controller: costController,
                  decoration: const InputDecoration(labelText: 'Unit Cost:'),
                  keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              final cost = double.tryParse(costController.text) ?? 0.0;
              if (quantity > 0 && cost > 0) {
                Provider.of<SuppliesProvider>(context, listen: false)
                    .resupply(supply.id, quantity, cost);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _deleteSupply() {
    if (_selectedSupplyId != null) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: const Text(
                      'Are you sure you want to delete this item in your supply?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('No')),
                    TextButton(
                        onPressed: () {
                          Provider.of<SuppliesProvider>(context, listen: false)
                              .deleteSupply(_selectedSupplyId!);
                          setState(() => _selectedSupplyId = null);
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Yes'))
                  ]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplyProvider = Provider.of<SuppliesProvider>(context);
    if (supplyProvider.items.isNotEmpty && _selectedSupplyId == null) {
      _selectedSupplyId = supplyProvider.items.first.id;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _showScr2 ? _buildScr2() : _buildScr1(),
    );
  }

  Widget _buildScr1() {
    final supplyProvider = Provider.of<SuppliesProvider>(context);
    final supplies = supplyProvider.items;
    final theme = Theme.of(context);
    final totalValue =
        supplies.fold<double>(0.0, (sum, supply) => sum + supply.total);
    final lowStock = supplies.where((s) => s.quantity <= 3).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.95),
                theme.colorScheme.secondary.withValues(alpha: 0.2),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                  child: _buildSummaryCard(
                      totalValue, lowStock, supplies.length, theme),
                ),
                Expanded(
                  child: supplies.isEmpty
                      ? _buildEmptyState(theme)
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _columnsForWidth(width),
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                            childAspectRatio: 1.15,
                          ),
                          itemCount: supplies.length,
                          itemBuilder: (context, index) {
                            final supply = supplies[index];
                            return _SupplyCard3D(
                              supply: supply,
                              selected: supply.id == _selectedSupplyId,
                              onTap: () =>
                                  setState(() => _selectedSupplyId = supply.id),
                              onResupply: () => _showResupplyDialog(supply),
                            );
                          },
                        ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: _buildSupplyActions(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScr2() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final theme = Theme.of(context);
    final types = dataProvider.defSups.map((e) => e.type).toSet().toList();
    if (types.isEmpty) {
      return Center(
        child:
            Text('No defined supplies yet.', style: theme.textTheme.bodyLarge),
      );
    }
    if (_tabController == null || _tabController!.length != types.length) {
      _tabController = TabController(length: types.length, vsync: this);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.95),
            theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white24),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(28),
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                tabs: types.map((type) => Tab(text: type)).toList(),
                onTap: (index) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: types.map((type) {
                  final items = dataProvider.defSups
                      .where((e) => e.type == type)
                      .toList();
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (items.isEmpty) {
                        return _buildEmptyDefState(theme);
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              _columnsForWidth(constraints.maxWidth),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.05,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _DefSupplyCard3D(
                            defSup: items[index],
                            onAdd: () => _showAddFromDefSupDialog(items[index]),
                          );
                        },
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Def'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FrmAddDefSupScreen())),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Def'),
                    onPressed: () {},
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    onPressed: _toggleScreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFromDefSupDialog(DefSup defSup) {
    final quantityController = TextEditingController();
    final costController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to My Supplies?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                stylusHandwritingEnabled: false,
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'How many:'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                stylusHandwritingEnabled: false,
                controller: costController,
                decoration: const InputDecoration(labelText: 'Unit Cost:'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              final cost = double.tryParse(costController.text) ?? 0.0;
              if (quantity > 0 && cost > 0) {
                final newSupply = Supply(
                  id: DateTime.now().toString(),
                  name: defSup.name,
                  description: defSup.description,
                  quantity: quantity,
                  cost: cost,
                  total: cost * quantity,
                );
                Provider.of<SuppliesProvider>(context, listen: false)
                    .addSupply(newSupply);
                _toggleScreen(); // Switch back to the main supplies view
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  int _columnsForWidth(double width) {
    if (width >= 1200) return 3;
    if (width >= 860) return 2;
    return 1;
  }

  Widget _buildSummaryCard(
      double totalValue, int lowStock, int totalItems, ThemeData theme) {
    final headline = theme.textTheme.titleLarge;
    final subhead = theme.textTheme.bodyLarge ?? const TextStyle();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final valueSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory Value', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                '\$${totalValue.toStringAsFixed(2)}',
                style: headline?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold) ??
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('$totalItems items tracked',
                  style: subhead.copyWith(
                      color:
                          theme.colorScheme.onPrimary.withValues(alpha: 0.8))),
            ],
          );
          final stockSection = Column(
            crossAxisAlignment: constraints.maxWidth < 460
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(lowStock > 0 ? 'Low stock' : 'Fully stocked',
                  style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                lowStock.toString(),
                style: headline?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold) ??
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('items under 3 pcs',
                  style: subhead.copyWith(
                      color:
                          theme.colorScheme.secondary.withValues(alpha: 0.8))),
            ],
          );

          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                valueSection,
                const SizedBox(height: 16),
                stockSection,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: valueSection),
              const SizedBox(width: 16),
              stockSection,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupplyActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth < 560;
        final buttonWidth =
            fullWidth ? constraints.maxWidth : (constraints.maxWidth - 16) / 3;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add New'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FrmAddSupScreen())),
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
                onPressed: _selectedSupplyId == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FrmAddSupScreen(
                                  editSupplyId: _selectedSupplyId)),
                        ),
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                onPressed: _selectedSupplyId == null ? null : _deleteSupply,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2,
              size: 64,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text('No supplies yet',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 6),
          Text('Tap "Add New" to start building your stock.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _buildEmptyDefState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_circle,
              size: 60,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text('No definitions yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Add your defined supplies so you can reuse them in one tap.',
              style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SupplyCard3D extends StatelessWidget {
  final Supply supply;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onResupply;

  const _SupplyCard3D({
    required this.supply,
    required this.selected,
    required this.onTap,
    required this.onResupply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateX(selected ? -0.055 : -0.035)
      ..rotateY(selected ? 0.05 : 0.03);
    return GestureDetector(
      onTap: onTap,
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color:
                    selected ? theme.colorScheme.secondary : Colors.transparent,
                width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                          selected ? theme.colorScheme.secondary : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      supply.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: onResupply,
                    tooltip: 'Resupply',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                supply.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text('Qty ${supply.quantity}'),
                    backgroundColor: Colors.white24,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('\$${supply.total.toStringAsFixed(2)}'),
                    backgroundColor: Colors.white24,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Unit cost: \$${supply.cost.toStringAsFixed(2)}',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefSupplyCard3D extends StatelessWidget {
  final DefSup defSup;
  final VoidCallback onAdd;

  const _DefSupplyCard3D({
    required this.defSup,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(-0.03)
      ..rotateY(0.025);
    return GestureDetector(
      onTap: onAdd,
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.secondary,
                theme.colorScheme.secondary.withValues(alpha: 0.6),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                defSup.type,
                style:
                    theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                defSup.name,
                style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  defSup.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${defSup.cost.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
