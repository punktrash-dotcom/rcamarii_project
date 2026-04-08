import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/farm_model.dart';
import '../models/schedule_alert_model.dart';
import 'sugarcane_asset_service.dart';

class CropTimelineProfile {
  const CropTimelineProfile({
    required this.key,
    required this.label,
    required this.minHarvestDays,
    required this.targetHarvestDays,
    required this.maxHarvestDays,
    required this.projectedYieldTonsPerHa,
    required this.waterDemandStartDay,
    required this.waterDemandEndDay,
    required this.stages,
  });

  final String key;
  final String label;
  final int minHarvestDays;
  final int targetHarvestDays;
  final int maxHarvestDays;
  final double projectedYieldTonsPerHa;
  final int waterDemandStartDay;
  final int waterDemandEndDay;
  final List<CropStageWindow> stages;
}

class CropStageWindow {
  const CropStageWindow({
    required this.startDay,
    required this.endDay,
    required this.label,
  });

  final int startDay;
  final int endDay;
  final String label;
}

class FarmOperationsService {
  static const CropTimelineProfile _riceProfile = CropTimelineProfile(
    key: 'rice',
    label: 'Rice',
    minHarvestDays: 95,
    targetHarvestDays: 110,
    maxHarvestDays: 125,
    projectedYieldTonsPerHa: 4.8,
    waterDemandStartDay: 8,
    waterDemandEndDay: 70,
    stages: [
      CropStageWindow(startDay: 0, endDay: 20, label: 'Seedling'),
      CropStageWindow(startDay: 21, endDay: 45, label: 'Tillering'),
      CropStageWindow(startDay: 46, endDay: 75, label: 'Panicle Initiation'),
      CropStageWindow(startDay: 76, endDay: 105, label: 'Grain Filling'),
      CropStageWindow(startDay: 106, endDay: 140, label: 'Harvest Window'),
    ],
  );

  static const CropTimelineProfile _cornProfile = CropTimelineProfile(
    key: 'corn',
    label: 'Corn',
    minHarvestDays: 90,
    targetHarvestDays: 105,
    maxHarvestDays: 120,
    projectedYieldTonsPerHa: 5.5,
    waterDemandStartDay: 10,
    waterDemandEndDay: 65,
    stages: [
      CropStageWindow(startDay: 0, endDay: 18, label: 'Emergence'),
      CropStageWindow(startDay: 19, endDay: 45, label: 'Vegetative'),
      CropStageWindow(startDay: 46, endDay: 70, label: 'Tasseling'),
      CropStageWindow(startDay: 71, endDay: 100, label: 'Grain Fill'),
      CropStageWindow(startDay: 101, endDay: 130, label: 'Harvest Window'),
    ],
  );

  static const CropTimelineProfile _sugarcaneProfile = CropTimelineProfile(
    key: 'sugarcane',
    label: 'Sugarcane',
    minHarvestDays: 300,
    targetHarvestDays: 360,
    maxHarvestDays: 420,
    projectedYieldTonsPerHa: 75,
    waterDemandStartDay: 25,
    waterDemandEndDay: 280,
    stages: [
      CropStageWindow(startDay: 0, endDay: 45, label: 'Establishment'),
      CropStageWindow(startDay: 46, endDay: 150, label: 'Tillering'),
      CropStageWindow(startDay: 151, endDay: 270, label: 'Grand Growth'),
      CropStageWindow(startDay: 271, endDay: 360, label: 'Ripening'),
      CropStageWindow(startDay: 361, endDay: 450, label: 'Harvest Window'),
    ],
  );

  static CropTimelineProfile? profileForCrop(String cropType) {
    final normalized = cropType.trim().toLowerCase();
    if (normalized.contains('sugar')) {
      return _sugarcaneProfile;
    }
    if (normalized.contains('rice') || normalized.contains('palay')) {
      return _riceProfile;
    }
    if (normalized.contains('corn') || normalized.contains('maize')) {
      return _cornProfile;
    }
    return null;
  }

  static int cropAgeInDays(DateTime plantingDate) {
    return math.max(0, DateTime.now().difference(plantingDate).inDays);
  }

  static int sugarcaneGrowthMonthForAge(int ageInDays) {
    return SugarcaneAssetService.monthForAge(ageInDays);
  }

  static String sugarcaneGrowthAssetForAge(int ageInDays) {
    return SugarcaneAssetService.growthAssetForAge(ageInDays);
  }

