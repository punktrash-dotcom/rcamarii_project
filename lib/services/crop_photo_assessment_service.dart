import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'farming_advice_service.dart';
import 'rice_knowledge_service.dart';
import 'sugarcane_asset_service.dart';
import 'sugarcane_knowledge_service.dart';

class CropPhotoAssessment {
  const CropPhotoAssessment({
    required this.summary,
    required this.honestyNote,
    required this.confidenceLabel,
    required this.findings,
    required this.recommendations,
    required this.tips,
    required this.captureGuidance,
    required this.metrics,
    required this.referenceMatches,
  });

  final String summary;
  final String honestyNote;
  final String confidenceLabel;
  final List<String> findings;
  final List<String> recommendations;
  final List<String> tips;
  final List<String> captureGuidance;
  final CropPhotoMetrics metrics;
  final List<CropPhotoReferenceMatch> referenceMatches;
}

class CropPhotoMetrics {
  const CropPhotoMetrics({
    required this.brightness,
    required this.contrast,
    required this.greenRatio,
    required this.yellowRatio,
    required this.brownRatio,
    required this.darkRatio,
  });

  final double brightness;
  final double contrast;
  final double greenRatio;
  final double yellowRatio;
  final double brownRatio;
  final double darkRatio;
}

class CropPhotoReferenceMatch {
  const CropPhotoReferenceMatch({
    required this.label,
    required this.category,
    required this.assetPath,
    required this.similarityScore,
    required this.similarityLabel,
    required this.referenceNote,
  });

  final String label;
  final String category;
  final String assetPath;
  final double similarityScore;
  final String similarityLabel;
  final String referenceNote;
}

class CropPhotoAssessmentService {
  static final Map<String, Future<CropPhotoMetrics>> _referenceMetricCache =
      <String, Future<CropPhotoMetrics>>{};

