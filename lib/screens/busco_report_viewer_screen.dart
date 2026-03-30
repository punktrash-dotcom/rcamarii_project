import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../themes/app_visuals.dart';

class BuscoReportViewerScreen extends StatefulWidget {
  const BuscoReportViewerScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  State<BuscoReportViewerScreen> createState() =>
      _BuscoReportViewerScreenState();
}

class _BuscoReportViewerScreenState extends State<BuscoReportViewerScreen> {
  static const _background = AppVisuals.deepGreen;
  static const _surface = AppVisuals.surfaceGreen;
  static const _accent = AppVisuals.primaryGold;

  static const _reportPages = <String>[
    'lib/assets/reports/report.png',
    'lib/assets/reports/report1.png',
    'lib/assets/reports/report2.png',
    'lib/assets/reports/report3.png',
  ];

  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialPage.clamp(0, _reportPages.length - 1).toInt();
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenViewer(
          pages: _reportPages,
          initialPage: _pageIndex,
        ),
      ),
    );
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _reportPages.length) {
      return;
    }
    setState(() => _pageIndex = index);
  }

  void _openPrintPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WeeklyReportPrintPreviewScreen(
          buildPdf: _buildWeeklyReportPdf,
        ),
      ),
    );
  }

  Future<Uint8List> _buildWeeklyReportPdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final pages = await Future.wait(_reportPages.map(_loadReportImage));

    for (var index = 0; index < pages.length; index++) {
      final image = pages[index];
      if (image == null) {
        continue;
      }

      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                index == 0
                    ? 'ABSFI Farmer\'s Weekly Report'
                    : 'ABSFI Weekly Report Page $index',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Page ${index + 1} of ${_reportPages.length}',
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

  Future<pw.MemoryImage?> _loadReportImage(String assetPath) async {
    try {
      final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFirstPage = _pageIndex == 0;
    final isLastPage = _pageIndex == _reportPages.length - 1;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: scheme.onSurface,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ABSFI Farmer\'s Weekly Report',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Page ${_pageIndex + 1} of ${_reportPages.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _openFullScreen,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent.withValues(alpha: 0.14),
                          foregroundColor: AppVisuals.textForest,
                        ),
                        icon: const Icon(Icons.fullscreen_rounded),
                        label: const Text('Open'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openPrintPreview,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              AppVisuals.brandWhite.withValues(alpha: 0.9),
                          foregroundColor: AppVisuals.textForest,
                        ),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  children: [
                    Expanded(
                      child: _buildModernCard(
                        title: _pageTitle(_pageIndex),
                        subtitle: _pageSubtitle(_pageIndex),
                        assetPath: _reportPages[_pageIndex],
                        onTap: _openFullScreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isFirstPage
                                ? null
                                : () => _goToPage(_pageIndex - 1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppVisuals.textForest,
                              side: BorderSide(
                                color: AppVisuals.brandWhite
                                    .withValues(alpha: 0.28),
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
                                : () => _goToPage(_pageIndex + 1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppVisuals.textForest,
                              side: BorderSide(
                                color: AppVisuals.brandWhite
                                    .withValues(alpha: 0.28),
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
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _reportPages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final isActive = index == _pageIndex;
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _goToPage(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 116,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppVisuals.glass(
                                  AppVisuals.cloudGlass,
                                  alpha: isActive ? 0.26 : 0.16,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isActive
                                      ? _accent.withValues(alpha: 0.42)
                                      : AppVisuals.brandWhite
                                          .withValues(alpha: 0.18),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  _reportPages[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pageTitle(int index) {
    return index == 0 ? 'Weekly report overview' : 'Weekly report page $index';
  }

  String _pageSubtitle(int index) {
    return index == 0
        ? 'ABSFI Farmer\'s Weekly Report front page'
        : 'Supporting weekly report image $index';
  }

  Widget _buildModernCard({
    required String title,
    required String subtitle,
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppVisuals.primaryGold.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: _accent.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppVisuals.textForest,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: AppVisuals.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          color: _accent,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
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
}

class _FullScreenViewer extends StatelessWidget {
  const _FullScreenViewer({
    required this.pages,
    required this.initialPage,
  });

  final List<String> pages;
  final int initialPage;

  @override
  Widget build(BuildContext context) {
    final controller = PageController(initialPage: initialPage);

    return Scaffold(
      backgroundColor: AppVisuals.deepGreen,
      appBar: AppBar(
        backgroundColor: AppVisuals.glass(AppVisuals.cloudGlass, alpha: 0.74),
        foregroundColor: AppVisuals.textForest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppVisuals.textForest),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: pages.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Center(
              child: Image.asset(
                pages[index],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeeklyReportPrintPreviewScreen extends StatelessWidget {
  const _WeeklyReportPrintPreviewScreen({
    required this.buildPdf,
  });

  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;

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
          'Print Weekly Report',
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
        pdfFileName: 'absfi-weekly-report.pdf',
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
