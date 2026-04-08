import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/delivery_model.dart';
import '../models/farm_model.dart';
import '../models/sugarcane_profit_model.dart';
import '../providers/app_settings_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/ftracker_provider.dart';
import '../providers/sugarcane_profit_provider.dart';
import '../services/database_helper.dart';
import '../themes/app_visuals.dart';
import '../widgets/searchable_dropdown.dart';
import 'absfi_share_guide_screen.dart';

class HarvestBoardSugarcaneProfitScreen extends StatefulWidget {
  const HarvestBoardSugarcaneProfitScreen({
    super.key,
    required this.farm,
    required this.pendingDeliveries,
    this.closeToFarmTabOnClose = false,
  });

  final Farm farm;
  final List<Delivery> pendingDeliveries;
  final bool closeToFarmTabOnClose;

  @override
  State<HarvestBoardSugarcaneProfitScreen> createState() =>
      _HarvestBoardSugarcaneProfitScreenState();
}

class _HarvestBoardSugarcaneProfitScreenState
    extends State<HarvestBoardSugarcaneProfitScreen> {
  static const double _absfiPlanterShare = 65.34;
  static final _numberFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'));

  final TextEditingController _netTonsCaneController = TextEditingController();
  final TextEditingController _lkgPerTcController = TextEditingController();
  final TextEditingController _planterShareController = TextEditingController();
  final TextEditingController _sugarPricePerLkgController =
      TextEditingController();
  final TextEditingController _molassesKgController = TextEditingController();
  final TextEditingController _molassesPricePerKgController =
      TextEditingController();
  final TextEditingController _productionCostsController =
      TextEditingController();
  static const String _planterShareTooltipMessage =
      'Example: 70\nABSFI formula: 66.00% planter share - 1% of 66.00% (0.66%) = 65.34%.';

  int? _selectedPendingDeliveryId;

  NumberFormat get _currency =>
      Provider.of<AppSettingsProvider?>(context, listen: false)
          ?.currencyFormat ??
      NumberFormat.currency(locale: 'en_PH', symbol: '\u20B1');

  @override
  void initState() {
    super.initState();
    if (widget.pendingDeliveries.isNotEmpty) {
      final firstDelivery = widget.pendingDeliveries.first;
      _selectedPendingDeliveryId = firstDelivery.delId;
      _applyPendingDelivery(firstDelivery);
    }
  }

  @override
  void dispose() {
    _netTonsCaneController.dispose();
    _lkgPerTcController.dispose();
    _planterShareController.dispose();
    _sugarPricePerLkgController.dispose();
    _molassesKgController.dispose();
    _molassesPricePerKgController.dispose();
    _productionCostsController.dispose();
    super.dispose();
  }

  double _parseNumber(String input) =>
      double.tryParse(input.replaceAll(',', '').trim()) ?? 0;

  String _extractTaggedValue(String? note, String tag) {
    final raw = note?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    for (final part in raw.split('|')) {
      final trimmed = part.trim();
      if (trimmed.toLowerCase().startsWith('${tag.toLowerCase()}:')) {
        return trimmed.substring(tag.length + 1).trim();
      }
    }
    return '';
  }

  String _deliveryReportLabel(Delivery delivery) {
    final batch = _extractTaggedValue(delivery.note, 'Batch');
    if (batch.isNotEmpty) {
      return batch;
    }
    return delivery.name;
  }

  double _extractTaggedAmount(String? note, String tag) {
    return _parseNumber(_extractTaggedValue(note, tag));
  }

  String _associationNameForDelivery(Delivery delivery) {
    final company = _extractTaggedValue(delivery.note, 'Company');
    if (company.isNotEmpty) {
      return company;
    }
    return delivery.name.trim().isEmpty ? 'Unspecified' : delivery.name.trim();
  }

  bool _usesAbsfiShare(Delivery delivery) {
    return _associationNameForDelivery(delivery).trim().toUpperCase() ==
        'ABSFI';
  }

  double _truckingAllowanceForDelivery(Delivery delivery) {
    return _extractTaggedAmount(delivery.note, 'Trucking Allowance');
  }

  double _truckingRentalForDelivery(Delivery delivery) {
    return _extractTaggedAmount(delivery.note, 'Trucking Rental');
  }

  double _truckingExpensesForDelivery(Delivery delivery) {
    return _truckingAllowanceForDelivery(delivery) +
        _truckingRentalForDelivery(delivery);
  }

  String _formatInputNumber(double value) {
    if (value <= 0) {
      return '';
    }
    return value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
  }

  void _applyPendingDelivery(Delivery? delivery) {
    if (delivery == null) {
      return;
    }
    if (delivery.quantity > 0) {
      _netTonsCaneController.text = delivery.quantity.toStringAsFixed(
        delivery.quantity.truncateToDouble() == delivery.quantity ? 0 : 2,
      );
    }
    _productionCostsController.text =
        _formatInputNumber(_truckingExpensesForDelivery(delivery));
    if (_usesAbsfiShare(delivery)) {
      _planterShareController.text = _formatInputNumber(_absfiPlanterShare);
    }
  }

  void _openAbsfiGuide() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AbsfiShareGuideScreen()),
    );
  }

  _SugarcaneProfitDraft _profitDraftForInput() {
    final netTonsCane = _parseNumber(_netTonsCaneController.text);
    final lkgPerTc = _parseNumber(_lkgPerTcController.text);
    final planterShare = _parseNumber(_planterShareController.text);
    final sugarPricePerLkg = _parseNumber(_sugarPricePerLkgController.text);
    final molassesKg = _parseNumber(_molassesKgController.text);
    final molassesPricePerKg = _parseNumber(_molassesPricePerKgController.text);
    final productionCosts = _parseNumber(_productionCostsController.text);
    final planterShareDecimal = planterShare / 100;
    final sugarProceeds =
        netTonsCane * lkgPerTc * planterShareDecimal * sugarPricePerLkg;
    final molassesProceeds = molassesKg * molassesPricePerKg;
    final totalRevenue = sugarProceeds + molassesProceeds;
    final netProfit = totalRevenue - productionCosts;

    return _SugarcaneProfitDraft(
      netTonsCane: netTonsCane,
      lkgPerTc: lkgPerTc,
      planterShare: planterShare,
      sugarPricePerLkg: sugarPricePerLkg,
      molassesKg: molassesKg,
      molassesPricePerKg: molassesPricePerKg,
      productionCosts: productionCosts,
      sugarProceeds: sugarProceeds,
      molassesProceeds: molassesProceeds,
      totalRevenue: totalRevenue,
      netProfit: netProfit,
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _closePendingPayment() {
    Navigator.of(context).pop(
      widget.closeToFarmTabOnClose ? 'close_to_tab_farm' : false,
    );
  }

  Future<void> _savePendingSugarcaneProfit() async {
    final selectedDelivery =
        widget.pendingDeliveries.cast<Delivery?>().firstWhere(
              (delivery) => delivery?.delId == _selectedPendingDeliveryId,
              orElse: () => null,
            );
    if (selectedDelivery == null) {
      _showMessage('Select a pending delivery first.');
      return;
    }

    final draft = _profitDraftForInput();
    if (draft.netTonsCane <= 0) {
      _showMessage('Net Weight of Cane must be greater than zero.');
      return;
    }
    if (draft.lkgPerTc <= 0) {
      _showMessage('LKG/TC must be greater than zero.');
      return;
    }
    if (draft.planterShare <= 0) {
      _showMessage('Planter Share must be greater than zero.');
      return;
    }
    if (draft.sugarPricePerLkg <= 0) {
      _showMessage('Sugar Price per LKG must be greater than zero.');
      return;
    }
    if (draft.productionCosts <= 0) {
      _showMessage('Trucking Expenses must be greater than zero.');
      return;
    }

    final associationName = _associationNameForDelivery(selectedDelivery);
    final truckingAllowance = _truckingAllowanceForDelivery(selectedDelivery);
    final truckingRental = _truckingRentalForDelivery(selectedDelivery);
    final ftrackerProvider =
        Provider.of<FtrackerProvider?>(context, listen: false);
    final deliveryProvider =
        Provider.of<DeliveryProvider?>(context, listen: false);
    final profitProvider =
        Provider.of<SugarcaneProfitProvider?>(context, listen: false);
    final trackerDate = DateFormat('yyyy-MM-dd').format(selectedDelivery.date);
    final trackerNote = selectedDelivery.note?.trim().isNotEmpty ?? false
        ? selectedDelivery.note!.trim()
        : 'Harvest Board pending payment for ${_deliveryReportLabel(selectedDelivery)}';

    final profitRecord = SugarcaneProfit(
      deliveryId: selectedDelivery.delId,
      sourceType: 'harvest_board',
      sourceLabel: _deliveryReportLabel(selectedDelivery),
      sourceStatus: 'completed',
      farmName: widget.farm.name,
      deliveryDate: selectedDelivery.date,
      netTonsCane: draft.netTonsCane,
      lkgPerTc: draft.lkgPerTc,
      planterShare: draft.planterShare,
      sugarPricePerLkg: draft.sugarPricePerLkg,
      molassesKg: draft.molassesKg,
      molassesPricePerKg: draft.molassesPricePerKg,
      productionCosts: draft.productionCosts,
      sugarProceeds: draft.sugarProceeds,
      molassesProceeds: draft.molassesProceeds,
      totalRevenue: draft.totalRevenue,
      netProfit: draft.netProfit,
      note: selectedDelivery.note,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.runInTransaction((txn) async {
      await txn.insert(
        DatabaseHelper.tableSugarcaneProfits,
        profitRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        DatabaseHelper.tableDeliveries,
        <String, Object?>{
          'Quantity': draft.netTonsCane,
          'Total': draft.totalRevenue,
        },
        where: 'DelID = ?',
        whereArgs: <Object?>[selectedDelivery.delId],
      );
      if (ftrackerProvider != null && truckingAllowance > 0) {
        await txn.insert(
          DatabaseHelper.tableFtracker,
          ftrackerProvider
              .buildRecord(
                dDate: trackerDate,
                dType: 'Expenses',
                dAmount: truckingAllowance,
                category: 'Sugarcane',
                name: '$associationName Trucking Allowance',
                note: trackerNote,
              )
              .toMap(),
        );
      }
      if (ftrackerProvider != null && truckingRental > 0) {
        await txn.insert(
          DatabaseHelper.tableFtracker,
          ftrackerProvider
              .buildRecord(
                dDate: trackerDate,
                dType: 'Expenses',
                dAmount: truckingRental,
                category: 'Sugarcane',
                name: '$associationName Trucking Rental',
                note: trackerNote,
              )
              .toMap(),
        );
      }
    });

    await Future.wait([
      if (deliveryProvider != null) deliveryProvider.loadDeliveries(),
      if (ftrackerProvider != null) ftrackerProvider.loadFtrackerRecords(),
      if (profitProvider != null) profitProvider.loadProfitRecords(),
    ]);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedDelivery =
        widget.pendingDeliveries.cast<Delivery?>().firstWhere(
              (delivery) => delivery?.delId == _selectedPendingDeliveryId,
              orElse: () => null,
            );
    final draft = _profitDraftForInput();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closePendingPayment();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackdrop(
          isDark: theme.brightness == Brightness.dark,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: _closePendingPayment,
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PENDING PAYMENT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w900,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.farm.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppVisuals.textForest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FrostedPanel(
                    radius: 30,
                    padding: const EdgeInsets.all(22),
                    color: scheme.surface.withValues(alpha: 0.88),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Income per Truckload',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppVisuals.textForest,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select the queued sugarcane delivery you want to complete for this pending payment entry.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppVisuals.textForestMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SearchableDropdownFormField<int>(
                          initialValue: widget.pendingDeliveries.any(
                            (delivery) =>
                                delivery.delId == _selectedPendingDeliveryId,
                          )
                              ? _selectedPendingDeliveryId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Pending delivery',
                          ),
                          items: widget.pendingDeliveries
                              .where((delivery) => delivery.delId != null)
                              .map(
                                (delivery) => DropdownMenuItem<int>(
                                  value: delivery.delId!,
                                  child: Text(
                                    '${_deliveryReportLabel(delivery)} | ${delivery.ticketNo?.trim().isEmpty ?? true ? 'Tracking pending' : delivery.ticketNo!.trim()} | ${DateFormat('MMM d, y').format(delivery.date)}',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            final delivery = widget.pendingDeliveries
                                .cast<Delivery?>()
                                .firstWhere(
                                  (item) => item?.delId == value,
                                  orElse: () => null,
                                );
                            setState(() {
                              _selectedPendingDeliveryId = value;
                            });
                            _applyPendingDelivery(delivery);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildProfitInputs(theme),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppVisuals.cloudGlass,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedDelivery == null
                                    ? 'Select a pending delivery to complete the profit entry.'
                                    : 'Linked to ${_deliveryReportLabel(selectedDelivery)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppVisuals.textForest,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sugar Proceeds: ${_currency.format(draft.sugarProceeds)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppVisuals.textForestMuted,
                                ),
                              ),
                              Text(
                                'Molasses Proceeds: ${_currency.format(draft.molassesProceeds)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppVisuals.textForestMuted,
                                ),
                              ),
                              Text(
                                'Total Revenue: ${_currency.format(draft.totalRevenue)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppVisuals.textForestMuted,
                                ),
                              ),
                              Text(
                                'Net Profit: ${_currency.format(draft.netProfit)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppVisuals.textForestMuted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _savePendingSugarcaneProfit,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Post to Harvest Board'),
                            ),
                            TextButton(
                              onPressed: _closePendingPayment,
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'ABSFI share guide',
                          onPressed: _openAbsfiGuide,
                          icon: const Icon(Icons.help_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfitInputs(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Net Weight of Cane',
                child: _FocusTooltipTextField(
                  message: 'Example: 100',
                  controller: _netTonsCaneController,
                  inputFormatters: <TextInputFormatter>[_numberFormatter],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(suffixText: 'tons'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LabeledField(
                label: 'LKG / TC',
                child: _FocusTooltipTextField(
                  message: 'Example: 1.80',
                  controller: _lkgPerTcController,
                  inputFormatters: <TextInputFormatter>[_numberFormatter],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Planter Share',
                child: _FocusTooltipTextField(
                  message: _planterShareTooltipMessage,
                  controller: _planterShareController,
                  inputFormatters: <TextInputFormatter>[_numberFormatter],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(suffixText: '%'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LabeledField(
                label: 'Sugar Price Per LKG',
                child: _FocusTooltipTextField(
                  message: 'Example: 55',
                  controller: _sugarPricePerLkgController,
                  inputFormatters: <TextInputFormatter>[_numberFormatter],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Molasses Quantity',
                child: _FocusTooltipTextField(
                  message: 'Example: 0',
                  controller: _molassesKgController,
                  inputFormatters: <TextInputFormatter>[_numberFormatter],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(suffixText: 'kg'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LabeledField(
                label: 'Molasses Price Per KG',
                child: _FocusTooltipTextField(
                  message: 'Example: 12',
                  controller: _molassesPricePerKgController,
                  inputFormatters: <TextInputFormatter>[_numberFormatter],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LabeledField(
          label: 'Trucking Expenses',
          child: _FocusTooltipTextField(
            message: 'Allowance + rental total',
            controller: _productionCostsController,
            inputFormatters: <TextInputFormatter>[_numberFormatter],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(),
          ),
        ),
      ],
    );
  }
}

class _SugarcaneProfitDraft {
  const _SugarcaneProfitDraft({
    required this.netTonsCane,
    required this.lkgPerTc,
    required this.planterShare,
    required this.sugarPricePerLkg,
    required this.molassesKg,
    required this.molassesPricePerKg,
    required this.productionCosts,
    required this.sugarProceeds,
    required this.molassesProceeds,
    required this.totalRevenue,
    required this.netProfit,
  });

  final double netTonsCane;
  final double lkgPerTc;
  final double planterShare;
  final double sugarPricePerLkg;
  final double molassesKg;
  final double molassesPricePerKg;
  final double productionCosts;
  final double sugarProceeds;
  final double molassesProceeds;
  final double totalRevenue;
  final double netProfit;
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _FocusTooltipTextField extends StatefulWidget {
  const _FocusTooltipTextField({
    required this.message,
    required this.controller,
    required this.decoration,
    this.inputFormatters,
    this.keyboardType,
  });

  final String message;
  final TextEditingController controller;
  final InputDecoration decoration;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;

  @override
  State<_FocusTooltipTextField> createState() => _FocusTooltipTextFieldState();
}

class _FocusTooltipTextFieldState extends State<_FocusTooltipTextField> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _tooltipKey.currentState?.ensureTooltipVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      triggerMode: TooltipTriggerMode.manual,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 4),
      child: TextField(
        focusNode: _focusNode,
        controller: widget.controller,
        inputFormatters: widget.inputFormatters,
        keyboardType: widget.keyboardType,
        decoration: widget.decoration,
      ),
    );
  }
}
