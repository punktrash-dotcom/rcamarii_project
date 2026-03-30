import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/farm_model.dart';
import '../models/ftracker_model.dart';
import '../models/schedule_alert_model.dart';
import '../models/supply_model.dart';
import '../providers/activity_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/ftracker_provider.dart';
import '../providers/guideline_language_provider.dart';
import '../providers/supplies_provider.dart';
import '../providers/weather_provider.dart';
import '../services/farm_operations_service.dart';
import '../services/farming_advice_service.dart';
import '../services/guideline_localization_service.dart';
import 'busco_report_viewer_screen.dart';
import '../themes/app_visuals.dart';

const String _kOfficialLogoAsset = 'lib/assets/images/logo2.png';
const Color _kSugarcaneChartColor = Color(0xFF4CAF50);
const Color _kRiceChartColor = Color(0xFFE6C76E);
const Color _kWaterChartColor = Color(0xFF42A5F5);
const Color _kRevenueChartColor = Color(0xFF2E6F40);
const Color _kExpenseChartColor = Color(0xFF90A4AE);
const List<String> _kWeeklyReportAssets = <String>[
  'lib/assets/reports/report.png',
  'lib/assets/reports/report1.png',
  'lib/assets/reports/report2.png',
  'lib/assets/reports/report3.png',
];

class FarmReportDashboardScreen extends StatefulWidget {
  const FarmReportDashboardScreen({super.key});

  @override
  State<FarmReportDashboardScreen> createState() =>
      _FarmReportDashboardScreenState();
}

class _FarmReportDashboardScreenState extends State<FarmReportDashboardScreen> {
  final DateFormat _dayLabel = DateFormat('MMM d');
  final DateFormat _monthLabel = DateFormat('MMM');
  final DateFormat _dateTimeLabel = DateFormat('MMM d, y h:mm a');
  final NumberFormat _currency = NumberFormat.currency(symbol: 'PHP ');
  final NumberFormat _tonsFormat = NumberFormat.decimalPattern();
  Future<pw.ThemeData>? _reportPdfThemeFuture;
  Future<pw.ImageProvider?>? _reportLogoFuture;
  int _weeklyReportPageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    final activityProvider =
        Provider.of<ActivityProvider>(context, listen: false);
    final suppliesProvider =
        Provider.of<SuppliesProvider>(context, listen: false);
    final deliveryProvider =
        Provider.of<DeliveryProvider>(context, listen: false);
    final trackerProvider =
        Provider.of<FtrackerProvider>(context, listen: false);
    final weatherProvider =
        Provider.of<WeatherProvider>(context, listen: false);

    await Future.wait([
      farmProvider.refreshFarms(),
      activityProvider.loadActivities(),
      suppliesProvider.loadSupplies(),
      deliveryProvider.loadDeliveries(),
      trackerProvider.loadFtrackerRecords(),
    ]);

    if (!mounted) return;