  static String cropBackdropAssetForAge(String cropType, int ageInDays) {
    final normalized = cropType.trim().toLowerCase();
    if (normalized.contains('sugar')) {
      return sugarcaneGrowthAssetForAge(ageInDays);
    }
    if (normalized.contains('rice') || normalized.contains('palay')) {
      return 'lib/assets/images/usda_rice.jpg';
    }
    if (normalized.contains('corn') || normalized.contains('maize')) {
      return 'lib/assets/images/usda_corn.jpg';
    }
    return 'lib/assets/images/usda_sugarcane.jpg';
  }

  static DateTime expectedHarvestDate(Farm farm) {
    final profile = profileForCrop(farm.type);
    if (profile == null) return farm.date;
    return farm.date.add(Duration(days: profile.targetHarvestDays));
  }

  static DateTimeRange? harvestWindow(Farm farm) {
    final profile = profileForCrop(farm.type);
    if (profile == null) return null;
    return DateTimeRange(
      start: farm.date.add(Duration(days: profile.minHarvestDays)),
      end: farm.date.add(Duration(days: profile.maxHarvestDays)),
    );
  }

  static bool isHarvestStatus(Farm farm, {DateTime? asOf}) {
    final profile = profileForCrop(farm.type);
    if (profile == null) {
      return false;
    }
    final referenceDate = asOf ?? DateTime.now();
    final ageInDays = math.max(0, referenceDate.difference(farm.date).inDays);
    return ageInDays >= profile.minHarvestDays;
  }

  static int daysUntilHarvest(Farm farm) {
    return expectedHarvestDate(farm).difference(DateTime.now()).inDays;
  }

  static String growthStage(String cropType, int ageInDays) {
    final profile = profileForCrop(cropType);
    if (profile == null) return 'Monitoring';
    for (final stage in profile.stages) {
      if (ageInDays >= stage.startDay && ageInDays <= stage.endDay) {
        return stage.label;
      }
    }
    return ageInDays < profile.minHarvestDays ? 'Monitoring' : 'Harvest Window';
  }

  static double harvestProgress(String cropType, int ageInDays) {
    final profile = profileForCrop(cropType);
    if (profile == null || profile.targetHarvestDays <= 0) return 0;
    return (ageInDays / profile.targetHarvestDays).clamp(0.0, 1.15);
  }

  static double projectedYieldTons(Farm farm) {
    final profile = profileForCrop(farm.type);
    if (profile == null) return 0;
    return farm.area * profile.projectedYieldTonsPerHa;
  }

  static String seasonLabel(DateTime date) {
    final month = date.month;
    if (month >= 11 || month <= 4) {
      return 'Dry Season';
    }
    return 'Wet Season';
  }

  static double irrigationNeed(
    String cropType,
    int ageInDays, {
    double? temperatureC,
    int? humidity,
  }) {
    final profile = profileForCrop(cropType);
    if (profile == null) return 0.35;

    var need = ageInDays >= profile.waterDemandStartDay &&
            ageInDays <= profile.waterDemandEndDay
        ? 0.72
        : 0.42;

    if ((temperatureC ?? 0) >= 32) {
      need += 0.12;
    } else if ((temperatureC ?? 0) <= 24) {
      need -= 0.05;
    }

    if ((humidity ?? 0) >= 85) {
      need -= 0.08;
    } else if ((humidity ?? 0) > 0 && (humidity ?? 0) <= 60) {
      need += 0.08;
    }

    if (cropType.toLowerCase().contains('sugar') && ageInDays >= 280) {
      need -= 0.14;
    }

    return need.clamp(0.15, 1.0);
  }

  static String irrigationStatus(
    String cropType,
    int ageInDays, {
    double? temperatureC,
    int? humidity,
  }) {
    final need = irrigationNeed(
      cropType,
      ageInDays,
      temperatureC: temperatureC,
      humidity: humidity,
    );

    if (need >= 0.78) return 'High Priority';
    if (need >= 0.56) return 'Scheduled';
    if (need >= 0.36) return 'Monitor';
    return 'Light';
  }

  static List<ScheduleAlert> inputAlertsForCrop(
      String cropType, int ageInDays) {
    final normalized = cropType.trim().toLowerCase();
    final alerts = switch (true) {
      _ when normalized.contains('sugar') => _sugarcaneInputAlerts,
      _ when normalized.contains('rice') || normalized.contains('palay') =>
        _riceInputAlerts,
      _ when normalized.contains('corn') || normalized.contains('maize') =>
        _cornInputAlerts,
      _ => const <ScheduleAlert>[],
    };

    return alerts
        .where((alert) =>
            ageInDays <= alert.endDay + 30 && ageInDays >= alert.startDay - 21)
        .toList()
      ..sort(
        (left, right) => _alertDistance(left, ageInDays)
            .compareTo(_alertDistance(right, ageInDays)),
      );
  }

