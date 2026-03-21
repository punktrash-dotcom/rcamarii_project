import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class HandbookViewerScreen extends StatefulWidget {
  final String title;
  final String assetPath;
  final String summary;
  final List<String> highlights;

  const HandbookViewerScreen({
    super.key,
    required this.title,
    required this.assetPath,
    required this.summary,
    required this.highlights,
  });

  @override
  State<HandbookViewerScreen> createState() => _HandbookViewerScreenState();
}

class _HandbookViewerScreenState extends State<HandbookViewerScreen> {
  Future<File>? _localFileFuture;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _localFileFuture = _copyAssetToTemp(widget.assetPath);
  }

  Future<File> _copyAssetToTemp(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final safeName = assetPath.split('/').last;
    final filePath = path.join(tempDir.path, safeName);
    final file = File(filePath);
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _openFile(File file) async {
    if (_isOpening) {
      return;
    }
    setState(() => _isOpening = true);

    try {
      final result = await OpenFilex.open(
        file.path,
        type:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      if (!mounted) {
        return;
      }
      if (result.type != ResultType.done) {
        final message = result.message.isNotEmpty
            ? result.message
            : 'No app found to open this handbook. Install Microsoft Word or Google Docs.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open this handbook. Please install Microsoft Word or Google Docs to view DOCX files.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: FutureBuilder<File>(
          future: _localFileFuture,
          builder: (context, snapshot) {
            final file = snapshot.data;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                ...widget.highlights.map(
                  (highlight) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(highlight)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  Text(
                    'Unable to prepare handbook file.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  )
                else if (file != null)
                  ElevatedButton.icon(
                    onPressed: _isOpening ? null : () => _openFile(file),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open handbook'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
