import 'package:flutter/material.dart';

import '../themes/app_visuals.dart';

class BuscoReportViewerScreen extends StatefulWidget {
  const BuscoReportViewerScreen({super.key});

  @override
  State<BuscoReportViewerScreen> createState() =>
      _BuscoReportViewerScreenState();
}

class _BuscoReportViewerScreenState extends State<BuscoReportViewerScreen> {
  static const _background = AppVisuals.deepGreen;
  static const _surface = AppVisuals.surfaceGreen;
  static const _accent = AppVisuals.primaryGold;

  static const _reportAssetPath = 'lib/assets/images/report.png';
  static const _breakdownPages = <String>[
    'lib/assets/images/report1.png',
    'lib/assets/images/report2.png',
    'lib/assets/images/report3.png',
  ];

  void _openFullScreen(String assetPath, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenViewer(assetPath: assetPath, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: _background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: _surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'BUSCO REPORT ANALYSIS',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accent.withValues(alpha: 0.2), _background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildModernCard(
                  title: 'Official BUSCO Report',
                  subtitle: 'Tap to expand and zoom',
                  assetPath: _reportAssetPath,
                  onTap: () =>
                      _openFullScreen(_reportAssetPath, 'Actual Report'),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color:
                                AppVisuals.textForest.withValues(alpha: 0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'STEP-BY-STEP BREAKDOWN',
                        style: TextStyle(
                          color: _accent.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color:
                                AppVisuals.textForest.withValues(alpha: 0.1))),
                  ],
                ),
                const SizedBox(height: 24),
                ...List.generate(_breakdownPages.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildModernCard(
                      title: 'Analysis Page ${index + 1}',
                      subtitle: 'Breakdown and explanation',
                      assetPath: _breakdownPages[index],
                      onTap: () => _openFullScreen(
                        _breakdownPages[index],
                        'Analysis Page ${index + 1}',
                      ),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
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
                          fit: BoxFit.cover,
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
  final String assetPath;
  final String title;

  const _FullScreenViewer({required this.assetPath, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppVisuals.deepGreen,
      appBar: AppBar(
        backgroundColor: AppVisuals.cloudGlass,
        foregroundColor: AppVisuals.textForest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppVisuals.textForest),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppVisuals.textForest,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        child: Center(
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
