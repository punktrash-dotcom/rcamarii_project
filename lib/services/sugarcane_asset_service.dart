import 'dart:math' as math;

class SugarcaneAssetService {
  static const String root = 'lib/assets/sugarcane';
  static const String problemsRoot = '$root/problems';
  static const String scanDiseasesRoot = '$root/scan_deseases';

  static int monthForAge(int ageInDays) {
    final normalizedAge = math.max(0, ageInDays);
    return ((normalizedAge ~/ 30) + 1).clamp(1, 12);
  }

  static String monthFolder(int month) => '$root/month${month.clamp(1, 12)}';

  static String healthyAssetForMonth(int month) =>
      '${monthFolder(month)}/healthy.png';

  static String growthAssetForAge(int ageInDays) =>
      healthyAssetForMonth(monthForAge(ageInDays));

  static String nitrogenDeficiencyAssetForMonth(int month) =>
      '${monthFolder(month)}/nitrogen_deficiency${_monthSuffix(month)}.png';

  static String phosphorusDeficiencyAssetForMonth(int month) =>
      '${monthFolder(month)}/phosphorus_deficiency${_monthSuffix(month)}.png';

  static String pestDamageAssetForMonth(int month) =>
      '${monthFolder(month)}/pest_damage${_monthSuffix(month)}.png';

  static String deficiencyAssetForMonth({
    required int month,
    required String nutrientKey,
  }) {
    return switch (nutrientKey.trim().toLowerCase()) {
      'nitrogen' => nitrogenDeficiencyAssetForMonth(month),
      'phosphorus' => phosphorusDeficiencyAssetForMonth(month),
      'potassium' => problemAsset('potassium_deficiency'),
      _ => healthyAssetForMonth(month),
    };
  }

  static String problemAsset(String issueKey) =>
      '$problemsRoot/${issueKey.trim().toLowerCase()}.png';

  static String scanAsset(
    String issueKey, {
    int variant = 1,
  }) {
    final normalizedVariant = variant.clamp(1, 5);
    final normalizedKey = issueKey.trim().toLowerCase();

    final folder = switch (normalizedKey) {
      'flood_stress' || 'flooding' => 'flooding',
      _ => normalizedKey,
    };

    final filePrefix = switch (normalizedKey) {
      'flood_stress' || 'flooding' => 'flooding',
      _ => folder,
    };

    return '$scanDiseasesRoot/$folder/${filePrefix}_$normalizedVariant.png';
  }

  static List<String> scanAssets(String issueKey, {int variants = 5}) {
    return List<String>.generate(
      variants.clamp(1, 5),
      (index) => scanAsset(issueKey, variant: index + 1),
      growable: false,
    );
  }

  static String _monthSuffix(int month) =>
      month.clamp(1, 12).toString().padLeft(2, '0');
}
