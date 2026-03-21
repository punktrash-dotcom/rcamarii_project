import 'package:flutter/material.dart';

class BuscoReportViewerScreen extends StatefulWidget {
  const BuscoReportViewerScreen({super.key});

  @override
  State<BuscoReportViewerScreen> createState() => _BuscoReportViewerScreenState();
}

class _BuscoReportViewerScreenState extends State<BuscoReportViewerScreen> {
  static const _background = Color(0xFF07131B);
  static const _surface = Color(0xFF10202B);

  static const _reportAssetPath = 'lib/assets/images/report.png';
  static const _breakdownPages = <String>[
    'lib/assets/images/report1.png',
    'lib/assets/images/report2.png',
    'lib/assets/images/report3.png',
  ];

  bool _showBreakdown = false;
  final PageController _breakdownController = PageController();
  int _breakdownPageIndex = 0;

  @override
  void dispose() {
    _breakdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('BUSCO Report'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            _buildImageCard(
              context,
              assetPath: _reportAssetPath,
              label: 'Actual report',
            ),
            const SizedBox(height: 14),
            if (!_showBreakdown)
              _buildBreakdownPrompt(theme, scheme)
            else
              _buildBreakdownSection(theme, scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(
    BuildContext context, {
    required String assetPath,
    required String label,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.22),
                    scheme.secondary.withValues(alpha: 0.14),
                  ],
                ),
              ),
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownPrompt(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Want a breakdown and explanation?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This opens an annotated, page-by-page walkthrough so you can understand what each part of the report means.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showBreakdown = true;
                      _breakdownPageIndex = 0;
                    });
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Yes, show breakdown'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.done_rounded),
                  label: const Text('No, I’m done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Breakdown & explanation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Page ${_breakdownPageIndex + 1} of ${_breakdownPages.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: _breakdownController,
            itemCount: _breakdownPages.length,
            onPageChanged: (index) {
              setState(() => _breakdownPageIndex = index);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildImageCard(
                  context,
                  assetPath: _breakdownPages[index],
                  label: 'Page ${index + 1}',
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to Profit'),
        ),
      ],
    );
  }
}