  static Future<CropPhotoAssessment> assessPhoto({
    required String imagePath,
    required String cropType,
    required int ageInDays,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final sampledBytes = await _decodeSampledRgba(bytes);
    final metrics = _analyzePixels(sampledBytes);
    final normalizedCrop = cropType.toLowerCase().trim();
    final referenceMatches = await _buildReferenceMatches(
      cropType: normalizedCrop,
      metrics: metrics,
    );

    final findings = <String>[];
    final recommendations = <String>[];
    final captureGuidance = <String>[];

    var confidenceLabel = 'Low';
    final photoQualityLooksUsable = metrics.contrast >= 0.16 &&
        metrics.brightness >= 0.28 &&
        metrics.brightness <= 0.82 &&
        metrics.darkRatio < 0.45;
    final topMatch = referenceMatches.isEmpty ? null : referenceMatches.first;

    if (photoQualityLooksUsable &&
        topMatch != null &&
        topMatch.similarityScore >= 0.56) {
      confidenceLabel = 'Moderate';
    } else if (photoQualityLooksUsable) {
      confidenceLabel = 'Low to moderate';
    }

    if (metrics.brightness < 0.28) {
      findings.add(
        'The photo is quite dark, so leaf color and stress signals may be understated.',
      );
      captureGuidance.add(
        'Retake in daylight or angle the camera away from heavy shadow.',
      );
    }
    if (metrics.contrast < 0.12) {
      findings.add(
        'The image has low contrast, which usually means flat lighting, haze, or slight blur.',
      );
      captureGuidance.add(
        'Move closer to the crop and keep one section of leaves in clear focus.',
      );
    }
    if (metrics.greenRatio < 0.22) {
      findings.add(
        'Green plant coverage is limited in the frame, so the photo may include too much soil, sky, or background.',
      );
      captureGuidance.add(
        'Fill more of the frame with the crop canopy or the affected leaves.',
      );
    }

    final summary = _buildSummary(
      cropType: normalizedCrop,
      metrics: metrics,
      topMatch: topMatch,
    );

    if (topMatch != null) {
      findings.add(
        'Closest built-in reference: ${topMatch.label} (${topMatch.category}, ${topMatch.similarityLabel.toLowerCase()}).',
      );
      findings.add(topMatch.referenceNote);
      recommendations.addAll(_referenceRecommendations(topMatch));
    } else {
      findings.add(
        'No close built-in reference match was available for this crop photo, so the result falls back to general visual cues only.',
      );
    }

    if (metrics.darkRatio >= 0.4) {
      recommendations.add(
        'Take one full-canopy photo and one close-up leaf photo so dark background areas do not dominate the assessment.',
      );
    }

    recommendations.addAll(
      _cropSpecificRecommendations(normalizedCrop, ageInDays),
    );
    final tips = _cropSpecificTips(normalizedCrop, ageInDays);

    if (captureGuidance.isEmpty) {
      captureGuidance.add(
        'For a stronger read, take one photo of the whole stand and another close-up of the most affected leaves.',
      );
    }

    final honestyNote = _honestyNoteForCrop(
      cropType: normalizedCrop,
      topMatch: topMatch,
    );

    return CropPhotoAssessment(
      summary: summary,
      honestyNote: honestyNote,
      confidenceLabel: confidenceLabel,
      findings: findings.take(5).toList(),
      recommendations: recommendations.toSet().take(6).toList(),
      tips: tips.toSet().take(4).toList(),
      captureGuidance: captureGuidance.toSet().take(3).toList(),
      metrics: metrics,
      referenceMatches: referenceMatches.take(3).toList(),
    );
  }

  static String _buildSummary({
    required String cropType,
    required CropPhotoMetrics metrics,
    required CropPhotoReferenceMatch? topMatch,
  }) {
    final matchLead = topMatch == null
        ? ''
        : 'The photo looks closest to the built-in "${topMatch.label}" reference, but that is only a local visual comparison, not a confirmed diagnosis. ';

    if (topMatch != null && topMatch.category != 'growth') {
      return '$matchLead${_summaryForIssueCategory(topMatch.category)}';
    }

    if (metrics.yellowRatio >= 0.22) {
      return '${matchLead}Visible yellowing is present in the photo. That can be consistent with nutrient stress, ageing leaves, harsh light, or disease pressure, but the image alone cannot confirm which one.';
    }
    if (metrics.brownRatio >= 0.18) {
      return '${matchLead}The photo shows notable brown or dry-looking areas. That can reflect leaf burn, dead tissue, drying stress, lodged debris, or simply exposed soil in the frame.';
    }
    if (metrics.greenRatio >= 0.45 && metrics.yellowRatio < 0.16) {
      return '${matchLead}The canopy looks mostly green in this photo, which is a positive visual sign. It still does not rule out hidden nutrient imbalance, early disease, or root-zone problems.';
    }

    if (cropType.contains('sugar') && topMatch != null) {
      return '${matchLead}The crop looks visually closer to one of the local sugarcane reference images than to a clearly distressed case, but field inspection is still needed before treatment.';
    }

    return '${matchLead}The crop looks mixed rather than clearly healthy or clearly stressed in this photo. The image suggests the stand should be checked in person before making a strong correction.';
  }

  static String _summaryForIssueCategory(String category) {
    switch (category) {
      case 'deficiency':
        return 'The current visual pattern is closer to a nutrient-deficiency reference than to a normal growth reference. That still needs field confirmation before fertilizer is changed.';
      case 'pest':
        return 'The current visual pattern is closer to a pest-related reference than to a clean canopy reference. It should trigger field scouting, not immediate certainty.';
      case 'disease':
        return 'The current visual pattern is closer to a disease-related reference from the local library. That is only a visual flag and should be confirmed in person.';
      case 'weather':
        return 'The current visual pattern is closer to a weather-stress reference. That can still overlap with nutrient or pest symptoms in real field conditions.';
      case 'growth':
        return 'The current visual pattern is closer to a normal growth-stage reference than to the bundled issue examples. That is encouraging, but it is not a clean bill of health.';
      default:
        return 'The image shows broad visual cues, but not enough evidence for a firm diagnosis.';
    }
  }

  static String _honestyNoteForCrop({
    required String cropType,
    required CropPhotoReferenceMatch? topMatch,
  }) {
    if (cropType.contains('sugar')) {
      final matchText = topMatch == null
          ? 'No strong local reference match was found.'
          : 'The best local comparison was ${topMatch.label}.';
      return 'This assessment is limited to the sugarcane reference images bundled inside RCAMARii, plus broad color and photo-quality cues. $matchText It does not identify deficiency, pests, or disease with lab or expert certainty.';
    }

    return 'This assessment is limited to the image resources currently bundled inside RCAMARii for this crop, plus broad color and photo-quality cues. Because the local reference library for this crop is still small, the result is mostly a general visual screen, not a diagnosis.';
  }

  static List<String> _referenceRecommendations(CropPhotoReferenceMatch match) {
    switch (match.category) {
      case 'deficiency':
        return [
          'Check whether symptoms begin on older or younger leaves before adjusting fertilizer.',
          'Confirm with field pattern, soil condition, and recent fertilization records before making a corrective application.',
        ];
      case 'pest':
        return [
          'Inspect the underside of leaves, the stalk base, and nearby plants for visible pest activity before spraying.',
          'Compare affected plants against a clean section of the field to confirm whether the problem is spreading biologically.',
        ];
      case 'disease':
        return [
          'Inspect the stand for repeating disease pattern, affected stalk tissue, and localized spread before treating it as infection.',
          'If symptoms are severe or expanding, document several plants and consult an agronomist or local DA technician.',
        ];
      case 'weather':
        return [
          'Check recent rainfall, drainage, heat exposure, or lodging before assuming a nutrient or pest problem.',
          'Look for whether the stress is uniform across the field or only in low or exposed spots.',
        ];
      case 'growth':
        return [
          'Compare the crop against its actual age and uniformity across the stand before assuming the field is normal.',
          'Keep scouting because a growth-stage lookalike does not rule out hidden deficiency or early pest pressure.',
        ];
      default:
        return const <String>[];
    }
  }

  static Future<List<CropPhotoReferenceMatch>> _buildReferenceMatches({
    required String cropType,
    required CropPhotoMetrics metrics,
  }) async {
    final references = _referenceLibraryForCrop(cropType);
    if (references.isEmpty) {
      return const <CropPhotoReferenceMatch>[];
    }

    final matches = <CropPhotoReferenceMatch>[];
    for (final reference in references) {
      final referenceMetrics = await _referenceMetrics(reference.assetPath);
      final score = _similarityScore(metrics, referenceMetrics);
      matches.add(
        CropPhotoReferenceMatch(
          label: reference.label,
          category: reference.category,
          assetPath: reference.assetPath,
          similarityScore: score,
          similarityLabel: _similarityLabel(score),
          referenceNote: reference.note,
        ),
      );
    }

    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return matches;
  }

  static Future<CropPhotoMetrics> _referenceMetrics(String assetPath) {
    return _referenceMetricCache.putIfAbsent(assetPath, () async {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      final sampledBytes = await _decodeSampledRgba(bytes);
      return _analyzePixels(sampledBytes);
    });
  }

  static double _similarityScore(
    CropPhotoMetrics input,
    CropPhotoMetrics reference,
  ) {
    final distance = (input.brightness - reference.brightness).abs() * 0.75 +
        (input.contrast - reference.contrast).abs() * 0.6 +
        (input.greenRatio - reference.greenRatio).abs() * 1.5 +
        (input.yellowRatio - reference.yellowRatio).abs() * 1.55 +
        (input.brownRatio - reference.brownRatio).abs() * 1.45 +
        (input.darkRatio - reference.darkRatio).abs() * 0.75;

    return 1 / (1 + distance * 3.2);
  }

  static String _similarityLabel(double score) {
    if (score >= 0.72) {
      return 'Closer match';
    }
    if (score >= 0.56) {
      return 'Possible match';
    }
    return 'Weak match';
  }

  static List<_ReferenceLibraryEntry> _referenceLibraryForCrop(
      String cropType) {
    if (cropType.contains('sugar')) {
      return <_ReferenceLibraryEntry>[
        _scanReferenceEntry(
          label: 'Nitrogen deficiency',
          category: 'deficiency',
          issueKey: 'nitrogen_deficiency',
        ),
        _ReferenceLibraryEntry(
          label: 'Phosphorus deficiency',
          category: 'deficiency',
          assetPath: SugarcaneAssetService.problemAsset(
            'phosphorus_deficiency',
          ),
          note:
              'This comparison checks the bundled phosphorus deficiency reference from the reorganized sugarcane problem set.',
        ),
        _scanReferenceEntry(
          label: 'Potassium deficiency',
          category: 'deficiency',
          issueKey: 'potassium_deficiency',
        ),
        _scanReferenceEntry(
          label: 'Mosaic virus',
          category: 'disease',
          issueKey: 'mosaic_virus',
        ),
        _scanReferenceEntry(
          label: 'Red rot',
          category: 'disease',
          issueKey: 'red_rot',
        ),
        _scanReferenceEntry(
          label: 'Aphids',
          category: 'pest',
          issueKey: 'aphids',
        ),
        _ReferenceLibraryEntry(
          label: 'Shoot borer',
          category: 'pest',
          assetPath: SugarcaneAssetService.problemAsset('shoot_borer'),
          note:
              'This comparison uses the reorganized sugarcane problem reference for shoot borer.',
        ),
        _scanReferenceEntry(
          label: 'Stem borer',
          category: 'pest',
          issueKey: 'stem_borer',
        ),
        _scanReferenceEntry(
          label: 'Drought stress',
          category: 'weather',
          issueKey: 'drought',
        ),
        _ReferenceLibraryEntry(
          label: 'Excessive heat',
          category: 'weather',
          assetPath: SugarcaneAssetService.problemAsset('excessive_heat'),
          note:
              'This comparison uses the reorganized sugarcane problem reference for excessive heat.',
        ),
        _scanReferenceEntry(
          label: 'Flood stress',
          category: 'weather',
          issueKey: 'flooding',
        ),
        _ReferenceLibraryEntry(
          label: 'Strong wind lodging',
          category: 'weather',
          assetPath: SugarcaneAssetService.problemAsset(
            'strong_wind_lodging',
          ),
          note:
              'This comparison uses the reorganized sugarcane problem reference for strong wind lodging.',
        ),
        _growthReferenceEntry(1),
        _growthReferenceEntry(4),
        _growthReferenceEntry(8),
        _growthReferenceEntry(12),
      ];
    }

    return const <_ReferenceLibraryEntry>[];
  }

  static _ReferenceLibraryEntry _scanReferenceEntry({
    required String label,
    required String category,
    required String issueKey,
  }) {
    return _ReferenceLibraryEntry(
      label: label,
      category: category,
      assetPath: SugarcaneAssetService.scanAsset(issueKey),
      note:
          'This comparison uses the reorganized sugarcane scan reference image for $label.',
    );
  }

  static _ReferenceLibraryEntry _growthReferenceEntry(int month) {
    final monthLabel = month.toString().padLeft(2, '0');
    return _ReferenceLibraryEntry(
      label: 'Growth month $monthLabel',
      category: 'growth',
      assetPath: SugarcaneAssetService.healthyAssetForMonth(month),
      note:
          'This is one of the reorganized sugarcane healthy month references, not a stress reference.',
    );
  }

  static Future<Uint8List> _decodeSampledRgba(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 96,
      targetHeight: 96,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      throw StateError('Unable to decode image bytes for crop analysis.');
    }
    return byteData.buffer.asUint8List();
  }

