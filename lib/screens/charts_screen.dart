import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/ftracker_model.dart';
import '../providers/app_settings_provider.dart';
import '../providers/ftracker_provider.dart';
import '../themes/app_visuals.dart';
import '../themes/custom_themes.dart';
import '../utils/transaction_report_utils.dart';
import '../widgets/searchable_dropdown.dart';
import 'busco_report_viewer_screen.dart';
import 'scr_new_transaction.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  static const revenueColor = AppVisuals.chartRevenue;
  static const expenseColor = AppVisuals.chartExpense;
  static const netColor = AppVisuals.chartNet;
  static const categoryColors = AppVisuals.chartPalette;

  final DateFormat dateLabel = DateFormat('MMM d, y');
  final DateFormat dateTimeLabel = DateFormat('MMM d, y h:mm a');

  DateTimeRange? selectedRange;
  String selectedCategory = allCategoriesFilter;
  Future<pw.ThemeData>? _reportPdfThemeFuture;

  Future<pw.ThemeData> _getReportPdfTheme() {
    return _reportPdfThemeFuture ??= _buildReportPdfTheme();
  }

  Future<pw.ThemeData> _buildReportPdfTheme() async {
    final baseFont = pw.Font.ttf(
      await rootBundle.load('lib/assets/fonts/NotoSans-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('lib/assets/fonts/NotoSans-Bold.ttf'),
    );

    return pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<FtrackerProvider>(context, listen: false)
            .loadFtrackerRecords();
      }
    });
  }

  Future<void> selectDateRange() async {
    final now = DateTime.now();
    final initialRange = selectedRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      currentDate: now,
      helpText: 'Select report range',
    );

    if (picked != null && mounted) {
      setState(() {
        selectedRange = picked;
      });
    }
  }

  void clearFilters() {
    setState(() {
      selectedCategory = allCategoriesFilter;
      selectedRange = null;
    });
  }

  void openPrintPreview(
    TransactionReportSnapshot snapshot,
    NumberFormat currency,
  ) {
    if (snapshot.records.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No transactions available to print.')),
        );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReportPrintPreviewScreen(
          title: 'Report Preview',
          buildPdf: (format) => buildReportPdf(snapshot, format, currency),
        ),
      ),
    );
  }

  Future<Uint8List> buildReportPdf(
    TransactionReportSnapshot snapshot,
    PdfPageFormat format,
    NumberFormat currency,
  ) async {
    final pdfTheme = await _getReportPdfTheme();
    final doc = pw.Document();
    final selectedRangeLabel = selectedRange == null
        ? 'All dates'
        : '${dateLabel.format(selectedRange!.start)} - ${dateLabel.format(selectedRange!.end)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: format.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pdfTheme,
        build: (context) {
          return [
            pw.Text(
              'RCAMARii Transaction Report',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Generated ${dateTimeLabel.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Category filter: $selectedCategory    Date range: $selectedRangeLabel',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 16),
            pw.Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                buildPdfSummaryCard(
                  'Revenue',
                  currency.format(snapshot.totalRevenue),
                  PdfColors.green300,
                ),
                buildPdfSummaryCard(
                  'Expenses',
                  currency.format(snapshot.totalExpenses),
                  PdfColors.red300,
                ),
                buildPdfSummaryCard(
                  'Net',
                  currency.format(snapshot.netBalance),
                  snapshot.netBalance >= 0
                      ? PdfColors.cyan300
                      : PdfColors.red200,
                ),
                buildPdfSummaryCard(
                  'Transactions',
                  snapshot.transactionCount.toString(),
                  PdfColors.blue200,
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Category Summary',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headers: const [
                'Category',
                'Revenue',
                'Expenses',
                'Net',
                'Transactions',
              ],
              data: snapshot.categoryComparisons
                  .map(
                    (summary) => [
                      summary.category,
                      currency.format(summary.revenue),
                      currency.format(summary.expenses),
                      currency.format(summary.net),
                      summary.transactionCount.toString(),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Transactions',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              headers: const [
                'Date',
                'Type',
                'Category',
                'Name',
                'Amount',
                'Note',
              ],
              data: snapshot.records.map((record) {
                return [
                  dateLabel.format(record.date),
                  record.type,
                  record.category,
                  record.name,
                  currency.format(record.amount),
                  truncateText(record.note ?? '-', 48),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget buildPdfSummaryCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 170,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackerTheme = CustomThemes.tracker(Theme.of(context));
    return Theme(
      data: trackerTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final appSettings = Provider.of<AppSettingsProvider>(context);
          final currency = appSettings.currencyFormat;
          final currencySymbol = appSettings.currencySymbol;

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: scheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRANSACTION REPORTS',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Reports & Analytics',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Select date range',
                  onPressed: selectDateRange,
                  icon: Icon(Icons.date_range_rounded, color: scheme.onSurface),
                ),
                Consumer<FtrackerProvider>(
                  builder: (context, provider, _) {
                    final report = buildTransactionReport(
                      provider.records,
                      dateRange: selectedRange,
                      categoryFilter: selectedCategory,
                    );
                    return IconButton(
                      tooltip: 'Print report',
                      onPressed: report.records.isEmpty
                          ? null
                          : () => openPrintPreview(report, currency),
                      icon: Icon(Icons.print_rounded, color: scheme.secondary),
                    );
                  },
                ),
              ],
            ),
            body: Consumer<FtrackerProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.records.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categoryOptions = [
                  allCategoriesFilter,
                  ...provider.uniqueCategories,
                ];
                final effectiveCategory =
                    categoryOptions.contains(selectedCategory)
                        ? selectedCategory
                        : allCategoriesFilter;
                final report = buildTransactionReport(
                  provider.records,
                  dateRange: selectedRange,
                  categoryFilter: effectiveCategory,
                );

                if (provider.records.isEmpty) {
                  return buildEmptyState(context);
                }

                return RefreshIndicator(
                  onRefresh: provider.loadFtrackerRecords,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    children: [
                      buildHeaderCard(context, report),
                      const SizedBox(height: 16),
                      buildBuscoAnalysisCard(context),
                      const SizedBox(height: 16),
                      buildFilterBar(
                        context: context,
                        categoryOptions: categoryOptions,
                        effectiveCategory: effectiveCategory,
                      ),
                      const SizedBox(height: 16),
                      buildSummaryGrid(context, report, currency),
                      const SizedBox(height: 20),
                      buildTrendChartCard(
                        context,
                        report,
                        currency,
                        currencySymbol,
                      ),
                      const SizedBox(height: 16),
                      buildCategoryComparisonCard(
                        context,
                        report,
                        currency,
                        currencySymbol,
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 920;
                          final expenseCard = buildCategoryPieCard(
                            context,
                            title: 'Expense Breakdown',
                            subtitle: 'Where costs are concentrated',
                            entries: report.expenseCategories,
                            emptyLabel: 'No expense categories in this range.',
                            paletteStart: 0,
                            currency: currency,
                          );
                          final revenueCard = buildCategoryPieCard(
                            context,
                            title: 'Revenue Breakdown',
                            subtitle: 'Income sources across categories',
                            entries: report.revenueCategories,
                            emptyLabel: 'No revenue categories in this range.',
                            paletteStart: 2,
                            currency: currency,
                          );

                          if (!isWide) {
                            return Column(
                              children: [
                                expenseCard,
                                const SizedBox(height: 16),
                                revenueCard,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: expenseCard),
                              const SizedBox(width: 16),
                              Expanded(child: revenueCard),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      buildTransactionsCard(context, report, currency),
                    ],
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScrNewTransaction(),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Transaction'),
            ),
          );
        },
      ),
    );
  }

  Widget buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: reportCardDecoration(scheme),
              child: Column(
                children: [
                  Icon(Icons.insights_rounded,
                      size: 42, color: scheme.secondary.withValues(alpha: 0.9)),
                  const SizedBox(height: 14),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a revenue or expense entry to unlock charts, printable reports, and category comparisons.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScrNewTransaction(),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add transaction'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            buildBuscoAnalysisCard(context),
          ],
        ),
      ),
    );
  }

  Widget buildHeaderCard(
    BuildContext context,
    TransactionReportSnapshot report,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.22),
            scheme.secondary.withValues(alpha: 0.18),
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 14,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtered Report Window',
                  style: TextStyle(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review every ledger entry by date, type, category, revenue, and expenses, then print a clean transaction report.',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.82),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              buildHeaderStat(
                scheme: scheme,
                label: 'Visible entries',
                value: report.transactionCount.toString(),
                accent: scheme.secondary,
              ),
              buildHeaderStat(
                scheme: scheme,
                label: 'Report range',
                value: selectedRange == null ? 'All dates' : 'Custom',
                accent: scheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildBuscoAnalysisCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: reportCardDecoration(scheme).copyWith(
        gradient: LinearGradient(
          colors: [
            AppVisuals.surfaceGreen,
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BuscoReportViewerScreen(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppVisuals.chartNet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppVisuals.chartNet.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.assessment_rounded,
                    color: AppVisuals.chartNet,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BUSCO REPORT ANALYSIS',
                        style: TextStyle(
                          color: AppVisuals.chartNet,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View & explain actual BUSCO reports',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Walkthrough of planter shares and proceeds',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: scheme.onSurface.withValues(alpha: 0.38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeaderStat({
    required ColorScheme scheme,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFilterBar({
    required BuildContext context,
    required List<String> categoryOptions,
    required String effectiveCategory,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final rangeText = selectedRange == null
        ? 'All dates'
        : '${dateLabel.format(selectedRange!.start)} - ${dateLabel.format(selectedRange!.end)}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: reportCardDecoration(scheme),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: SearchableDropdownFormField<String>(
              initialValue: effectiveCategory,
              decoration: const InputDecoration(
                labelText: 'Category filter',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: categoryOptions
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(
                        category,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedCategory = value;
                });
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: selectDateRange,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(rangeText),
          ),
          TextButton.icon(
            onPressed: clearFilters,
            icon: const Icon(Icons.filter_alt_off_rounded),
            label: const Text('Reset filters'),
          ),
          Text(
            'Use the Farm category here for farm-related ledger entries.',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.64),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryGrid(
    BuildContext context,
    TransactionReportSnapshot report,
    NumberFormat currency,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      _SummaryTileData(
        label: 'Revenue',
        value: currency.format(report.totalRevenue),
        icon: Icons.trending_up_rounded,
        accent: revenueColor,
      ),
      _SummaryTileData(
        label: 'Expenses',
        value: currency.format(report.totalExpenses),
        icon: Icons.trending_down_rounded,
        accent: expenseColor,
      ),
      _SummaryTileData(
        label: 'Net Balance',
        value: currency.format(report.netBalance),
        icon: Icons.account_balance_wallet_rounded,
        accent: report.netBalance >= 0 ? netColor : expenseColor,
      ),
      _SummaryTileData(
        label: 'Transactions',
        value: report.transactionCount.toString(),
        icon: Icons.receipt_long_rounded,
        accent: scheme.secondary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 680
                ? 2
                : 1;
        final tileWidth =
            columns == 1 ? width : (width - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: tileWidth,
                  child: buildSummaryTile(context, item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget buildSummaryTile(BuildContext context, _SummaryTileData item) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: reportCardDecoration(scheme),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTrendChartCard(
    BuildContext context,
    TransactionReportSnapshot report,
    NumberFormat currency,
    String currencySymbol,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: reportCardDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeader(
            context,
            title: 'Revenue vs Expense Trend',
            subtitle: 'Time-series comparison across the filtered window',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 280,
            child: report.trendPoints.isEmpty
                ? buildNoChartData(
                    context,
                    'No trend data for the current filter.',
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              final point = report.trendPoints[spot.x.toInt()];
                              final seriesLabel =
                                  spot.barIndex == 0 ? 'Revenue' : 'Expenses';
                              return LineTooltipItem(
                                '${point.label}\n$seriesLabel ${currency.format(spot.y)}',
                                TextStyle(
                                  color:
                                      spot.bar.color ?? AppVisuals.textForest,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval:
                            safeAxisInterval(trendMaxY(report.trendPoints)),
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: scheme.onSurface.withValues(alpha: 0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 54,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  compactCurrency(value, currencySymbol),
                                  style: TextStyle(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.58),
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 ||
                                  index >= report.trendPoints.length) {
                                return const SizedBox.shrink();
                              }
                              if (!shouldShowAxisLabel(
                                  index, report.trendPoints.length)) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  report.trendPoints[index].label,
                                  style: TextStyle(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.64),
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        buildLineSeries(report.trendPoints, true),
                        buildLineSeries(report.trendPoints, false),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              buildLegendItem('Revenue', revenueColor, scheme: scheme),
              buildLegendItem('Expenses', expenseColor, scheme: scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCategoryComparisonCard(
    BuildContext context,
    TransactionReportSnapshot report,
    NumberFormat currency,
    String currencySymbol,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final categories = report.categoryComparisons.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: reportCardDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeader(
            context,
            title: 'Category Comparison',
            subtitle: 'Revenue and expense totals per category',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 300,
            child: categories.isEmpty
                ? buildNoChartData(context, 'No category data to compare.')
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: comparisonMaxY(categories),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval:
                            safeAxisInterval(comparisonMaxY(categories)),
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: scheme.onSurface.withValues(alpha: 0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final category = categories[group.x.toInt()];
                            final label =
                                rodIndex == 0 ? 'Revenue' : 'Expenses';
                            return BarTooltipItem(
                              '${category.category}\n$label ${currency.format(rod.toY)}',
                              TextStyle(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 54,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                compactCurrency(value, currencySymbol),
                                style: TextStyle(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.58),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= categories.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  truncateText(categories[index].category, 10),
                                  style: TextStyle(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.64),
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(categories.length, (index) {
                        final category = categories[index];
                        return BarChartGroupData(
                          x: index,
                          barsSpace: 6,
                          barRods: [
                            BarChartRodData(
                              toY: category.revenue,
                              color: revenueColor,
                              width: 14,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            BarChartRodData(
                              toY: category.expenses,
                              color: expenseColor,
                              width: 14,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              buildLegendItem('Revenue bars', revenueColor, scheme: scheme),
              buildLegendItem('Expense bars', expenseColor, scheme: scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCategoryPieCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<CategorySummary> entries,
    required String emptyLabel,
    required int paletteStart,
    required NumberFormat currency,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final visibleEntries = entries.take(6).toList();
    final total = visibleEntries.fold<double>(
      0.0,
      (sum, entry) => sum + entry.amount,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: reportCardDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeader(
            context,
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 260,
            child: visibleEntries.isEmpty || total <= 0
                ? buildNoChartData(context, emptyLabel)
                : PieChart(
                    PieChartData(
                      centerSpaceRadius: 52,
                      sectionsSpace: 3,
                      sections: List.generate(visibleEntries.length, (index) {
                        final entry = visibleEntries[index];
                        final color = categoryColors[
                            (paletteStart + index) % categoryColors.length];
                        final pct = entry.amount / total * 100;
                        return PieChartSectionData(
                          value: entry.amount,
                          color: color,
                          radius: 56,
                          title: '${pct.toStringAsFixed(0)}%',
                          titleStyle: TextStyle(
                            color: AppVisuals.textForest,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        );
                      }),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: List.generate(visibleEntries.length, (index) {
              final entry = visibleEntries[index];
              final color = categoryColors[
                  (paletteStart + index) % categoryColors.length];
              return buildLegendItem(
                '${entry.category} • ${currency.format(entry.amount)}',
                color,
                scheme: scheme,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget buildTransactionsCard(
    BuildContext context,
    TransactionReportSnapshot report,
    NumberFormat currency,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final rowsPerPage =
        report.records.length < 8 ? max(report.records.length, 1) : 8;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: reportCardDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: buildSectionHeader(
              context,
              title: 'Transaction Ledger',
              subtitle:
                  'Every filtered transaction by date, type, category, and value',
            ),
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(
              cardColor: Colors.transparent,
              dividerColor: scheme.onSurface.withValues(alpha: 0.08),
            ),
            child: PaginatedDataTable(
              header: Text(
                '${report.transactionCount} record${report.transactionCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: scheme.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              rowsPerPage: rowsPerPage,
              availableRowsPerPage: const [5, 8, 10, 20],
              columnSpacing: 18,
              horizontalMargin: 16,
              showFirstLastButtons: true,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Note')),
              ],
              source: _TransactionTableSource(
                records: report.records,
                currency: currency,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.68),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget buildNoChartData(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.64),
        ),
      ),
    );
  }

  Widget buildLegendItem(String label, Color color, {ColorScheme? scheme}) {
    final fg = scheme?.onSurface ?? AppVisuals.textForest;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: fg.withValues(alpha: 0.82), fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  LineChartBarData buildLineSeries(
    List<TrendPoint> points,
    bool revenue,
  ) {
    final color = revenue ? revenueColor : expenseColor;
    return LineChartBarData(
      isCurved: true,
      curveSmoothness: 0.22,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: points.length <= 12),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.12),
      ),
      spots: List.generate(points.length, (index) {
        final value = revenue ? points[index].revenue : points[index].expenses;
        return FlSpot(index.toDouble(), value);
      }),
    );
  }

  BoxDecoration reportCardDecoration(ColorScheme scheme) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        colors: [
          scheme.surface.withValues(alpha: 0.98),
          Color.alphaBlend(
            AppVisuals.brandBlue.withValues(alpha: 0.1),
            AppVisuals.surfaceInset,
          ),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
      boxShadow: [
        BoxShadow(
          color: scheme.primary.withValues(alpha: 0.08),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  bool shouldShowAxisLabel(int index, int length) {
    if (length <= 6) return true;
    final step = (length / 6).ceil();
    return index % step == 0 || index == length - 1;
  }

  double trendMaxY(List<TrendPoint> points) {
    final maxValue = points.fold<double>(
      0.0,
      (currentMax, point) =>
          max(currentMax, max(point.revenue, point.expenses)),
    );
    return maxValue <= 0 ? 1 : maxValue * 1.2;
  }

  double comparisonMaxY(List<CategoryComparison> categories) {
    final maxValue = categories.fold<double>(
      0.0,
      (currentMax, category) =>
          max(currentMax, max(category.revenue, category.expenses)),
    );
    return maxValue <= 0 ? 1 : maxValue * 1.2;
  }

  double safeAxisInterval(double maxValue) {
    if (maxValue <= 1) return 1;
    return maxValue / 4;
  }

  String compactCurrency(double value, String currencySymbol) {
    if (value >= 1000000) {
      return '$currencySymbol${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '$currencySymbol${(value / 1000).toStringAsFixed(0)}k';
    }
    return '$currencySymbol${value.toStringAsFixed(0)}';
  }

  String truncateText(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1)}…';
  }
}

class _SummaryTileData {
  const _SummaryTileData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
}

class _TransactionTableSource extends DataTableSource {
  _TransactionTableSource({
    required this.records,
    required this.currency,
  });

  final List<Ftracker> records;
  final NumberFormat currency;
  final DateFormat dateFormat = DateFormat('MMM d, y');

  @override
  DataRow? getRow(int index) {
    if (index >= records.length) return null;
    final record = records[index];
    final isExpense = isExpenseRecord(record);
    final accent = isExpense
        ? _ChartsScreenState.expenseColor
        : _ChartsScreenState.revenueColor;

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(dateFormat.format(record.date))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              record.type,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        DataCell(Text(record.category)),
        DataCell(
          SizedBox(
            width: 180,
            child: Text(
              record.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Text(
            currency.format(record.amount),
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              record.note ?? '-',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => records.length;

  @override
  int get selectedRowCount => 0;
}

class _ReportPrintPreviewScreen extends StatelessWidget {
  const _ReportPrintPreviewScreen({
    required this.title,
    required this.buildPdf,
  });

  final String title;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemes.tracker(Theme.of(context));
    final scheme = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: scheme.onSurface,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: PdfPreview(
          build: buildPdf,
          allowPrinting: true,
          allowSharing: true,
          canChangeOrientation: true,
          canChangePageFormat: true,
          pdfFileName: 'rcamarii-transaction-report.pdf',
          previewPageMargin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          scrollViewDecoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.74),
          ),
          pdfPreviewPageDecoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
