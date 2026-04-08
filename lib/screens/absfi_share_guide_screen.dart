import 'package:flutter/material.dart';

import '../themes/app_visuals.dart';

class AbsfiShareGuideScreen extends StatefulWidget {
  const AbsfiShareGuideScreen({super.key});

  @override
  State<AbsfiShareGuideScreen> createState() => _AbsfiShareGuideScreenState();
}

class _AbsfiShareGuideScreenState extends State<AbsfiShareGuideScreen> {
  static const _reportPages = <String>[
    'lib/assets/reports/report.png',
    'lib/assets/reports/report1.png',
    'lib/assets/reports/report2.png',
    'lib/assets/reports/report3.png',
  ];

  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _reportPages.length) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openImageViewer() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _AbsfiReportImageViewer(
          pages: _reportPages,
          initialPage: _pageIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ABSFI SHARE GUIDE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w900,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Farmer Share Reference',
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
                _buildInfoCard(theme),
                const SizedBox(height: 18),
                _buildFormulaCard(theme),
                const SizedBox(height: 18),
                _buildReportCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABSFI Farmer Share',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'For ABSFI members, the sharing basis is 66% for planters and 34% for mills.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ABSFI takes 1% from the planter share. That 1% is computed from the 66% planter share, not from 100% gross.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Because of that, the net planter share used in the calculator is 65.34%.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForest,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaCard(ThemeData theme) {
    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Computation',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 12),
          _FormulaRow(
            label: 'Planter share',
            value: '66.00%',
          ),
          _FormulaRow(
            label: 'ABSFI deduction',
            value: '1% of 66.00% = 0.66%',
          ),
          _FormulaRow(
            label: 'Net planter share',
            value: '66.00% - 0.66% = 65.34%',
            emphasize: true,
          ),
          const SizedBox(height: 12),
          Text(
            'App behavior: if the selected association is ABSFI, the planter share field is auto-filled to 65.34%.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(ThemeData theme) {
    final isFirstPage = _pageIndex == 0;
    final isLastPage = _pageIndex == _reportPages.length - 1;

    return FrostedPanel(
      radius: 30,
      padding: const EdgeInsets.all(22),
      color: theme.colorScheme.surface.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reference Report Pages',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppVisuals.textForest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use these report images as a presentation reference for the ABSFI share computation.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppVisuals.textForestMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap the page to open it full screen and use zoom controls.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppVisuals.textForestMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _openImageViewer,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _reportPages.length,
                    onPageChanged: (value) {
                      setState(() {
                        _pageIndex = value;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: AppVisuals.panelSoft.withValues(alpha: 0.28),
                            child: Image.asset(
                              _reportPages[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            right: 14,
                            top: 14,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.open_in_full_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _reportPages.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _pageIndex
                      ? AppVisuals.primaryGold
                      : AppVisuals.textForestMuted.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isFirstPage ? null : () => _goToPage(_pageIndex - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isLastPage ? null : () => _goToPage(_pageIndex + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbsfiReportImageViewer extends StatefulWidget {
  const _AbsfiReportImageViewer({
    required this.pages,
    required this.initialPage,
  });

  final List<String> pages;
  final int initialPage;

  @override
  State<_AbsfiReportImageViewer> createState() =>
      _AbsfiReportImageViewerState();
}

class _AbsfiReportImageViewerState extends State<_AbsfiReportImageViewer> {
  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  static const double _zoomStep = 0.5;

  late final PageController _pageController;
  late final List<TransformationController> _transformControllers;
  late final List<double> _scales;
  late int _pageIndex;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _transformControllers = List<TransformationController>.generate(
      widget.pages.length,
      (_) => TransformationController(),
    );
    _scales = List<double>.filled(widget.pages.length, _minScale);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setScale(double nextScale) {
    final clampedScale = nextScale.clamp(_minScale, _maxScale);
    _transformControllers[_pageIndex].value = Matrix4.identity()
      ..scaleByDouble(clampedScale, clampedScale, 1.0, 1.0);
    setState(() {
      _scales[_pageIndex] = clampedScale;
    });
  }

  void _zoomIn() {
    _setScale(_scales[_pageIndex] + _zoomStep);
  }

  void _zoomOut() {
    _setScale(_scales[_pageIndex] - _zoomStep);
  }

  void _resetZoom() {
    _setScale(_minScale);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppVisuals.glass(AppVisuals.cloudGlass, alpha: 0.74),
        foregroundColor: AppVisuals.textForest,
        elevation: 0,
        title: Text(
          'ABSFI Reference ${_pageIndex + 1}/${widget.pages.length}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppVisuals.textForest,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Zoom out',
            onPressed: _zoomOut,
            icon: const Icon(Icons.zoom_out_rounded),
          ),
          IconButton(
            tooltip: 'Reset zoom',
            onPressed: _resetZoom,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: _zoomIn,
            icon: const Icon(Icons.zoom_in_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.pages.length,
            onPageChanged: (value) {
              setState(() {
                _pageIndex = value;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                transformationController: _transformControllers[index],
                minScale: _minScale,
                maxScale: _maxScale,
                child: Center(
                  child: Image.asset(
                    widget.pages[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  'Zoom ${_scales[_pageIndex].toStringAsFixed(1)}x',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  const _FormulaRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForestMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppVisuals.textForest,
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