    final selectedFarm = farmProvider.selectedFarm ??
        (farmProvider.farms.isNotEmpty ? farmProvider.farms.first : null);
    if (selectedFarm != null && weatherProvider.weatherData == null) {
      await weatherProvider
          .getWeather('${selectedFarm.city}, ${selectedFarm.province}');
    }
  }

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

  Future<pw.ImageProvider?> _getReportLogo() {
    return _reportLogoFuture ??= _buildReportLogo();
  }

  Future<pw.ImageProvider?> _buildReportLogo() async {
    try {
      final bytes =
          (await rootBundle.load(_kOfficialLogoAsset)).buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  void _openWeeklyReportViewer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BuscoReportViewerScreen(initialPage: _weeklyReportPageIndex),
      ),
    );
  }

  void _goToWeeklyReportPage(int index) {
    if (index < 0 || index >= _kWeeklyReportAssets.length) {
      return;
    }
    setState(() => _weeklyReportPageIndex = index);
  }

  void _openWeeklyReportPrintPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FarmReportPrintPreviewScreen(
          title: 'Print Weekly Report',
          buildPdf: _buildWeeklyReportPdf,
          pdfFileName: 'absfi-weekly-report.pdf',
        ),
      ),
    );
  }

  void _openPrintPreview({
    required _FarmDashboardData reportData,
    required List<Farm> farms,
    required Farm? selectedFarm,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FarmReportPrintPreviewScreen(
          title: 'Print Report',
          buildPdf: (format) => _buildReportPdf(
            format: format,
            reportData: reportData,
            farms: farms,
            selectedFarm: selectedFarm,
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildReportPdf({
    required PdfPageFormat format,
    required _FarmDashboardData reportData,
    required List<Farm> farms,
    required Farm? selectedFarm,
  }) async {
    final pdfTheme = await _getReportPdfTheme();
    final logo = await _getReportLogo();
    final doc = pw.Document();
    final harvestLedger = farms
        .map((farm) => _HarvestLedgerEntry.fromFarm(farm))
        .toList()
      ..sort(
          (left, right) => left.daysToHarvest.compareTo(right.daysToHarvest));

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        theme: pdfTheme,
        build: (context) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 54,
                        height: 54,
                        margin: const pw.EdgeInsets.only(right: 12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RCAMARii Properties Management System',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Farm Operations Report',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Formal summary for field operations, crop timing, and harvest planning',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated ${_dateTimeLabel.format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Season: ${FarmOperationsService.seasonLabel(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Selected farm: ${selectedFarm?.name ?? 'None'}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: reportData.metrics
                  .map(
                    (metric) => _buildPdfSummaryCard(
                      metric.label,
                      metric.value,
                      metric.detail,
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 18),
            _buildPdfSectionTitle(
              'Selected Farm Profile',
              'Target harvest, stage, irrigation, and projected output',
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    selectedFarm?.name ?? 'No farm selected',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    selectedFarm == null
                        ? 'Select a farm in the app to focus the report on one field profile.'
                        : '${selectedFarm.type} | ${selectedFarm.area.toStringAsFixed(1)} ha | ${selectedFarm.city}, ${selectedFarm.province}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    selectedFarm == null
                        ? 'No target harvest is available.'
                        : 'Target harvest: ${_dayLabel.format(FarmOperationsService.expectedHarvestDate(selectedFarm))} | Growth stage: ${reportData.growthStageHeadline} | Irrigation status: ${reportData.irrigationHeadline} | Forecast yield: ${_tonsFormat.format(reportData.selectedProjectedYield)} tons',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            _buildPdfSectionTitle(
              'Operational Alerts',
              'Priority items for pests, disease pressure, fertilizer timing, and crop applications',
            ),
            ...reportData.dashboardAlerts.map(
              (alert) => _buildPdfBulletRow(alert.title, alert.message),
            ),
            if (reportData.scheduleAlerts.isNotEmpty) pw.SizedBox(height: 8),
            ...reportData.scheduleAlerts.map(
              (alert) => _buildPdfBulletRow(
                alert.title,
                '${alert.message} Window: day ${alert.startDay}-${alert.endDay}.',
              ),
            ),
            pw.SizedBox(height: 18),
            _buildPdfSectionTitle(
              'Production Outlook',
              'Six-month yield outlook and finance totals',
            ),
            pw.TableHelper.fromTextArray(
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headers: const [
                'Month',
                'Sugarcane Yield',
                'Rice Yield',
                'Revenue',
                'Expense',
              ],
              data: List.generate(reportData.yieldPoints.length, (index) {
                final yieldPoint = reportData.yieldPoints[index];
                final financePoint = reportData.financePoints[index];
                return [
                  _monthLabel.format(yieldPoint.month),
                  '${yieldPoint.sugarcane.toStringAsFixed(1)} t',
                  '${yieldPoint.rice.toStringAsFixed(1)} t',
                  _currency.format(financePoint.revenue),
                  _currency.format(financePoint.expense),
                ];
              }),
            ),
            pw.SizedBox(height: 18),
            _buildPdfSectionTitle(
              'Harvest Ledger',
              'Field-by-field timing for harvest scheduling and dispatch planning',
            ),
            pw.TableHelper.fromTextArray(
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              headerStyle: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              headers: const [
                'Field',
                'Crop',
                'Area',
                'Stage',
                'Age',
                'Target Harvest',
                'Forecast Yield',
              ],
              data: harvestLedger
                  .map(
                    (entry) => [
                      entry.name,
                      entry.cropLabel,
                      '${entry.area.toStringAsFixed(1)} ha',
                      entry.stage,
                      '${entry.ageInDays} d',
                      _dayLabel.format(entry.targetHarvest),
                      '${entry.projectedYield.toStringAsFixed(1)} t',
                    ],
                  )
                  .toList(),
            ),
          ];
        },
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _buildWeeklyReportPdf(PdfPageFormat format) async {
    final pdfTheme = await _getReportPdfTheme();
    final doc = pw.Document();
    final pages = await Future.wait(
      _kWeeklyReportAssets.map(_loadWeeklyReportImage),
    );

    for (var index = 0; index < pages.length; index++) {
      final image = pages[index];
      if (image == null) {
        continue;
      }

      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(24),
          theme: pdfTheme,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _weeklyReportPageTitle(index),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Page ${index + 1} of ${_kWeeklyReportAssets.length}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(
                    image,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return doc.save();
  }

  Future<pw.MemoryImage?> _loadWeeklyReportImage(String assetPath) async {
    try {
      final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _buildPdfSectionTitle(String title, String subtitle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryCard(String label, String value, String detail) {
    return pw.Container(
      width: 122,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            detail,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfBulletRow(String title, String detail) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 5,
            height: 5,
            margin: const pw.EdgeInsets.only(top: 5, right: 8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.green700,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$title: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(text: detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = mediaQuery.size.width >= 1100;
    final farmProvider = context.watch<FarmProvider>();
    final activityProvider = context.watch<ActivityProvider>();
    final suppliesProvider = context.watch<SuppliesProvider>();
    final deliveryProvider = context.watch<DeliveryProvider>();
    final trackerProvider = context.watch<FtrackerProvider>();
    final weatherProvider = context.watch<WeatherProvider>();
    final language =
        context.watch<GuidelineLanguageProvider>().selectedLanguage;

    final farms = farmProvider.farms;
    final selectedFarm =
        farmProvider.selectedFarm ?? (farms.isNotEmpty ? farms.first : null);
    final weather = weatherProvider.weatherData;
    final selectedAge = selectedFarm == null
        ? null
        : FarmOperationsService.cropAgeInDays(selectedFarm.date);
    final reportData = _FarmDashboardData.fromSources(
      farms: farms,
      selectedFarm: selectedFarm,
      selectedAge: selectedAge,
      activities: activityProvider.activities,
      supplies: suppliesProvider.items,
      trackerRecords: trackerProvider.records,
      weather: weather,
      deliveryCount: deliveryProvider.deliveries.length,
      language: language,
    );

    return Scaffold(
      body: AppBackdrop(
        isDark: isDark,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                _buildHeader(
                  theme: theme,
                  farmProvider: farmProvider,
                  farms: farms,
                  selectedFarm: selectedFarm,
                  reportData: reportData,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 220,
                              child: _buildSideRail(theme, reportData),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildContent(
                                theme: theme,
                                reportData: reportData,
                                selectedFarm: selectedFarm,
                                farms: farms,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildSectionChips(theme, reportData),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _buildContent(
                                theme: theme,
                                reportData: reportData,
                                selectedFarm: selectedFarm,
                                farms: farms,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required ThemeData theme,
    required FarmProvider farmProvider,
    required List<Farm> farms,
    required Farm? selectedFarm,
    required _FarmDashboardData reportData,
  }) {
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppVisuals.primaryGold.withValues(alpha: 0.24),
                    ),
                    boxShadow: AppVisuals.shadow3d(theme.colorScheme),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      _kOfficialLogoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppVisuals.fieldMist,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: AppVisuals.brandGreen,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPERATIONS REPORT',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppVisuals.primaryGold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFarm?.name ?? 'Farm Operations Dashboard',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: AppVisuals.textForest,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedFarm == null
                            ? 'Select a farm to reveal stage-based guidance, alerts, and harvest targets.'
                            : '${selectedFarm.city}, ${selectedFarm.province}  |  ${FarmOperationsService.seasonLabel(DateTime.now())}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppVisuals.textForestMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 520,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildHeaderActionButton(
                  theme: theme,
                  tooltip: 'Back',
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                _buildHeaderActionButton(
                  theme: theme,
                  tooltip: 'Print report',
                  icon: Icons.print_rounded,
                  onTap: () => _openPrintPreview(
                    reportData: reportData,
                    farms: farms,
                    selectedFarm: selectedFarm,
                  ),
                ),
                _buildHeaderActionButton(
                  theme: theme,
                  tooltip: 'Weekly report',
                  icon: Icons.photo_library_outlined,
                  onTap: _openWeeklyReportViewer,
                ),
                _buildFarmSelector(theme, farmProvider, farms, selectedFarm),
                _buildHeaderBadge(
                  theme: theme,
                  icon: Icons.calendar_month_rounded,
                  title: _dayLabel.format(DateTime.now()),
                  subtitle: FarmOperationsService.seasonLabel(DateTime.now()),
                ),
                _buildHeaderBadge(
                  theme: theme,
                  icon: Icons.notifications_active_outlined,
                  title: '${reportData.notificationCount}',
                  subtitle: 'alerts',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required ThemeData theme,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppVisuals.brandWhite.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.42),
            ),
          ),
          child: Icon(icon, color: AppVisuals.textForest, size: 20),
        ),
      ),
    );
  }

  Widget _buildFarmSelector(
    ThemeData theme,
    FarmProvider farmProvider,
    List<Farm> farms,
    Farm? selectedFarm,
  ) {
    return Container(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppVisuals.brandWhite.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFarm?.id,
          hint: const Text('Select farm'),
          isExpanded: true,
          borderRadius: BorderRadius.circular(18),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: farms
              .map(
                (farm) => DropdownMenuItem<String>(
                  value: farm.id,
                  child: Text(
                    farm.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppVisuals.textForest,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            final nextFarm = farms.cast<Farm?>().firstWhere(
                  (farm) => farm?.id == value,
                  orElse: () => null,
                );
            if (nextFarm == null) return;
            farmProvider.handleFarmSelection(nextFarm);
            Provider.of<WeatherProvider>(context, listen: false).getWeather(
              '${nextFarm.city}, ${nextFarm.province}',
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderBadge({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppVisuals.brandWhite.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppVisuals.fieldMist,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppVisuals.brandGreen, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppVisuals.textForest,
                ),
              ),
              Text(
                subtitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppVisuals.textForestMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSideRail(ThemeData theme, _FarmDashboardData reportData) {
    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modules',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'High-level reading for field operations, procurement, labor, and harvest timing.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          ...reportData.sections.map(
            (section) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: section.highlighted
                    ? AppVisuals.fieldMist
                    : AppVisuals.brandWhite.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: section.highlighted
                      ? AppVisuals.brandGreen.withValues(alpha: 0.28)
                      : theme.colorScheme.outline.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(section.icon,
                      size: 18,
                      color: section.highlighted
                          ? AppVisuals.brandGreen
                          : AppVisuals.textForestMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppVisuals.textForest,
                      ),
                    ),
                  ),
                  Text(
                    section.value,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppVisuals.primaryGold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChips(ThemeData theme, _FarmDashboardData reportData) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: reportData.sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final section = reportData.sections[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: section.highlighted
                  ? AppVisuals.fieldMist
                  : AppVisuals.brandWhite.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: section.highlighted
                    ? AppVisuals.brandGreen.withValues(alpha: 0.24)
                    : theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(section.icon,
                    size: 16,
                    color: section.highlighted
                        ? AppVisuals.brandGreen
                        : AppVisuals.textForestMuted),
                const SizedBox(width: 8),
                Text(
                  '${section.label} ${section.value}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required ThemeData theme,
    required _FarmDashboardData reportData,
    required Farm? selectedFarm,
    required List<Farm> farms,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroSummary(theme, reportData, selectedFarm),
          const SizedBox(height: 14),
          _buildMetrics(theme, reportData),
          const SizedBox(height: 14),
          _buildOpsMatrix(theme, reportData),
          const SizedBox(height: 14),
          _buildMiddleCards(theme, reportData, selectedFarm),
          const SizedBox(height: 14),
          _buildAlertsAndGuidance(theme, reportData, selectedFarm),
          const SizedBox(height: 14),
          _buildCharts(theme, reportData),
          const SizedBox(height: 14),
          _buildWeeklyReportPanel(theme),
          const SizedBox(height: 14),
          _buildHarvestLedger(theme, farms),
        ],
      ),
    );
  }

  Widget _buildHeroSummary(
    ThemeData theme,
    _FarmDashboardData reportData,
    Farm? selectedFarm,
  ) {
    final expectedHarvest = selectedFarm == null
        ? null
        : FarmOperationsService.expectedHarvestDate(selectedFarm);
    final harvestWindow = selectedFarm == null
        ? null
        : FarmOperationsService.harvestWindow(selectedFarm);
    final harvestWindowLabel = harvestWindow == null
        ? 'Target window unavailable'
        : '${_dayLabel.format(harvestWindow.start)} - ${_dayLabel.format(harvestWindow.end)}';

    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIELD INTELLIGENCE',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppVisuals.primaryGold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedFarm == null
                      ? 'Operational dashboard for farm, labor, inputs, and harvest timing.'
                      : 'Track ${selectedFarm.name} with a clean read on land use, stage pressure, crop inputs, and harvest readiness.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppVisuals.textForest,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  selectedFarm == null
                      ? 'Load a farm record to activate crop-stage alerts, irrigation guidance, and harvest forecasts.'
                      : 'Target harvest: ${_dayLabel.format(expectedHarvest!)}  |  Window: $harvestWindowLabel  |  Forecast yield: ${_tonsFormat.format(reportData.selectedProjectedYield)} tons',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 124,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppVisuals.glass(AppVisuals.brandWhite, alpha: 0.74),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppVisuals.brandGreen.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.track_changes_rounded,
                  color: AppVisuals.brandGreen,
                  size: 24,
                ),
                const SizedBox(height: 10),
                Text(
                  selectedFarm == null
                      ? '--'
                      : '${reportData.selectedDaysToHarvest}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppVisuals.textForest,
                    fontSize: 22,
                  ),
                ),
                Text(
                  selectedFarm == null ? 'days' : 'days to target',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(ThemeData theme, _FarmDashboardData reportData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxWidth < 820;
        final crossAxisCount = isTight ? 2 : 4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isTight ? 1.02 : 1.18,
          children: reportData.metrics
              .map((metric) => _MetricCard(theme: theme, metric: metric))
              .toList(),
        );
      },
    );
  }

  Widget _buildOpsMatrix(ThemeData theme, _FarmDashboardData reportData) {
    return FrostedPanel(
      radius: 28,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: reportData.sections
            .map(
              (section) => Container(
                width: 180,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppVisuals.brandWhite.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(section.icon, size: 18, color: AppVisuals.brandGreen),
                    const SizedBox(height: 10),
                    Text(
                      section.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppVisuals.textForestMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.detail,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppVisuals.textForest,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMiddleCards(
    ThemeData theme,
    _FarmDashboardData reportData,
    Farm? selectedFarm,
  ) {
    final cards = [
      _InfoPanelData(
        title: 'Weather',
        icon: Icons.wb_sunny_rounded,
        headline: reportData.weatherHeadline,
        detail: reportData.weatherDetail,
        accent: _kWaterChartColor,
        progress: reportData.irrigationNeed,
      ),
      _InfoPanelData(
        title: 'Growth Stage',
        icon: Icons.grass_rounded,
        headline: reportData.growthStageHeadline,
        detail: reportData.growthStageDetail,
        accent: _kSugarcaneChartColor,
        progress: reportData.harvestProgress,
      ),
      _InfoPanelData(
        title: 'Irrigation',
        icon: Icons.water_drop_rounded,
        headline: reportData.irrigationHeadline,
        detail: reportData.irrigationDetail,
        accent: _kWaterChartColor,
        progress: reportData.irrigationNeed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxWidth < 860;
        if (isTight) {
          return Column(
            children: [
              for (final card in cards) ...[
                _InfoPanelCard(theme: theme, data: card),
                if (card != cards.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: _InfoPanelCard(theme: theme, data: cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAlertsAndGuidance(
    ThemeData theme,
    _FarmDashboardData reportData,
    Farm? selectedFarm,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final alertsCard = _buildAlertsPanel(theme, reportData);
        final timelineCard =
            _buildGuidancePanel(theme, reportData, selectedFarm);

        if (stacked) {
          return Column(
            children: [
              alertsCard,
              const SizedBox(height: 12),
              timelineCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: alertsCard),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: timelineCard),
          ],
        );
      },
    );
  }

  Widget _buildAlertsPanel(ThemeData theme, _FarmDashboardData reportData) {
    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational Alerts',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Surface immediate pressure before field dispatch or procurement.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < reportData.dashboardAlerts.length; i++) ...[
            _DashboardAlertCard(
              theme: theme,
              alert: reportData.dashboardAlerts[i],
            ),
            if (i != reportData.dashboardAlerts.length - 1)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidancePanel(
    ThemeData theme,
    _FarmDashboardData reportData,
    Farm? selectedFarm,
  ) {
    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Field Applications',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedFarm == null
                ? 'Select a farm to reveal the next agronomy windows.'
                : 'Schedule visible windows for fertilizer, herbicide, pesticide, foliar, and harvest prep based on crop age.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (reportData.scheduleAlerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppVisuals.brandWhite.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'No active or near-term crop window is available yet.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (var i = 0; i < reportData.scheduleAlerts.length; i++) ...[
              _ScheduleAlertTile(
                theme: theme,
                alert: reportData.scheduleAlerts[i],
                ageInDays: reportData.selectedCropAge,
              ),
              if (i != reportData.scheduleAlerts.length - 1)
                const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildCharts(ThemeData theme, _FarmDashboardData reportData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final yieldCard = _ChartPanel(
          theme: theme,
          title: 'Yield Over Time',
          subtitle: 'Projected harvest tons over the next six months',
          legend: const [
            _LegendItemData('Sugarcane', _kSugarcaneChartColor),
            _LegendItemData('Rice', _kRiceChartColor),
          ],
          child: _YieldChart(
            theme: theme,
            points: reportData.yieldPoints,
            monthLabel: _monthLabel,
          ),
        );
        final financeCard = _ChartPanel(
          theme: theme,
          title: 'Revenue vs Expenses',
          subtitle: 'Actual ledger totals over the last six months',
          legend: const [
            _LegendItemData('Revenue', _kRevenueChartColor),
            _LegendItemData('Expense', _kExpenseChartColor),
          ],
          child: _FinanceChart(
            theme: theme,
            points: reportData.financePoints,
            monthLabel: _monthLabel,
            currency: _currency,
          ),
        );

        if (stacked) {
          return Column(
            children: [
              yieldCard,
              const SizedBox(height: 12),
              financeCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: yieldCard),
            const SizedBox(width: 12),
            Expanded(child: financeCard),
          ],
        );
      },
    );
  }

  Widget _buildHarvestLedger(ThemeData theme, List<Farm> farms) {
    final entries = farms
        .map((farm) => _HarvestLedgerEntry.fromFarm(farm))
        .toList()
      ..sort(
          (left, right) => left.daysToHarvest.compareTo(right.daysToHarvest));

    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harvest Ledger',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Every active field with crop age, stage, expected target harvest, and forecast output.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Text(
              'No farms available yet.',
              style: theme.textTheme.bodyMedium,
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              _HarvestLedgerTile(
                theme: theme,
                entry: entries[i],
                dateFormat: _dayLabel,
                tonsFormat: _tonsFormat,
              ),
              if (i != entries.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildWeeklyReportPanel(ThemeData theme) {
    final isFirstPage = _weeklyReportPageIndex == 0;
    final isLastPage =
        _weeklyReportPageIndex == _kWeeklyReportAssets.length - 1;

    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ABSFI Farmer\'s Weekly Report',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppVisuals.textForest,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Display the weekly report pages here and navigate from report.png into report1.png, report2.png, and report3.png.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _openWeeklyReportViewer,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppVisuals.primaryGold.withValues(alpha: 0.14),
                      foregroundColor: AppVisuals.textForest,
                    ),
                    icon: const Icon(Icons.fullscreen_rounded),
                    label: const Text('Open'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _openWeeklyReportPrintPreview,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppVisuals.brandWhite.withValues(alpha: 0.86),
                      foregroundColor: AppVisuals.textForest,
                    ),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _openWeeklyReportViewer,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppVisuals.glass(AppVisuals.cloudGlass, alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _weeklyReportPageTitle(_weeklyReportPageIndex),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppVisuals.textForest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Page ${_weeklyReportPageIndex + 1} of ${_kWeeklyReportAssets.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppVisuals.textForestMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.asset(
                        _kWeeklyReportAssets[_weeklyReportPageIndex],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isFirstPage
                      ? null
                      : () => _goToWeeklyReportPage(_weeklyReportPageIndex - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppVisuals.textForest,
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.28),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLastPage
                      ? null
                      : () => _goToWeeklyReportPage(_weeklyReportPageIndex + 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppVisuals.textForest,
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.28),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_kWeeklyReportAssets.length, (index) {
              final isActive = index == _weeklyReportPageIndex;
              return ChoiceChip(
                label: Text(index == 0 ? 'Cover' : 'Page $index'),
                selected: isActive,
                onSelected: (_) => _goToWeeklyReportPage(index),
                backgroundColor: AppVisuals.glass(
                  AppVisuals.cloudGlass,
                  alpha: 0.18,
                ),
                selectedColor: AppVisuals.primaryGold.withValues(alpha: 0.18),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: AppVisuals.textForest,
                ),
                side: BorderSide(
                  color: isActive
                      ? AppVisuals.primaryGold.withValues(alpha: 0.4)
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _weeklyReportPageTitle(int index) {
    return index == 0
        ? 'ABSFI Farmer\'s Weekly Report'
        : 'ABSFI Weekly Report Page $index';
  }
}

class _FarmDashboardData {
  _FarmDashboardData({
    required this.metrics,
    required this.sections,
    required this.dashboardAlerts,
    required this.scheduleAlerts,
    required this.yieldPoints,
    required this.financePoints,
    required this.notificationCount,
    required this.weatherHeadline,
    required this.weatherDetail,
    required this.growthStageHeadline,
    required this.growthStageDetail,
    required this.irrigationHeadline,
    required this.irrigationDetail,
    required this.irrigationNeed,
    required this.harvestProgress,
    required this.selectedProjectedYield,
    required this.selectedDaysToHarvest,
    required this.selectedCropAge,
  });

  final List<_MetricCardData> metrics;
  final List<_SectionItem> sections;
  final List<_DashboardAlertData> dashboardAlerts;
  final List<ScheduleAlert> scheduleAlerts;
  final List<_YieldChartPoint> yieldPoints;
  final List<_FinanceChartPoint> financePoints;
  final int notificationCount;
  final String weatherHeadline;
  final String weatherDetail;
  final String growthStageHeadline;
  final String growthStageDetail;
  final String irrigationHeadline;
  final String irrigationDetail;
  final double irrigationNeed;
  final double harvestProgress;
  final double selectedProjectedYield;
  final int selectedDaysToHarvest;
  final int? selectedCropAge;

  factory _FarmDashboardData.fromSources({
    required List<Farm> farms,
    required Farm? selectedFarm,
    required int? selectedAge,
    required List<dynamic> activities,
    required List<Supply> supplies,
    required List<Ftracker> trackerRecords,
    required Weather? weather,
    required int deliveryCount,
    required GuidelineLanguage language,
  }) {
    final totalArea =
        farms.fold<double>(0, (sum, farm) => sum + farm.area.clamp(0, 100000));
    final sugarcaneArea = farms
        .where((farm) => farm.type.toLowerCase().contains('sugar'))
        .fold<double>(0, (sum, farm) => sum + farm.area);
    final riceArea = farms
        .where((farm) =>
            farm.type.toLowerCase().contains('rice') ||
            farm.type.toLowerCase().contains('palay'))
        .fold<double>(0, (sum, farm) => sum + farm.area);

    final forecastArea = farms
        .where((farm) => FarmOperationsService.daysUntilHarvest(farm) <= 60)
        .fold<double>(0, (sum, farm) => sum + farm.area);
    final forecastCount = farms
        .where((farm) => FarmOperationsService.daysUntilHarvest(farm) <= 60)
        .length;

    final selectedProjectedYield = selectedFarm == null
        ? 0.0
        : FarmOperationsService.projectedYieldTons(selectedFarm);
    final selectedDaysToHarvest = selectedFarm == null
        ? 0
        : FarmOperationsService.daysUntilHarvest(selectedFarm);

    final selectedActivities = selectedFarm == null
        ? activities
        : activities
            .where((activity) => activity.farm == selectedFarm.name)
            .toList();
    final laborCost = selectedActivities.fold<double>(
      0,
      (sum, activity) => sum + ((activity.total as num?)?.toDouble() ?? 0.0),
    );

    final uniqueCrops = farms.map((farm) => farm.type).toSet().length;
    final fertilizerUnits = supplies
        .where((item) => _matchesSupplyKeyword(item, ['fert', 'urea', 'npk']))
        .fold<int>(0, (sum, item) => sum + item.quantity);
    final lowStockCount = supplies.where((item) => item.quantity <= 3).length;

    final irrigationNeed = selectedFarm == null || selectedAge == null
        ? 0.0
        : FarmOperationsService.irrigationNeed(
            selectedFarm.type,
            selectedAge,
            temperatureC: weather?.temp,
            humidity: weather?.humidity,
          );
    final growthStage = selectedFarm == null || selectedAge == null
        ? 'No farm selected'
        : FarmOperationsService.growthStage(selectedFarm.type, selectedAge);
    final weatherHeadline = weather == null
        ? 'Weather offline'
        : '${weather.temp.toStringAsFixed(0)} C and ${weather.description}';
    final weatherDetail = weather == null
        ? 'Connect weather data to read humidity and wind conditions before dispatch.'
        : 'Humidity ${weather.humidity}%  |  Wind ${(weather.windSpeed * 3.6).toStringAsFixed(1)} km/h  |  Cloud cover ${weather.cloudiness}%';
    final irrigationStatus = selectedFarm == null || selectedAge == null
        ? 'Select a farm'
        : FarmOperationsService.irrigationStatus(
            selectedFarm.type,
            selectedAge,
            temperatureC: weather?.temp,
            humidity: weather?.humidity,
          );
    final irrigationDetail = selectedFarm == null || selectedAge == null
        ? 'A selected crop is required before irrigation guidance can be scored.'
        : 'Current need is ${(irrigationNeed * 100).round()}%. Use weather and soil moisture to confirm the next pump or furrow cycle.';

    final combinedAlerts = selectedFarm == null || selectedAge == null
        ? <ScheduleAlert>[]
        : [
            ...FarmingAdviceService.getAdviceForCrop(
              selectedFarm.type,
              selectedAge,
            ),
            ...FarmOperationsService.inputAlertsForCrop(
              selectedFarm.type,
              selectedAge,
            ),
          ]
            .map((alert) =>
                GuidelineLocalizationService.translateAlert(alert, language))
            .fold<List<ScheduleAlert>>([], (list, alert) {
            final exists = list.any(
              (entry) =>
                  entry.title == alert.title &&
                  entry.startDay == alert.startDay &&
                  entry.endDay == alert.endDay,
            );
            if (!exists) {
              list.add(alert);
            }
            return list;
          })
      ..sort((left, right) {
        final leftDistance = _alertDistance(left, selectedAge ?? 0);
        final rightDistance = _alertDistance(right, selectedAge ?? 0);
        return leftDistance.compareTo(rightDistance);
      });

    final scheduleAlerts = combinedAlerts.take(4).toList();
    final dashboardAlerts = _buildDashboardAlerts(
      selectedFarm: selectedFarm,
      selectedAge: selectedAge,
      weather: weather,
      fertilizerUnits: fertilizerUnits,
      lowStockCount: lowStockCount,
    );

    return _FarmDashboardData(
      metrics: [
        _MetricCardData(
          label: 'Active Land',
          value: '${totalArea.toStringAsFixed(1)} ha',
          detail: '${farms.length} active fields',
          icon: Icons.landscape_rounded,
          accent: AppVisuals.brandGreen,
        ),
        _MetricCardData(
          label: 'Sugarcane Area',
          value: '${sugarcaneArea.toStringAsFixed(1)} ha',
          detail: 'Cane blocks under management',
          icon: Icons.grass_rounded,
          accent: _kSugarcaneChartColor,
        ),
        _MetricCardData(
          label: 'Rice Area',
          value: '${riceArea.toStringAsFixed(1)} ha',
          detail: 'Palay area in rotation',
          icon: Icons.rice_bowl_rounded,
          accent: _kRiceChartColor,
        ),
        _MetricCardData(
          label: 'Harvest Forecast',
          value: forecastCount == 0 ? 'Stable' : '$forecastCount due',
          detail: forecastCount == 0
              ? 'No field is inside the next 60-day window'
              : '${forecastArea.toStringAsFixed(1)} ha nearing harvest',
          icon: Icons.event_available_rounded,
          accent: AppVisuals.primaryGold,
        ),
      ],
      sections: [
        _SectionItem(
          label: 'Fields',
          value: farms.length.toString(),
          detail: '${totalArea.toStringAsFixed(1)} hectares tracked',
          icon: Icons.grid_view_rounded,
        ),
        _SectionItem(
          label: 'Crops',
          value: uniqueCrops.toString(),
          detail: farms.isEmpty
              ? 'No crop mix yet'
              : farms.map((farm) => farm.type).toSet().join(', '),
          icon: Icons.eco_rounded,
        ),
        _SectionItem(
          label: 'Labor',
          value: selectedActivities.length.toString(),
          detail: '${_currencyShort(laborCost)} labor logged',
          icon: Icons.groups_rounded,
        ),
        _SectionItem(
          label: 'Inventory',
          value: supplies.length.toString(),
          detail:
              '$lowStockCount low-stock items, $fertilizerUnits fertilizer units',
          icon: Icons.inventory_2_rounded,
        ),
        _SectionItem(
          label: 'Irrigation',
          value: '${(irrigationNeed * 100).round()}%',
          detail:
              selectedFarm == null ? 'Needs selected farm' : irrigationStatus,
          icon: Icons.water_rounded,
        ),
        _SectionItem(
          label: 'Reports',
          value: deliveryCount.toString(),
          detail: '${trackerRecords.length} ledger records linked',
          icon: Icons.assessment_rounded,
          highlighted: true,
        ),
      ],
      dashboardAlerts: dashboardAlerts,
      scheduleAlerts: scheduleAlerts,
      yieldPoints: _buildYieldPoints(farms),
      financePoints: _buildFinancePoints(trackerRecords),
      notificationCount: dashboardAlerts.length + scheduleAlerts.length,
      weatherHeadline: weatherHeadline,
      weatherDetail: weatherDetail,
      growthStageHeadline: growthStage,
      growthStageDetail: selectedFarm == null || selectedAge == null
          ? 'Choose a farm to activate growth-stage reporting.'
          : 'Crop age is $selectedAge days. Harvest progress is ${(FarmOperationsService.harvestProgress(selectedFarm.type, selectedAge) * 100).round()}% against the target timeline.',
      irrigationHeadline: irrigationStatus,
      irrigationDetail: irrigationDetail,
      irrigationNeed: irrigationNeed,
      harvestProgress: selectedFarm == null || selectedAge == null
          ? 0
          : FarmOperationsService.harvestProgress(
              selectedFarm.type, selectedAge),
      selectedProjectedYield: selectedProjectedYield,
      selectedDaysToHarvest: selectedDaysToHarvest,
      selectedCropAge: selectedAge,
    );
  }

  static bool _matchesSupplyKeyword(Supply item, List<String> keywords) {
    final haystack = '${item.name} ${item.description}'.toLowerCase();
    return keywords.any(haystack.contains);
  }

  static int _alertDistance(ScheduleAlert alert, int ageInDays) {
    if (ageInDays >= alert.startDay && ageInDays <= alert.endDay) {
      return 0;
    }
    if (ageInDays < alert.startDay) {
      return alert.startDay - ageInDays;
    }
    return ageInDays - alert.endDay + 60;
  }

  static String _currencyShort(double amount) {
    if (amount >= 1000000) {
      return 'PHP ${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return 'PHP ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return 'PHP ${amount.toStringAsFixed(0)}';
  }

  static List<_DashboardAlertData> _buildDashboardAlerts({
    required Farm? selectedFarm,
    required int? selectedAge,
    required Weather? weather,
    required int fertilizerUnits,
    required int lowStockCount,
  }) {
    final cropName = selectedFarm?.type ?? 'crop';
    final pestPressure = selectedFarm != null &&
        selectedAge != null &&
        ((cropName.toLowerCase().contains('sugar') &&
                selectedAge >= 90 &&
                selectedAge <= 240) ||
            (cropName.toLowerCase().contains('rice') &&
                selectedAge >= 20 &&
                selectedAge <= 60) ||
            (cropName.toLowerCase().contains('corn') &&
                selectedAge >= 16 &&
                selectedAge <= 45));
    final diseasePressure =
        weather != null && (weather.humidity >= 85 || weather.cloudiness >= 70);
    final lowFertilizer = fertilizerUnits <= 5 || lowStockCount >= 3;

    return [
      _DashboardAlertData(
        title: 'Pest infestation',
        message: pestPressure
            ? 'High scouting pressure on ${selectedFarm.name}. Inspect vulnerable blocks before the next application round.'
            : 'No strong pressure signal yet, but keep routine scouting active during canopy build-up.',
        tone: pestPressure ? 'Watch now' : 'Monitor',
        accent: const Color(0xFFD17B2E),
        icon: Icons.pest_control_rounded,
      ),
      _DashboardAlertData(
        title: 'Disease',
        message: diseasePressure
            ? 'Humidity and cloud cover are elevated. Tighten sanitation and check leaf and stalk symptoms before they spread.'
            : 'Disease pressure is moderate. Continue field sanitation and remove stressed material quickly.',
        tone: diseasePressure ? 'Weather risk' : 'Stable',
        accent: const Color(0xFF7C5A9B),
        icon: Icons.warning_amber_rounded,
      ),
      _DashboardAlertData(
        title: 'Low fertilizer',
        message: lowFertilizer
            ? 'Fertilizer stock looks thin for the current work window. Review procurement before the next feed cycle starts.'
            : 'Fertilizer stock is still serviceable, but keep purchase timing aligned with the next crop-stage window.',
        tone: lowFertilizer ? 'Procure soon' : 'Stock visible',
        accent: const Color(0xFF638040),
        icon: Icons.inventory_rounded,
      ),
    ];
  }

  static List<_YieldChartPoint> _buildYieldPoints(List<Farm> farms) {
    final now = DateTime.now();
    final baseMonth = DateTime(now.year, now.month);
    final months = List.generate(
      6,
      (index) => DateTime(baseMonth.year, baseMonth.month + index),
    );

    return months.map((month) {
      double sugarcane = 0;
      double rice = 0;
      for (final farm in farms) {
        final harvestDate = FarmOperationsService.expectedHarvestDate(farm);
        if (harvestDate.year == month.year &&
            harvestDate.month == month.month) {
          final projected = FarmOperationsService.projectedYieldTons(farm);
          final normalizedCrop = farm.type.toLowerCase();
          if (normalizedCrop.contains('sugar')) {
            sugarcane += projected;
          } else if (normalizedCrop.contains('rice') ||
              normalizedCrop.contains('palay')) {
            rice += projected;
          }
        }
      }

      return _YieldChartPoint(
        month: month,
        sugarcane: sugarcane,
        rice: rice,
      );
    }).toList();
  }

  static List<_FinanceChartPoint> _buildFinancePoints(List<Ftracker> records) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - 5 + index),
    );

    return months.map((month) {
      final monthlyRecords = records.where(
        (record) =>
            record.date.year == month.year && record.date.month == month.month,
      );

      var revenue = 0.0;
      var expense = 0.0;
      for (final record in monthlyRecords) {
        final type = record.type.toLowerCase();
        if (type.contains('revenue') || type.contains('income')) {
          revenue += record.amount;
        } else if (type.contains('expense')) {
          expense += record.amount;
        }
      }

      return _FinanceChartPoint(
        month: month,
        revenue: revenue,
        expense: expense,
      );
    }).toList();
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.theme,
    required this.metric,
  });

  final ThemeData theme;
  final _MetricCardData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppVisuals.brandWhite.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: metric.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: metric.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: metric.accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            metric.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            metric.value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppVisuals.textForest,
              fontSize: 22,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            metric.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InfoPanelCard extends StatelessWidget {
  const _InfoPanelCard({
    required this.theme,
    required this.data,
  });

  final ThemeData theme;
  final _InfoPanelData data;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                data.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppVisuals.textForest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.headline,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.progress.clamp(0.0, 1.0),
              minHeight: 8,
              color: data.accent,
              backgroundColor: data.accent.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardAlertCard extends StatelessWidget {
  const _DashboardAlertCard({
    required this.theme,
    required this.alert,
  });

  final ThemeData theme;
  final _DashboardAlertData alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppVisuals.brandWhite.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: alert.accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: alert.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(alert.icon, color: alert.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppVisuals.textForest,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: alert.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        alert.tone,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: alert.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleAlertTile extends StatelessWidget {
  const _ScheduleAlertTile({
    required this.theme,
    required this.alert,
    required this.ageInDays,
  });

  final ThemeData theme;
  final ScheduleAlert alert;
  final int? ageInDays;

  @override
  Widget build(BuildContext context) {
    final age = ageInDays ?? -1;
    final dueNow = age >= alert.startDay && age <= alert.endDay;
    final ahead = alert.startDay - age;
    final badge = dueNow
        ? 'Now'
        : ahead > 0
            ? 'In $ahead d'
            : 'Review';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppVisuals.brandWhite.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: alert.color.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: alert.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(alert.icon, color: alert.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppVisuals.textForest,
                        ),
                      ),
                    ),
                    Text(
                      badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: alert.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Window: day ${alert.startDay}-${alert.endDay}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.legend,
    required this.child,
  });

  final ThemeData theme;
  final String title;
  final String subtitle;
  final List<_LegendItemData> legend;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: legend
                .map(
                  (item) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppVisuals.textForest,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(height: 250, child: child),
        ],
      ),
    );
  }
}

class _YieldChart extends StatelessWidget {
  const _YieldChart({
    required this.theme,
    required this.points,
    required this.monthLabel,
  });

  final ThemeData theme;
  final List<_YieldChartPoint> points;
  final DateFormat monthLabel;

  @override
  Widget build(BuildContext context) {
    if (points.every((point) => point.sugarcane == 0 && point.rice == 0)) {
      return Center(
        child: Text(
          'No projected harvest hits the next six-month window yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppVisuals.textForestMuted,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final maxY = points.fold<double>(
      0,
      (currentMax, point) => math.max(
        currentMax,
        math.max(point.sugarcane, point.rice),
      ),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: math.max(10, maxY * 1.25),
        lineTouchData: const LineTouchData(
          enabled: false,
          handleBuiltInTouches: false,
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(5, maxY / 4),
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              reservedSize: 44,
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value.toInt().toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthLabel.format(points[index].month),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppVisuals.textForestMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: false,
            color: _kSugarcaneChartColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: _kSugarcaneChartColor,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(show: false),
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].sugarcane),
            ],
          ),
          LineChartBarData(
            isCurved: false,
            color: _kRiceChartColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: _kRiceChartColor,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(show: false),
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].rice),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceChart extends StatelessWidget {
  const _FinanceChart({
    required this.theme,
    required this.points,
    required this.monthLabel,
    required this.currency,
  });

  final ThemeData theme;
  final List<_FinanceChartPoint> points;
  final DateFormat monthLabel;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (points.every((point) => point.revenue == 0 && point.expense == 0)) {
      return Center(
        child: Text(
          'No ledger activity is available for the last six months.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppVisuals.textForestMuted,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final maxY = points.fold<double>(
      0,
      (currentMax, point) =>
          math.max(currentMax, math.max(point.revenue, point.expense)),
    );

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: math.max(1000, maxY * 1.25),
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: false,
          handleBuiltInTouches: false,
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(1000, maxY / 4),
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              reservedSize: 56,
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  currency.format(value).replaceAll('.00', ''),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthLabel.format(points[index].month),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppVisuals.textForestMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 6,
              barRods: [
                BarChartRodData(
                  toY: points[i].revenue,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                  color: _kRevenueChartColor,
                ),
                BarChartRodData(
                  toY: points[i].expense,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                  color: _kExpenseChartColor,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HarvestLedgerTile extends StatelessWidget {
  const _HarvestLedgerTile({
    required this.theme,
    required this.entry,
    required this.dateFormat,
    required this.tonsFormat,
  });

  final ThemeData theme;
  final _HarvestLedgerEntry entry;
  final DateFormat dateFormat;
  final NumberFormat tonsFormat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppVisuals.brandWhite.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppVisuals.brandGreen.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppVisuals.textForest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.cropLabel}  |  ${entry.stage}  |  ${entry.area.toStringAsFixed(1)} ha',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppVisuals.textForestMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.daysToHarvest} d',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppVisuals.primaryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: entry.progress.clamp(0.0, 1.0),
              minHeight: 8,
              color: AppVisuals.brandGreen,
              backgroundColor: AppVisuals.fieldMist,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Text(
                'Age ${entry.ageInDays} days',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppVisuals.textForestMuted,
                ),
              ),
              Text(
                'Target ${dateFormat.format(entry.targetHarvest)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppVisuals.textForestMuted,
                ),
              ),
              Text(
                'Window ${dateFormat.format(entry.window.start)}-${dateFormat.format(entry.window.end)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppVisuals.textForestMuted,
                ),
              ),
              Text(
                'Forecast ${tonsFormat.format(entry.projectedYield)} t',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppVisuals.textForestMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;
}

class _SectionItem {
  const _SectionItem({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final bool highlighted;
}

class _InfoPanelData {
  const _InfoPanelData({
    required this.title,
    required this.icon,
    required this.headline,
    required this.detail,
    required this.accent,
    required this.progress,
  });

  final String title;
  final IconData icon;
  final String headline;
  final String detail;
  final Color accent;
  final double progress;
}

class _DashboardAlertData {
  const _DashboardAlertData({
    required this.title,
    required this.message,
    required this.tone,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String message;
  final String tone;
  final Color accent;
  final IconData icon;
}

class _LegendItemData {
  const _LegendItemData(this.label, this.color);

  final String label;
  final Color color;
}

class _YieldChartPoint {
  const _YieldChartPoint({
    required this.month,
    required this.sugarcane,
    required this.rice,
  });

  final DateTime month;
  final double sugarcane;
  final double rice;
}

class _FinanceChartPoint {
  const _FinanceChartPoint({
    required this.month,
    required this.revenue,
    required this.expense,
  });

  final DateTime month;
  final double revenue;
  final double expense;
}

class _HarvestLedgerEntry {
  const _HarvestLedgerEntry({
    required this.name,
    required this.cropLabel,
    required this.area,
    required this.ageInDays,
    required this.stage,
    required this.targetHarvest,
    required this.window,
    required this.daysToHarvest,
    required this.progress,
    required this.projectedYield,
  });

  final String name;
  final String cropLabel;
  final double area;
  final int ageInDays;
  final String stage;
  final DateTime targetHarvest;
  final DateTimeRange window;
  final int daysToHarvest;
  final double progress;
  final double projectedYield;

  factory _HarvestLedgerEntry.fromFarm(Farm farm) {
    final ageInDays = FarmOperationsService.cropAgeInDays(farm.date);
    return _HarvestLedgerEntry(
      name: farm.name,
      cropLabel: farm.type,
      area: farm.area,
      ageInDays: ageInDays,
      stage: FarmOperationsService.growthStage(farm.type, ageInDays),
      targetHarvest: FarmOperationsService.expectedHarvestDate(farm),
      window: FarmOperationsService.harvestWindow(farm) ??
          DateTimeRange(start: farm.date, end: farm.date),
      daysToHarvest: FarmOperationsService.daysUntilHarvest(farm),
      progress: FarmOperationsService.harvestProgress(farm.type, ageInDays),
      projectedYield: FarmOperationsService.projectedYieldTons(farm),
    );
  }
}

class _FarmReportPrintPreviewScreen extends StatelessWidget {
  const _FarmReportPrintPreviewScreen({
    required this.title,
    required this.buildPdf,
    this.pdfFileName = 'rcamarii-farm-operations-report.pdf',
  });

  final String title;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;
  final String pdfFileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface.withValues(alpha: 0.74),
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
        canChangeOrientation: false,
        canChangePageFormat: true,
        pdfFileName: pdfFileName,
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
    );
  }
}
