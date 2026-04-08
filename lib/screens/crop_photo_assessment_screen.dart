import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/crop_photo_assessment_service.dart';
import '../themes/app_visuals.dart';

class CropPhotoAssessmentScreen extends StatefulWidget {
  const CropPhotoAssessmentScreen({
    super.key,
    required this.farmName,
    required this.cropType,
    required this.ageInDays,
  });

  final String farmName;
  final String cropType;
  final int ageInDays;

  @override
  State<CropPhotoAssessmentScreen> createState() =>
      _CropPhotoAssessmentScreenState();
}

class _CropPhotoAssessmentScreenState extends State<CropPhotoAssessmentScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  CropPhotoAssessment? _assessment;
  bool _isAnalyzing = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _error = null;
    });

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2200,
      );
      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _assessment = null;
        _isAnalyzing = true;
      });

      final result = await CropPhotoAssessmentService.assessPhoto(
        imagePath: image.path,
        cropType: widget.cropType,
        ageInDays: widget.ageInDays,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _assessment = result;
        _isAnalyzing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAnalyzing = false;
        _error = 'Unable to analyze the selected crop photo right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.farmName} Photo Check'),
      ),
      body: AppBackdrop(
        isDark: theme.brightness == Brightness.dark,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FrostedPanel(
                  radius: 30,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actual Crop Photo Assessment',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppVisuals.primaryGold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a photo of the actual crop or choose one from the gallery. RCAMARii will compare it against the local crop reference images we already have and combine that with basic visual cues. The result is still limited to those built-in resources and is not a guaranteed pathology diagnosis.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppVisuals.textForestMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _isAnalyzing
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: const Text('Take picture'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isAnalyzing
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Choose photo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Crop: ${widget.cropType} • Live age: ${widget.ageInDays} days',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppVisuals.textForestMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 16),
                  FrostedPanel(
                    radius: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Photo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppVisuals.primaryGold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            height: 260,
                            color: Colors.black.withValues(alpha: 0.78),
                            padding: const EdgeInsets.all(14),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isAnalyzing) ...[
                  const SizedBox(height: 16),
                  const FrostedPanel(
                    radius: 28,
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Analyzing photo...'),
                          SizedBox(height: 12),
                          LinearProgressIndicator(minHeight: 3),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  FrostedPanel(
                    radius: 28,
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (_assessment != null) ...[
                  const SizedBox(height: 16),
                  _AssessmentSection(
                    title: 'Assessment',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _assessment!.summary,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppVisuals.textForest,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppVisuals.panelSoft.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _assessment!.honestyNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppVisuals.textForestMuted,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MetricPill(
                              label: 'Confidence',
                              value: _assessment!.confidenceLabel,
                            ),
                            _MetricPill(
                              label: 'Green',
                              value:
                                  '${(_assessment!.metrics.greenRatio * 100).round()}%',
                            ),
                            _MetricPill(
                              label: 'Yellow',
                              value:
                                  '${(_assessment!.metrics.yellowRatio * 100).round()}%',
                            ),
                            _MetricPill(
                              label: 'Brown',
                              value:
                                  '${(_assessment!.metrics.brownRatio * 100).round()}%',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AssessmentSection(
                    title: 'Findings',
                    child: _SimpleBulletList(items: _assessment!.findings),
                  ),
                  const SizedBox(height: 16),
                  _AssessmentSection(
                    title: 'Recommendations',
                    child:
                        _SimpleBulletList(items: _assessment!.recommendations),
                  ),
                  if (_assessment!.referenceMatches.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _AssessmentSection(
                      title: 'Closest Local References',
                      child: Column(
                        children: _assessment!.referenceMatches
                            .map(
                              (match) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ReferenceMatchCard(match: match),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _AssessmentSection(
                    title: 'Tips',
                    child: _SimpleBulletList(items: _assessment!.tips),
                  ),
                  const SizedBox(height: 16),
                  _AssessmentSection(
                    title: 'Better Photo Tips',
                    child:
                        _SimpleBulletList(items: _assessment!.captureGuidance),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssessmentSection extends StatelessWidget {
  const _AssessmentSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FrostedPanel(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppVisuals.primaryGold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SimpleBulletList extends StatelessWidget {
  const _SimpleBulletList({
    required this.items,
  });

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: AppVisuals.primaryGold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppVisuals.textForest,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppVisuals.primaryGold.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppVisuals.textForestMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppVisuals.textForest,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceMatchCard extends StatelessWidget {
  const _ReferenceMatchCard({
    required this.match,
  });

  final CropPhotoReferenceMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppVisuals.panelSoft.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppVisuals.primaryGold.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 84,
              height: 84,
              color: Colors.black.withValues(alpha: 0.78),
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                match.assetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppVisuals.textForest,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${match.category} • ${match.similarityLabel}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppVisuals.primaryGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  match.referenceNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppVisuals.textForestMuted,
                    height: 1.4,
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