  static int _alertDistance(ScheduleAlert alert, int ageInDays) {
    if (ageInDays >= alert.startDay && ageInDays <= alert.endDay) {
      return 0;
    }
    if (ageInDays < alert.startDay) {
      return alert.startDay - ageInDays;
    }
    return ageInDays - alert.endDay + 60;
  }

  static const List<ScheduleAlert> _riceInputAlerts = [
    ScheduleAlert(
      title: 'First Fertilizer & Herbicide',
      message:
          'Apply early Nitrogen and clean the field while tillers are still building. Use herbicide only when weed pressure is active.',
      startDay: 15,
      endDay: 28,
      icon: Icons.compost_rounded,
      color: Colors.green,
    ),
    ScheduleAlert(
      title: 'Pest and Disease Watch',
      message:
          'Scout for stem borers, leaf folders, and sheath diseases during the humid canopy-building stage.',
      startDay: 25,
      endDay: 55,
      icon: Icons.pest_control_rounded,
      color: Colors.orange,
    ),
    ScheduleAlert(
      title: 'Top-Dress and Foliar Support',
      message:
          'Top-dress around panicle initiation. Add foliar support only if recovery is weak or deficiency symptoms are visible.',
      startDay: 45,
      endDay: 65,
      icon: Icons.spa_rounded,
      color: Colors.lightGreen,
    ),
  ];

  static const List<ScheduleAlert> _cornInputAlerts = [
    ScheduleAlert(
      title: 'Basal Feed and Weed Control',
      message:
          'Side-dress early fertilizer and clear weeds before canopy closure reduces spray coverage.',
      startDay: 10,
      endDay: 22,
      icon: Icons.compost_rounded,
      color: Colors.green,
    ),
    ScheduleAlert(
      title: 'Armyworm Scouting',
      message:
          'Inspect whorls and leaf damage regularly. Treat only when infestation crosses the threshold.',
      startDay: 16,
      endDay: 38,
      icon: Icons.bug_report_rounded,
      color: Colors.red,
    ),
    ScheduleAlert(
      title: 'Second Fertilizer and Hilling',
      message:
          'Reinforce the stand with the second feed and hilling-up before tasseling demand peaks.',
      startDay: 30,
      endDay: 48,
      icon: Icons.agriculture_rounded,
      color: Colors.orange,
    ),
    ScheduleAlert(
      title: 'Foliar and Stress Check',
      message:
          'Use foliar micronutrients only when the stand is uneven or weather stress is slowing development.',
      startDay: 46,
      endDay: 68,
      icon: Icons.water_drop_rounded,
      color: Colors.blue,
    ),
  ];

  static const List<ScheduleAlert> _sugarcaneInputAlerts = [
    ScheduleAlert(
      title: 'Early Herbicide Window',
      message:
          'Apply pre-emergence or early post-emergence weed control before cane shading closes the furrows.',
      startDay: 20,
      endDay: 45,
      icon: Icons.grass_rounded,
      color: Colors.green,
    ),
    ScheduleAlert(
      title: 'Nitrogen Split Application',
      message:
          'Split Nitrogen across the tillering stage and keep band placement close to the root zone for better recovery.',
      startDay: 30,
      endDay: 90,
      icon: Icons.compost_rounded,
      color: Colors.lightGreen,
    ),
    ScheduleAlert(
      title: 'Foliar Micronutrient Support',
      message:
          'Use foliar support during active stalk building when leaves look stressed or micronutrient demand is visible.',
      startDay: 90,
      endDay: 180,
      icon: Icons.spa_rounded,
      color: Colors.teal,
    ),
    ScheduleAlert(
      title: 'Pest and Disease Protection',
      message:
          'Scout for borers, smut, and red rot as the canopy densifies. Keep field sanitation and treatment timing tight.',
      startDay: 100,
      endDay: 240,
      icon: Icons.pest_control_rounded,
      color: Colors.red,
    ),
    ScheduleAlert(
      title: 'Ripener and Harvest Prep',
      message:
          'Reduce late Nitrogen, trim excess water, and line up crews, trucks, and cutting sequence before harvest.',
      startDay: 250,
      endDay: 360,
      icon: Icons.event_available_rounded,
      color: Colors.amber,
    ),
  ];
}