  static CropPhotoMetrics _analyzePixels(Uint8List bytes) {
    var total = 0;
    var brightnessSum = 0.0;
    var brightnessSquaredSum = 0.0;
    var greenCount = 0;
    var yellowCount = 0;
    var brownCount = 0;
    var darkCount = 0;

    for (var i = 0; i < bytes.length; i += 4) {
      final r = bytes[i].toDouble();
      final g = bytes[i + 1].toDouble();
      final b = bytes[i + 2].toDouble();
      final alpha = bytes[i + 3];
      if (alpha == 0) {
        continue;
      }

      total++;
      final brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
      brightnessSum += brightness;
      brightnessSquaredSum += brightness * brightness;

      if (brightness < 0.22) {
        darkCount++;
      }
      if (g > r * 1.06 && g > b * 1.02 && g > 70) {
        greenCount++;
      }
      if (r > 110 && g > 95 && b < 150 && (r - g).abs() < 48) {
        yellowCount++;
      }
      if (r > 85 && g > 45 && b < 110 && r > g && g > b) {
        brownCount++;
      }
    }

    final safeTotal = math.max(total, 1);
    final meanBrightness = brightnessSum / safeTotal;
    final variance =
        (brightnessSquaredSum / safeTotal) - (meanBrightness * meanBrightness);
    final contrast = math.sqrt(math.max(variance, 0.0));

    return CropPhotoMetrics(
      brightness: meanBrightness,
      contrast: contrast,
      greenRatio: greenCount / safeTotal,
      yellowRatio: yellowCount / safeTotal,
      brownRatio: brownCount / safeTotal,
      darkRatio: darkCount / safeTotal,
    );
  }

  static List<String> _cropSpecificRecommendations(
    String cropType,
    int ageInDays,
  ) {
    final recommendations = FarmingAdviceService.getAdviceForCrop(
      cropType,
      ageInDays,
    );
    return recommendations.map((alert) => alert.message).toList();
  }

  static List<String> _cropSpecificTips(String cropType, int ageInDays) {
    if (cropType.contains('sugar')) {
      return [
        SugarcaneKnowledgeService.randomTip(),
        ...FarmingAdviceService.getAdviceForCrop(cropType, ageInDays).map(
          (alert) => alert.title,
        ),
      ];
    }
    if (cropType.contains('rice') || cropType.contains('palay')) {
      return [
        RiceKnowledgeService.randomTip(),
        ...FarmingAdviceService.getAdviceForCrop(cropType, ageInDays).map(
          (alert) => alert.title,
        ),
      ];
    }
    return FarmingAdviceService.getAdviceForCrop(cropType, ageInDays)
        .map((alert) => alert.message)
        .toList();
  }
}

class _ReferenceLibraryEntry {
  const _ReferenceLibraryEntry({
    required this.label,
    required this.category,
    required this.assetPath,
    required this.note,
  });

  final String label;
  final String category;
  final String assetPath;
  final String note;
}
