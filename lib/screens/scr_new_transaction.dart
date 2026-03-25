import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../providers/ftracker_provider.dart';
import '../services/rice_knowledge_service.dart';
import '../services/sugarcane_knowledge_service.dart';
import '../themes/app_visuals.dart';
import '../widgets/calculator_widget.dart';

enum TransactionType { expense, revenue }

class ScrNewTransaction extends StatefulWidget {
  const ScrNewTransaction({super.key});

  @override
  State<ScrNewTransaction> createState() => _ScrNewTransactionState();
}

class _ScrNewTransactionState extends State<ScrNewTransaction> {
  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  String _note = '';
  String _category = '';
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onCalculatorResultChanged(String value) {
    setState(() {
      if (value == '<-') {
        if (_amountController.text.length > 1) {
          _amountController.text = _amountController.text
              .substring(0, _amountController.text.length - 1);
        } else {
          _amountController.text = '0';
        }
      } else if (value == '.') {
        if (!_amountController.text.contains('.')) {
          _amountController.text += '.';
        }
      } else {
        if (_amountController.text == '0') {
          _amountController.text = value;
        } else {
          _amountController.text += value;
        }
      }
    });
  }

  void _showNoteDialog() async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        final noteController = TextEditingController(text: _note);
        return AlertDialog(
          backgroundColor: AppVisuals.cloudGlass,
          title: const Text('Note:',
              style: TextStyle(color: AppVisuals.textForest)),
          content: SingleChildScrollView(
            child: TextField(
              stylusHandwritingEnabled: false,
              controller: noteController,
              autofocus: true,
              style: const TextStyle(color: AppVisuals.textForest),
              decoration: const InputDecoration(
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red)),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel',
                  style: TextStyle(
                      color: AppVisuals.textForest.withValues(alpha: 0.55))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(noteController.text),
            ),
          ],
        );
      },
    );

    if (note != null) {
      setState(() {
        _note = note;
      });
    }
  }

  void _addTransaction() async {
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    final farmType = farmProvider.selectedFarm?.type.toLowerCase();
    final selectedCategory = _category.trim();
    if (selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final selectedName = _nameController.text.trim();
    if (selectedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a transaction name')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final sanitizedNote = _note.trim();
    final dType =
        _selectedType == TransactionType.expense ? 'Expenses' : 'Income';
    try {
      await Provider.of<FtrackerProvider>(context, listen: false).transRec(
        dDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        dType: dType,
        dAmount: amount,
        category: selectedCategory,
        name: selectedName,
        note: sanitizedNote.isNotEmpty ? sanitizedNote : null,
      );
      if (mounted) {
        if (farmType == 'sugarcane' || farmType == 'rice') {
          final isRice = farmType == 'rice';
          final tip = isRice
              ? RiceKnowledgeService.randomTip()
              : SugarcaneKnowledgeService.randomTip();
          if (tip.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('RCAMARii ${isRice ? 'rice' : 'sugarcane'} tip: $tip'),
              duration: const Duration(seconds: 4),
            ));
          }
        }
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> dataList = [
      {'Household': 'Bills'},
      {'Farm': 'Business'},
      {'Healthcare': 'Salary'},
      {'Maintenance': 'Utilities'},
      {'Education': 'Loans'},
      {'Gifts': 'Personal'},
      {'Recurring': 'Investment'},
    ];
    final allCategories = dataList
        .expand((item) => [item.keys.first, item.values.first])
        .toList();

    final Map<String, IconData> categoryIcons = {
      'Household': Icons.home_outlined,
      'Bills': Icons.receipt_long_outlined,
      'Farm': Icons.agriculture_outlined,
      'Business': Icons.business_center_outlined,
      'Healthcare': Icons.local_hospital_outlined,
      'Salary': Icons.payments_outlined,
      'Maintenance': Icons.build_outlined,
      'Utilities': Icons.lightbulb_outline,
      'Education': Icons.school_outlined,
      'Loans': Icons.account_balance_wallet_outlined,
      'Gifts': Icons.card_giftcard_outlined,
      'Personal': Icons.person_outline,
      'Recurring': Icons.autorenew_outlined,
      'Investment': Icons.trending_up_outlined,
    };

    return Scaffold(
      backgroundColor: AppVisuals.fieldMist,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppVisuals.textForest, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            final calculatorHeight =
                (constraints.maxHeight * (viewInsets.bottom > 0 ? 0.24 : 0.32))
                    .clamp(160.0, 260.0)
                    .toDouble();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toggle button
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppVisuals.cloudGlass,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppVisuals.textForest
                                  .withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            _buildTypeButton(
                                TransactionType.expense, Colors.red),
                            _buildTypeButton(
                                TransactionType.revenue, Colors.green.shade700),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Amount display
                      Text('Enter Amount',
                          style: TextStyle(
                              color:
                                  AppVisuals.textForest.withValues(alpha: 0.55),
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('₱',
                                style: TextStyle(
                                    color: AppVisuals.textForest,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 58,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Text(
                                    _amountController.text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppVisuals.textForest,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Date and Note buttons
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _buildDateNoteButton(
                              icon: Icons.calendar_today_outlined,
                              label: DateFormat('MMM dd').format(_selectedDate),
                              onTap: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    _selectedDate = pickedDate;
                                  });
                                }
                              }),
                          _buildDateNoteButton(
                              icon: Icons.notes_outlined,
                              label: _note.isEmpty ? 'Note' : 'Note (Set)',
                              onTap: _showNoteDialog),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Category selector
                      SizedBox(
                          height: 100.0,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: (allCategories.length / 2).ceil(),
                            itemBuilder: (context, index) {
                              return Wrap(
                                direction: Axis.vertical,
                                spacing: 8.0,
                                runSpacing: 12.0,
                                children: List.generate(2, (i) {
                                  final itemIndex = index * 2 + i;
                                  if (itemIndex >= allCategories.length) {
                                    return Container();
                                  }
                                  final category = allCategories[itemIndex];
                                  return InkWell(
                                    onTap: () {
                                      setState(() => _category = category);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      decoration: BoxDecoration(
                                        color: _category == category
                                            ? (_selectedType ==
                                                    TransactionType.expense
                                                ? Colors.red
                                                    .withValues(alpha: 0.2)
                                                : Colors.green
                                                    .withValues(alpha: 0.2))
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: _category ==
                                                    category
                                                ? (_selectedType ==
                                                        TransactionType.expense
                                                    ? Colors.red
                                                    : Colors.green.shade700)
                                                : Colors.grey[800],
                                            child: Icon(
                                                categoryIcons[category] ??
                                                    Icons.category,
                                                color: _category == category
                                                    ? Colors.white
                                                    : Colors.grey[400],
                                                size: 22),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _category == category
                                                  ? (_selectedType ==
                                                          TransactionType
                                                              .expense
                                                      ? Colors.red
                                                      : Colors.green.shade700)
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          )),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: TextField(
                          stylusHandwritingEnabled: false,
                          controller: _nameController,
                          style: const TextStyle(color: AppVisuals.textForest),
                          decoration: InputDecoration(
                            labelText: 'Name',
                            hintText: 'What is this transaction for?',
                            labelStyle: TextStyle(
                                color: AppVisuals.textForest
                                    .withValues(alpha: 0.55)),
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: AppVisuals.cloudGlass,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade800),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade800),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: AppVisuals.textForest
                                      .withValues(alpha: 0.45)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey, thickness: 0.2),

                      // Calculator
                      SizedBox(
                        height: calculatorHeight,
                        child: CalculatorWidget(
                          onResultChanged: _onCalculatorResultChanged,
                        ),
                      ),

                      // Save button
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _addTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selectedType == TransactionType.expense
                                      ? Colors.red
                                      : Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Save Transaction',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypeButton(TransactionType type, Color color) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
              child: Text(type.name[0].toUpperCase() + type.name.substring(1),
                  style: TextStyle(
                      color: isSelected ? Colors.white : AppVisuals.textForest,
                      fontSize: 16))),
        ),
      ),
    );
  }

  Widget _buildDateNoteButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppVisuals.cloudGlass,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppVisuals.textForest.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: AppVisuals.textForest.withValues(alpha: 0.55), size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: AppVisuals.textForest, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
