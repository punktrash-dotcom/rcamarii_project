import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/crop_inspector_scan_model.dart';
import 'crop_photo_assessment_service.dart';

class CropInspectorService {
  CropInspectorService._();

  static const String _sugarcaneModelAsset =
      'lib/assets/models/sugarcane_crop_inspector.tflite';
  static const String _sugarcaneLabelsAsset =
      'lib/assets/models/sugarcane_inspector_labels.json';

  static Future<Interpreter?>? _sugarcaneInterpreterFuture;
  static Future<Map<int, _InspectorLabelMetadata>>? _sugarcaneLabelsFuture;

  static Future<CropInspectorDiagnosis> diagnose({
    required String imagePath,
    required String cropType,
    required int ageInDays,
    String farmName = 'Unknown farm',
  }) async {
    final normalizedCrop = cropType.toLowerCase().trim();
    if (normalizedCrop.contains('sugar')) {
      final diagnosis = await _tryTfliteDiagnosis(
        imagePath: imagePath,
        cropType: cropType,
        ageInDays: ageInDays,
        farmName: farmName,
      );
      if (diagnosis != null) {
        return diagnosis;
      }
    }

    return _buildFallbackDiagnosis(
      imagePath: imagePath,
      cropType: cropType,
      ageInDays: ageInDays,
      farmName: farmName,
    );
  }

  static Future<CropInspectorDiagnosis?> _tryTfliteDiagnosis({
    required String imagePath,
    required String cropType,
    required int ageInDays,
    required String farmName,
  }) async {
    try {
      final interpreter = await _loadSugarcaneInterpreter();
      if (interpreter == null) {
        return null;
      }

      final labels = await _loadSugarcaneLabels();
      final inputTensor = interpreter.getInputTensors().first;
      final inputShape = inputTensor.shape;
      if (inputShape.length < 4) {
        return null;
      }

      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];
      final input = await _buildInputTensor(
        imagePath: imagePath,
        width: inputWidth,
        height: inputHeight,
      );

      final outputTensor = interpreter.getOutputTensors().first;
      final outputShape = outputTensor.shape;
      final outputClassCount =
          outputShape.isNotEmpty ? outputShape.last : labels.length;
      final output = [
        List<double>.filled(outputClassCount, 0),
      ];

      interpreter.run(input, output);
      final probabilities = output.first;
      if (probabilities.isEmpty) {
        return null;
      }

      final rankedPredictions = probabilities.asMap().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final predictions = rankedPredictions.take(3).map((entry) {
        final metadata =
            labels[entry.key] ?? _InspectorLabelMetadata.fallback(entry.key);
        return CropInspectorPrediction(
          key: metadata.key,
          title: metadata.title,
          category: metadata.category,
          score: entry.value.clamp(0.0, 1.0),
          summary: metadata.summary,
          recommendations: metadata.recommendations,
        );
      }).toList(growable: false);

      if (predictions.isEmpty) {
        return null;
      }

      final primary = predictions.first;
      final findings = <String>[
        'Top model match: ${primary.title}.',
        'Category: ${_categoryLabel(primary.category)}.',
        if (predictions.length > 1)
          'Next closest matches: ${predictions.skip(1).map((prediction) => prediction.title).join(', ')}.',
      ];

      final recommendations = <String>[
        ...primary.recommendations,
        'Confirm the image result against the actual field before treatment.',
      ];

      return CropInspectorDiagnosis(
        farmName: farmName,
        cropType: cropType,
        imagePath: imagePath,
        ageInDays: ageInDays,
        engine: CropInspectorEngine.tflite,
        primaryPrediction: primary,
        predictions: predictions,
        summary: primary.summary,
        confidence: primary.score,
        confidenceLabel: _confidenceLabel(primary.score),
        findings: findings,
        recommendations: recommendations.toSet().toList(growable: false),
        captureTips: const [
          'Take one full-stand photo and one close-up of the most affected leaves.',
          'Keep the crop in focus and avoid heavy backlighting.',
          'Capture the same problem from more than one angle before acting.',
        ],
        analyzedAt: DateTime.now(),
        engineDetail: 'On-device TensorFlow Lite model',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<CropInspectorDiagnosis> _buildFallbackDiagnosis({
    required String imagePath,
    required String cropType,
    required int ageInDays,
    required String farmName,
  }) async {
    final assessment = await CropPhotoAssessmentService.assessPhoto(
      imagePath: imagePath,
      cropType: cropType,
      ageInDays: ageInDays,
    );

    final topMatch = assessment.referenceMatches.isEmpty
        ? null
        : assessment.referenceMatches.first;
    final prediction = CropInspectorPrediction(
      key: (topMatch?.label ?? 'visual_screening')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), ''),
      title: topMatch?.label ?? 'Visual screening',
      category: topMatch?.category ?? 'visual',
      score: topMatch?.similarityScore ?? 0.42,
      summary: assessment.summary,
      recommendations: assessment.recommendations,
    );

    return CropInspectorDiagnosis(
      farmName: farmName,
      cropType: cropType,
      imagePath: imagePath,
      ageInDays: ageInDays,
      engine: CropInspectorEngine.heuristic,
      primaryPrediction: prediction,
      predictions: [
        prediction,
        ...assessment.referenceMatches.skip(1).take(2).map(
              (match) => CropInspectorPrediction(
                key: match.label
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                    .replaceAll(RegExp(r'^_+|_+$'), ''),
                title: match.label,
                category: match.category,
                score: match.similarityScore,
                summary: match.referenceNote,
                recommendations: assessment.recommendations,
              ),
            ),
      ],
      summary: assessment.summary,
      confidence: topMatch?.similarityScore ?? 0.42,
      confidenceLabel: assessment.confidenceLabel,
      findings: assessment.findings,
      recommendations: assessment.recommendations,
      captureTips: assessment.captureGuidance,
      analyzedAt: DateTime.now(),
      engineDetail: 'Local heuristic photo assessment fallback',
    );
  }

