import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../services/app_localization_service.dart';
import '../themes/app_visuals.dart';

enum HarvestCrop { rice, corn }

extension HarvestCropLabel on HarvestCrop {
  String get label => this == HarvestCrop.rice ? 'Rice' : 'Corn';

  IconData get icon =>
      this == HarvestCrop.rice ? Icons.rice_bowl_rounded : Icons.grain_rounded;
}

class HarvestProfitCalculatorScreen extends StatefulWidget {
  const HarvestProfitCalculatorScreen({
    super.key,
    required this.initialCrop,
  });

  final HarvestCrop initialCrop;

  @override
  State<HarvestProfitCalculatorScreen> createState() =>
      _HarvestProfitCalculatorScreenState();
}

class _HarvestProfitCalculatorScreenState
    extends State<HarvestProfitCalculatorScreen> {
  static const _screenBackground = AppVisuals.fieldMist;
  static final _numberInputFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'));

  final TextEditingController _yieldKgController = TextEditingController();
  final TextEditingController _kgPerBagController =
      TextEditingController(text: '50');
  final TextEditingController _pricePerKgController = TextEditingController();

  String _cropLabel(HarvestCrop crop) {
    return context.tr(crop == HarvestCrop.rice ? 'Rice' : 'Corn');
  }

  final TextEditingController _deductionPercentController =
      TextEditingController();
  final TextEditingController _productionCostsController =
      TextEditingController();

  late HarvestCrop _selectedCrop;
  late final List<TextEditingController> _controllers;

  NumberFormat get _currency =>
      Provider.of<AppSettingsProvider?>(context, listen: false)
          ?.currencyFormat ??
      NumberFormat.currency(locale: 'en_PH', symbol: '\u20B1');

  String get _currencySymbol =>
      Provider.of<AppSettingsProvider?>(context, listen: false)
          ?.currencySymbol ??
      '\u20B1';

  @override
  void initState() {
    super.initState();
    _selectedCrop = widget.initialCrop;
    _controllers = [
      _yieldKgController,
      _kgPerBagController,
      _pricePerKgController,
      _deductionPercentController,
      _productionCostsController,
    ];
    for (final controller in _controllers) {
      controller.addListener(_handleInputChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_handleInputChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearAll() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _kgPerBagController.text = '50';
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  double _parseNumber(String input) =>
      double.tryParse(input.replaceAll(',', '').trim()) ?? 0;

  _HarvestBreakdown get _breakdown {
    final yieldKg = _parseNumber(_yieldKgController.text);
    final kgPerBag = _parseNumber(_kgPerBagController.text);
    final pricePerKg = _parseNumber(_pricePerKgController.text);
    final deductionPercent = _parseNumber(_deductionPercentController.text)
        .clamp(0.0, 100.0)
        .toDouble();
    final productionCosts = _parseNumber(_productionCostsController.text);
    final payableYieldKg = yieldKg * (1 - (deductionPercent / 100));
    final totalRevenue = payableYieldKg * pricePerKg;
    final estimatedBags = kgPerBag > 0 ? yieldKg / kgPerBag : 0.0;

    return _HarvestBreakdown(
      yieldKg: yieldKg,
      estimatedBags: estimatedBags,
      payableYieldKg: payableYieldKg,
      totalRevenue: totalRevenue,
      productionCosts: productionCosts,
      netProfit: totalRevenue - productionCosts,
      deductionPercent: deductionPercent,
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AppSettingsProvider?>(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final breakdown = _breakdown;
    final isLoss = breakdown.netProfit < 0;

    return Scaffold(
      backgroundColor: _screenBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.16),
              scheme.secondary.withValues(alpha: 0.08),
              _screenBackground,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 18),
                _buildHeroCard(theme, breakdown, isLoss),
                const SizedBox(height: 16),
                _buildMetricsGrid(theme, breakdown),
                const SizedBox(height: 18),
                _buildInputPanel(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final scheme = theme.colorScheme;
    final compactHeader = MediaQuery.sizeOf(context).width < 430;
    final backButton = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pop(),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_cropLabel(_selectedCrop).toUpperCase()} TRIAL HARVEST ESTIMATE',
          style: theme.textTheme.bodySmall?.copyWith(
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Harvest Profit Simulator',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
    final cropBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppVisuals.textForest.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppVisuals.textForest.withValues(alpha: 0.12),
        ),
      ),
      child: Icon(_selectedCrop.icon, color: scheme.onSurface),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compactHeader) ...[
          Row(
            children: [
              backButton,
              const Spacer(),
              cropBadge,
            ],
          ),
          const SizedBox(height: 14),
          titleBlock,
        ] else
          Row(
            children: [
              backButton,
              const SizedBox(width: 14),
              Expanded(child: titleBlock),
              const SizedBox(width: 12),
              cropBadge,
            ],
          ),
        const SizedBox(height: 14),
        Text(
          'Select crop for trial simulation',
          style: theme.textTheme.bodySmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              key: const ValueKey('harvestProfitCalculator.crop.sugarcane'),
              label: Text(context.tr('Sugarcane')),
              selected: false,
              onSelected: (_) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            ChoiceChip(
              key: const ValueKey('harvestProfitCalculator.crop.rice'),
              label: Text(context.tr('Rice')),
              selected: _selectedCrop == HarvestCrop.rice,
              onSelected: (_) => setState(() {
                _selectedCrop = HarvestCrop.rice;
              }),
            ),
            ChoiceChip(
              key: const ValueKey('harvestProfitCalculator.crop.corn'),
              label: Text(context.tr('Corn')),
              selected: _selectedCrop == HarvestCrop.corn,
              onSelected: (_) => setState(() {
                _selectedCrop = HarvestCrop.corn;
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    ThemeData theme,
    _HarvestBreakdown breakdown,
    bool isLoss,
  ) {
    final scheme = theme.colorScheme;
    final heroTextColor = isLoss ? scheme.onErrorContainer : scheme.onPrimary;
    final gradientColors = isLoss
        ? [
            scheme.error.withValues(alpha: 0.92),
            scheme.errorContainer.withValues(alpha: 0.95),
            scheme.surfaceContainerHighest.withValues(alpha: 0.98),
          ]
        : [
            scheme.secondary.withValues(alpha: 0.94),
            scheme.primary.withValues(alpha: 0.92),
            scheme.surfaceContainerHighest.withValues(alpha: 0.98),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppVisuals.textForest.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppVisuals.textForest.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isLoss
                  ? 'Cost-heavy trial scenario'
                  : 'Per-harvest trial estimate',
              style: theme.textTheme.labelMedium?.copyWith(
                color: heroTextColor.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${_cropLabel(_selectedCrop)} Net Profit',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: heroTextColor.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currency.format(breakdown.netProfit),
            key: const ValueKey('harvestProfitCalculator.netProfit'),
            style: theme.textTheme.displayLarge?.copyWith(
              color: heroTextColor,
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            breakdown.deductionPercent > 0
                ? 'Revenue already reflects a ${breakdown.deductionPercent.toStringAsFixed(1)}% deduction.'
                : 'Revenue uses the full harvest yield with no deductions applied. Use the Harvest Board for official farm recording.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: heroTextColor.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme, _HarvestBreakdown breakdown) {
    final metrics = [
      _MetricCardData(
        keyName: 'harvestProfitCalculator.estimatedBags',
        label: 'Estimated Bags',
        value: breakdown.estimatedBags.toStringAsFixed(1),
        suffix: 'bags',
        icon: Icons.inventory_2_rounded,
      ),
      _MetricCardData(
        keyName: 'harvestProfitCalculator.payableYield',
        label: 'Payable Yield',
        value: breakdown.payableYieldKg.toStringAsFixed(2),
        suffix: 'kg',
        icon: Icons.scale_rounded,
      ),
      _MetricCardData(
        keyName: 'harvestProfitCalculator.totalRevenue',
        label: 'Total Revenue',
        value: _currency.format(breakdown.totalRevenue),
        icon: Icons.payments_rounded,
      ),
      _MetricCardData(
        keyName: 'harvestProfitCalculator.productionCosts',
        label: 'Production Costs',
        value: _currency.format(breakdown.productionCosts),
        icon: Icons.receipt_long_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final columns = constraints.maxWidth >= 820 ? 4 : 2;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map((metric) => SizedBox(
                    width: cardWidth,
                    child: _buildMetricCard(theme, metric),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(ThemeData theme, _MetricCardData metric) {
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            metric.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.suffix == null
                ? metric.value
                : '${metric.value} ${metric.suffix}',
            key: ValueKey(metric.keyName),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel(ThemeData theme) {
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surface.withValues(alpha: 0.98),
            scheme.surfaceContainerHighest.withValues(alpha: 0.94),
            scheme.surface.withValues(alpha: 0.99),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_cropLabel(_selectedCrop)} harvest inputs',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the harvest yield, optional deduction rate, selling price, and total production costs.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 14.0;
              final columns = constraints.maxWidth >= 880 ? 2 : 1;
              final fieldWidth =
                  (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: _buildInputField(
                      theme: theme,
                      controller: _yieldKgController,
                      fieldKey: 'harvestProfitCalculator.yieldKg',
                      label: 'Yield',
                      hint: 'Example: 5000',
                      icon: Icons.scale_rounded,
                      suffixText: 'kg',
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _buildInputField(
                      theme: theme,
                      controller: _kgPerBagController,
                      fieldKey: 'harvestProfitCalculator.kgPerBag',
                      label: 'Weight per bag',
                      hint: 'Example: 50',
                      icon: Icons.inventory_2_rounded,
                      suffixText: 'kg',
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _buildInputField(
                      theme: theme,
                      controller: _pricePerKgController,
                      fieldKey: 'harvestProfitCalculator.pricePerKg',
                      label: 'Price per kg',
                      hint: 'Example: 18',
                      icon: Icons.payments_rounded,
                      prefixText: _currencySymbol,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _buildInputField(
                      theme: theme,
                      controller: _deductionPercentController,
                      fieldKey: 'harvestProfitCalculator.deductionPercent',
                      label: 'Deductions',
                      hint: 'Optional',
                      icon: Icons.percent_rounded,
                      suffixText: '%',
                    ),
                  ),
                  SizedBox(
                    width:
                        columns == 1 ? fieldWidth : (fieldWidth * 2) + spacing,
                    child: _buildInputField(
                      theme: theme,
                      controller: _productionCostsController,
                      fieldKey: 'harvestProfitCalculator.productionCosts',
                      label: 'Production costs',
                      hint: 'Example: 45000',
                      icon: Icons.request_quote_rounded,
                      prefixText: _currencySymbol,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppVisuals.textForest.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppVisuals.textForest.withValues(alpha: 0.10),
              ),
            ),
            child: Text(
              'Example: 5,000 kg harvest at ${_currencySymbol}18/kg with no deduction gives ${_currencySymbol}90,000 revenue. If costs are ${_currencySymbol}45,000, net profit is ${_currencySymbol}45,000 per harvest.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.76),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('harvestProfitCalculator.clearAll'),
            onPressed: _clearAll,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Clear all'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required ThemeData theme,
    required TextEditingController controller,
    required String fieldKey,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    String? suffixText,
  }) {
    final scheme = theme.colorScheme;

    return TextField(
      key: ValueKey(fieldKey),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_numberInputFormatter],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        filled: true,
        fillColor: scheme.surface,
        prefixIcon: Icon(icon, color: scheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.34),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.keyName,
    required this.label,
    required this.value,
    required this.icon,
    this.suffix,
  });

  final String keyName;
  final String label;
  final String value;
  final String? suffix;
  final IconData icon;
}

class _HarvestBreakdown {
  const _HarvestBreakdown({
    required this.yieldKg,
    required this.estimatedBags,
    required this.payableYieldKg,
    required this.totalRevenue,
    required this.productionCosts,
    required this.netProfit,
    required this.deductionPercent,
  });

  final double yieldKg;
  final double estimatedBags;
  final double payableYieldKg;
  final double totalRevenue;
  final double productionCosts;
  final double netProfit;
  final double deductionPercent;
}
