import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfHandbookViewerScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const PdfHandbookViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
      ),
      body: PdfViewer.asset(
        assetPath,
        params: const PdfViewerParams(
          margin: 0,
          pageAnchor: PdfPageAnchor.all,
          pageAnchorEnd: PdfPageAnchor.all,
          calculateInitialZoom: _fitWholePage,
        ),
      ),
    );
  }

  static double _fitWholePage(
    PdfDocument document,
    PdfViewerController controller,
    double fitZoom,
    double coverZoom,
  ) {
    return fitZoom;
  }
}