  static Future<List<List<List<List<double>>>>> _buildInputTensor({
    required String imagePath,
    required int width,
    required int height,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final sampled = await _decodeRgba(
      bytes,
      width: width,
      height: height,
    );

    return [
      List<List<List<double>>>.generate(height, (y) {
        return List<List<double>>.generate(width, (x) {
          final offset = ((y * width) + x) * 4;
          final r = sampled[offset] / 255.0;
          final g = sampled[offset + 1] / 255.0;
          final b = sampled[offset + 2] / 255.0;
          return [r, g, b];
        }, growable: false);
      }, growable: false),
    ];
  }

  static Future<Uint8List> _decodeRgba(
    Uint8List bytes, {
    required int width,
    required int height,
  }) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      throw StateError('Unable to decode image for crop inspector.');
    }
    return byteData.buffer.asUint8List();
  }

  static Future<Interpreter?> _loadSugarcaneInterpreter() {
    return _sugarcaneInterpreterFuture ??= () async {
      try {
        await rootBundle.load(_sugarcaneModelAsset);
        return Interpreter.fromAsset(_sugarcaneModelAsset);
      } catch (_) {
        return null;
      }
    }();
  }

  static Future<Map<int, _InspectorLabelMetadata>> _loadSugarcaneLabels() {
    return _sugarcaneLabelsFuture ??= () async {
      final source = await rootBundle.loadString(_sugarcaneLabelsAsset);
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      final labels = <int, _InspectorLabelMetadata>{};
      for (final entry in decoded.entries) {
        labels[int.tryParse(entry.key) ?? 0] = _InspectorLabelMetadata.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
      return labels;
    }();
  }

  static String _confidenceLabel(double score) {
    if (score >= 0.8) {
      return 'High';
    }
    if (score >= 0.6) {
      return 'Moderate';
    }
    return 'Low';
  }

  static String _categoryLabel(String category) {
    switch (category) {
      case 'deficiency':
        return 'Nutrient deficiency';
      case 'pest':
        return 'Pest pressure';
      case 'disease':
        return 'Disease risk';
      case 'weather':
        return 'Weather stress';
      case 'normal':
        return 'Normal crop';
      default:
        return 'Visual screening';
    }
  }
}

class _InspectorLabelMetadata {
  const _InspectorLabelMetadata({
    required this.key,
    required this.title,
    required this.category,
    required this.summary,
    required this.recommendations,
  });

  final String key;
  final String title;
  final String category;
  final String summary;
  final List<String> recommendations;

  factory _InspectorLabelMetadata.fromJson(Map<String, dynamic> json) {
    return _InspectorLabelMetadata(
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      recommendations: ((json['recommendations'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  factory _InspectorLabelMetadata.fallback(int index) {
    return _InspectorLabelMetadata(
      key: 'class_$index',
      title: 'Class $index',
      category: 'visual',
      summary: 'The model returned an unmapped class for this crop image.',
      recommendations: const [
        'Review the crop manually before treatment.',
      ],
    );
  }
}
