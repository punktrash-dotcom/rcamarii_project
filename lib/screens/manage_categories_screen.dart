import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../themes/app_visuals.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'icon': Icons.fastfood_outlined, 'color': Colors.orange},
    {
      'name': 'Transport',
      'icon': Icons.directions_bus_outlined,
      'color': Colors.blue
    },
    {
      'name': 'Shopping',
      'icon': Icons.shopping_bag_outlined,
      'color': Colors.pink
    },
    {'name': 'Bills', 'icon': Icons.receipt_long_outlined, 'color': Colors.red},
    {'name': 'Salary', 'icon': Icons.payments_outlined, 'color': Colors.green},
  ];

  final List<IconData> _availableIcons = [
    Icons.fastfood_outlined,
    Icons.directions_bus_outlined,
    Icons.shopping_bag_outlined,
    Icons.receipt_long_outlined,
    Icons.payments_outlined,
    Icons.home_outlined,
    Icons.agriculture_outlined,
    Icons.business_center_outlined,
    Icons.local_hospital_outlined,
    Icons.build_outlined,
    Icons.lightbulb_outline,
    Icons.school_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.card_giftcard_outlined,
    Icons.person_outline,
    Icons.autorenew_outlined,
    Icons.trending_up_outlined,
    Icons.movie_outlined,
    Icons.flight_takeoff_outlined,
    Icons.pets_outlined,
  ];

  void _showAddCategoryDialog() {
    final TextEditingController nameController = TextEditingController();
    IconData selectedIcon = _availableIcons[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFE8F0EC),
              title: const Text('Add New Category',
                  style: TextStyle(color: AppVisuals.textForest)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      stylusHandwritingEnabled: false,
                      controller: nameController,
                      style: const TextStyle(color: AppVisuals.textForest),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        labelStyle: TextStyle(
                            color: AppVisuals.textForest.withValues(alpha: 0.55)),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: AppVisuals.textForest
                                    .withValues(alpha: 0.22))),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Choose Icon',
                        style: TextStyle(
                            color: AppVisuals.textForest,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.maxFinite,
                      height: 200,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5),
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, index) {
                          final icon = _availableIcons[index];
                          final isSelected = selectedIcon == icon;
                          return IconButton(
                            icon: Icon(icon,
                                color: isSelected
                                    ? Colors.deepPurple
                                    : AppVisuals.textForest
                                        .withValues(alpha: 0.45)),
                            onPressed: () =>
                                setDialogState(() => selectedIcon = icon),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      setState(() {
                        _categories.add({
                          'name': nameController.text,
                          'icon': selectedIcon,
                          'color': Colors.deepPurple,
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple),
                  child: const Text('Add',
                      style: TextStyle(color: AppVisuals.softWhite)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.darkTheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFFD8E8E0) : Colors.grey[200],
      appBar: AppBar(
        title: const Text('Manage Categories',
            style: TextStyle(
                color: AppVisuals.textForest,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppVisuals.textForest),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 30),
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Card(
            color: const Color(0xFFE8F0EC),
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: category['color'].withValues(alpha: 0.1),
                child: Icon(category['icon'],
                    color: isDark ? Colors.deepPurpleAccent : category['color'],
                    size: 24),
              ),
              title: Text(category['name'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppVisuals.textForest)),
            ),
          );
        },
      ),
    );
  }
}
