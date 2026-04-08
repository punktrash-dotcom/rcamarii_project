import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/farm_model.dart';
import '../models/schedule_alert_model.dart';
import 'farm_operations_service.dart';

@immutable
class CropSimulationEnvironment {
  const CropSimulationEnvironment({
    this.temperatureC = 31,
    this.humidity = 74,
    this.weeklyRainfallMm = 24,
  });

  final double temperatureC;
  final int humidity;
  final double weeklyRainfallMm;

  CropSimulationEnvironment copyWith({
    double? temperatureC,
    int? humidity,
    double? weeklyRainfallMm,
  }) {
    return CropSimulationEnvironment(
      temperatureC: temperatureC ?? this.temperatureC,
      humidity: humidity ?? this.humidity,
      weeklyRainfallMm: weeklyRainfallMm ?? this.weeklyRainfallMm,
    );
  }
}

@immutable
class CropPlantingTechnique {
  const CropPlantingTechnique({
    required this.key,
    required this.label,
    required this.description,
    required this.waterEfficiency,
    required this.nutrientEfficiency,
    required this.pestResistance,
    required this.emergenceBoost,
    required this.canopyDensity,
    required this.rootStrength,
  });

  final String key;
  final String label;
  final String description;
  final double waterEfficiency;
  final double nutrientEfficiency;
  final double pestResistance;
  final double emergenceBoost;
  final double canopyDensity;
  final double rootStrength;
}

@immutable
class CropFertilizerRecommendation {
  const CropFertilizerRecommendation({
    required this.label,
    required this.formula,
    required this.reason,
    required this.nitrogenDelta,
    required this.phosphorusDelta,
    required this.potassiumDelta,
    required this.color,
  });

  final String label;
  final String formula;
  final String reason;
  final double nitrogenDelta;
  final double phosphorusDelta;
  final double potassiumDelta;
  final Color color;
}

@immutable
class CropSimulationLogEntry {
  const CropSimulationLogEntry({
    required this.day,
    required this.title,
    required this.details,
  });

  final int day;
  final String title;
  final String details;
}

@immutable
class CropSimulationState {
  const CropSimulationState({
    required this.farm,
    required this.profile,
    required this.plantingDate,
    required this.environment,
    required this.techniqueKey,
    required this.day,
    required this.planted,
    required this.harvested,
    required this.soilMoisture,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.pestPressure,
    required this.weedPressure,
    required this.plantHealth,
    required this.ripenerBoost,
    required this.irrigationCount,
    required this.fertilizationCount,
    required this.weedControlCount,
    required this.pestControlCount,
    required this.log,
    this.harvestedYieldTons,
  });

  final Farm farm;
  final CropTimelineProfile profile;
  final DateTime plantingDate;
  final CropSimulationEnvironment environment;
  final String techniqueKey;
  final int day;
  final bool planted;
  final bool harvested;
  final double soilMoisture;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double pestPressure;
  final double weedPressure;
  final double plantHealth;
  final double ripenerBoost;
  final int irrigationCount;
  final int fertilizationCount;
  final int weedControlCount;
  final int pestControlCount;
  final List<CropSimulationLogEntry> log;
  final double? harvestedYieldTons;

  CropPlantingTechnique get technique =>
      CropSimulationService.techniqueForKey(farm.type, techniqueKey) ??
      CropSimulationService.techniquesForCrop(farm.type).first;

  DateTime get simulatedDate => plantingDate.add(Duration(days: day));

  String get growthStage => planted
      ? FarmOperationsService.growthStage(farm.type, day)
      : 'Ready to Plant';

  double get nutrientLevel =>
      (nitrogen * 0.5 + phosphorus * 0.2 + potassium * 0.3).clamp(0.0, 100.0);

  double get canopyCover {
    if (!planted) {
      return 0;
    }
    final timeCurve =
        math.sin((day / profile.targetHarvestDays).clamp(0.0, 1.0) * math.pi);
    final nutritionLift = (nitrogen / 100 * 18) + (technique.canopyDensity * 6);
    return (timeCurve * 82 + nutritionLift).clamp(5.0, 100.0);
  }

  double get heightScore {
    if (!planted) {
      return 0;
    }
    final timeProgress = (day / profile.targetHarvestDays).clamp(0.0, 1.15);
    final baseHeight = timeProgress * 82;
    final techniqueLift =
        technique.emergenceBoost * 30 + technique.rootStrength * 6;
    final phosphorusLift = phosphorus / 100 * 10;
    final stressPenalty = (pestPressure + weedPressure) / 20;
    return (baseHeight + techniqueLift + phosphorusLift - stressPenalty)
        .clamp(4.0, 100.0);
  }

  double get harvestProgress {
    if (!planted) {
      return 0;
    }
    return (day / profile.targetHarvestDays).clamp(0.0, 1.15);
  }

  double get maturityPercent {
    if (!planted) {
      return 0;
    }
    final timeProgress = day / profile.targetHarvestDays;
    final healthLift = (plantHealth - 55) * 0.18;
    final phosphorusLift = (phosphorus - 50) * 0.12;
    final potassiumLift = (potassium - 50) * 0.07;
    final techniqueLift = technique.emergenceBoost * 18;
    final stressPenalty = pestPressure * 0.08 + weedPressure * 0.05;
    return (timeProgress * 100 +
            healthLift +
            phosphorusLift +
            potassiumLift +
            techniqueLift +
            ripenerBoost -
            stressPenalty)
        .clamp(0.0, 125.0);
  }

  bool get isHarvestWindow =>
      day >= profile.minHarvestDays && day <= profile.maxHarvestDays;

  bool get canAdvance => planted && !harvested;

  bool get canHarvest {
    final earliestHarvestDay = math.max(30, profile.minHarvestDays ~/ 2);
    return planted && !harvested && day >= earliestHarvestDay;
  }

  double get projectedYieldTons {
    if (!planted) {
      return 0;
    }

    final baseYield = farm.area * profile.projectedYieldTonsPerHa;
    final healthFactor = (0.45 + plantHealth / 100 * 0.55).clamp(0.45, 1.0);
    final npkFactor = (0.55 + nutrientLevel / 100 * 0.45).clamp(0.55, 1.0);
    final moistureBalance =
        (1 - ((soilMoisture - 68).abs() / (105 * technique.waterEfficiency)))
            .clamp(0.7, 1.0);
    final pestFactor =
        (1 - pestPressure / (150 * technique.pestResistance)).clamp(0.58, 1.0);
    final weedFactor = (1 - weedPressure / 160).clamp(0.65, 1.0);
    final techniqueFactor = ((technique.waterEfficiency +
                technique.nutrientEfficiency +
                technique.rootStrength) /
            3)
        .clamp(0.9, 1.12);
    final ratoonFactor = farm.type.toLowerCase().contains('sugar')
        ? (1 - math.min(farm.ratoonCount * 0.035, 0.18))
        : 1.0;

    final double timingFactor;
    if (day < 1) {
      timingFactor = 0;
    } else if (day < profile.minHarvestDays) {
      timingFactor =
          (0.46 + day / profile.minHarvestDays * 0.44).clamp(0.46, 0.9);
    } else if (day <= profile.maxHarvestDays) {
      timingFactor =
          (0.96 + math.min(ripenerBoost / 100, 0.08)).clamp(0.96, 1.04);
    } else {
      timingFactor = math.max(0.74, 1 - (day - profile.maxHarvestDays) / 240);
    }

    final maturityFactor = (maturityPercent / 100).clamp(0.52, 1.05);
    return baseYield *
        healthFactor *
        npkFactor *
        moistureBalance *
        pestFactor *
        weedFactor *
        techniqueFactor *
        ratoonFactor *
        timingFactor *
        maturityFactor;
  }

  String get harvestReadinessLabel {
    if (!planted) {
      return 'Run a soil check, choose a planting technique, then plant the crop.';
    }
    if (harvested) {
      return 'Harvest already recorded for this simulated season.';
    }
    if (isHarvestWindow && maturityPercent >= 85) {
      return 'The crop is in a strong harvest window.';
    }
    if (day < profile.minHarvestDays) {
      return 'The crop still needs more field time before harvest.';
    }
    return 'The crop can be harvested, but holding too long is reducing quality.';
  }

  CropSimulationState copyWith({
    Farm? farm,
    CropTimelineProfile? profile,
    DateTime? plantingDate,
    CropSimulationEnvironment? environment,
    String? techniqueKey,
    int? day,
    bool? planted,
    bool? harvested,
    double? soilMoisture,
    double? nitrogen,
    double? phosphorus,
    double? potassium,
    double? pestPressure,
    double? weedPressure,
    double? plantHealth,
    double? ripenerBoost,
    int? irrigationCount,
    int? fertilizationCount,
    int? weedControlCount,
    int? pestControlCount,
    List<CropSimulationLogEntry>? log,
    double? harvestedYieldTons,
    bool clearHarvestedYield = false,
  }) {
    return CropSimulationState(
      farm: farm ?? this.farm,
      profile: profile ?? this.profile,
      plantingDate: plantingDate ?? this.plantingDate,
      environment: environment ?? this.environment,
      techniqueKey: techniqueKey ?? this.techniqueKey,
      day: day ?? this.day,
      planted: planted ?? this.planted,
      harvested: harvested ?? this.harvested,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      nitrogen: nitrogen ?? this.nitrogen,
      phosphorus: phosphorus ?? this.phosphorus,
      potassium: potassium ?? this.potassium,
      pestPressure: pestPressure ?? this.pestPressure,
      weedPressure: weedPressure ?? this.weedPressure,
      plantHealth: plantHealth ?? this.plantHealth,
      ripenerBoost: ripenerBoost ?? this.ripenerBoost,
      irrigationCount: irrigationCount ?? this.irrigationCount,
      fertilizationCount: fertilizationCount ?? this.fertilizationCount,
      weedControlCount: weedControlCount ?? this.weedControlCount,
      pestControlCount: pestControlCount ?? this.pestControlCount,
      log: log ?? this.log,
      harvestedYieldTons: clearHarvestedYield
          ? null
          : harvestedYieldTons ?? this.harvestedYieldTons,
    );
  }
}

class CropSimulationService {
  static const CropTimelineProfile _fallbackProfile = CropTimelineProfile(
    key: 'generic',
    label: 'Generic Crop',
    minHarvestDays: 100,
    targetHarvestDays: 130,
    maxHarvestDays: 160,
    projectedYieldTonsPerHa: 5.0,
    waterDemandStartDay: 7,
    waterDemandEndDay: 90,
    stages: [
      CropStageWindow(startDay: 0, endDay: 15, label: 'Planting'),
      CropStageWindow(startDay: 16, endDay: 45, label: 'Establishment'),
      CropStageWindow(startDay: 46, endDay: 90, label: 'Vegetative Growth'),
      CropStageWindow(startDay: 91, endDay: 130, label: 'Maturing'),
      CropStageWindow(startDay: 131, endDay: 170, label: 'Harvest Window'),
    ],
  );

  static const CropPlantingTechnique _genericStandard = CropPlantingTechnique(
    key: 'standard',
    label: 'Standard rows',
    description: 'Balanced spacing and standard management.',
    waterEfficiency: 1.0,
    nutrientEfficiency: 1.0,
    pestResistance: 1.0,
    emergenceBoost: 0.02,
    canopyDensity: 1.0,
    rootStrength: 1.0,
  );

  static const List<CropPlantingTechnique> _sugarcaneTechniques = [
    CropPlantingTechnique(
      key: 'conventional_setts',
      label: 'Conventional setts',
      description: 'Traditional furrow planting with balanced growth response.',
      waterEfficiency: 1.0,
      nutrientEfficiency: 1.0,
      pestResistance: 1.0,
      emergenceBoost: 0.01,
      canopyDensity: 1.0,
      rootStrength: 1.0,
    ),
    CropPlantingTechnique(
      key: 'wide_row_furrow',
      label: 'Wide-row furrow',
      description:
          'Better airflow and root spread, slightly slower canopy closure.',
      waterEfficiency: 1.08,
      nutrientEfficiency: 1.03,
      pestResistance: 1.05,
      emergenceBoost: 0.02,
      canopyDensity: 0.94,
      rootStrength: 1.08,
    ),
    CropPlantingTechnique(
      key: 'mulch_drip_precision',
      label: 'Mulch + drip precision',
      description:
          'High water and nutrient efficiency with stronger late-season vigor.',
      waterEfficiency: 1.18,
      nutrientEfficiency: 1.12,
      pestResistance: 1.08,
      emergenceBoost: 0.04,
      canopyDensity: 1.06,
      rootStrength: 1.1,
    ),
    CropPlantingTechnique(
      key: 'bud_chip_high_density',
      label: 'Bud-chip high density',
      description:
          'Faster stand build-up, denser canopy, and higher nutrient demand.',
      waterEfficiency: 0.95,
      nutrientEfficiency: 1.06,
      pestResistance: 0.94,
      emergenceBoost: 0.06,
      canopyDensity: 1.14,
      rootStrength: 0.95,
    ),
  ];

  static const List<CropPlantingTechnique> _riceTechniques = [
    CropPlantingTechnique(
      key: 'transplanted',
      label: 'Transplanted',
      description: 'Stable establishment with dependable root recovery.',
      waterEfficiency: 1.0,
      nutrientEfficiency: 1.0,
      pestResistance: 1.0,
      emergenceBoost: 0.03,
      canopyDensity: 1.0,
      rootStrength: 1.02,
    ),
    CropPlantingTechnique(
      key: 'direct_seeded',
      label: 'Direct seeded',
      description: 'Fast early cover with higher weed competition risk.',
      waterEfficiency: 0.96,
      nutrientEfficiency: 1.01,
      pestResistance: 0.95,
      emergenceBoost: 0.06,
      canopyDensity: 1.08,
      rootStrength: 0.96,
    ),
    CropPlantingTechnique(
      key: 'sri_spaced',
      label: 'SRI spaced rows',
      description: 'Wider spacing and stronger roots with lower water demand.',
      waterEfficiency: 1.12,
      nutrientEfficiency: 1.05,
      pestResistance: 1.04,
      emergenceBoost: 0.02,
      canopyDensity: 0.92,
      rootStrength: 1.1,
    ),
  ];

  static const List<CropPlantingTechnique> _cornTechniques = [
    CropPlantingTechnique(
      key: 'standard_rows',
      label: 'Standard rows',
      description: 'Balanced field response and familiar machinery spacing.',
      waterEfficiency: 1.0,
      nutrientEfficiency: 1.0,
      pestResistance: 1.0,
      emergenceBoost: 0.03,
      canopyDensity: 1.0,
      rootStrength: 1.0,
    ),
    CropPlantingTechnique(
      key: 'twin_row',
      label: 'Twin-row planting',
      description: 'Denser canopy and faster light interception.',
      waterEfficiency: 0.97,
      nutrientEfficiency: 1.04,
      pestResistance: 0.96,
      emergenceBoost: 0.05,
      canopyDensity: 1.1,
      rootStrength: 0.98,
    ),
    CropPlantingTechnique(
      key: 'mulched_drip',
      label: 'Mulched drip',
      description: 'Lower moisture stress and tighter nutrient recovery.',
      waterEfficiency: 1.16,
      nutrientEfficiency: 1.1,
      pestResistance: 1.05,
      emergenceBoost: 0.03,
      canopyDensity: 1.03,
      rootStrength: 1.08,
    ),
  ];

  static CropSimulationState initialState(Farm farm) {
    final techniques = techniquesForCrop(farm.type);
    return CropSimulationState(
      farm: farm,
      profile: _profileForCrop(farm.type),
      plantingDate: DateTime(farm.date.year, farm.date.month, farm.date.day),
      environment: const CropSimulationEnvironment(),
      techniqueKey: techniques.first.key,
      day: 0,
      planted: false,
      harvested: false,
      soilMoisture: 58,
      nitrogen: 52,
      phosphorus: 46,
      potassium: 50,
      pestPressure: 8,
      weedPressure: 12,
      plantHealth: 72,
      ripenerBoost: 0,
      irrigationCount: 0,
      fertilizationCount: 0,
      weedControlCount: 0,
      pestControlCount: 0,
      log: const [
        CropSimulationLogEntry(
          day: 0,
          title: 'Soil check ready',
          details: 'Adjust NPK first, then pick a planting technique.',
        ),
      ],
    );
  }

  static List<CropPlantingTechnique> techniquesForCrop(String cropType) {
    final normalized = cropType.trim().toLowerCase();
    if (normalized.contains('sugar')) {
      return _sugarcaneTechniques;
    }
    if (normalized.contains('rice') || normalized.contains('palay')) {
      return _riceTechniques;
    }
    if (normalized.contains('corn') || normalized.contains('maize')) {
      return _cornTechniques;
    }
    return const [
      _genericStandard,
      CropPlantingTechnique(
        key: 'dense_rows',
        label: 'Dense rows',
        description: 'Faster canopy but heavier N demand.',
        waterEfficiency: 0.96,
        nutrientEfficiency: 1.03,
        pestResistance: 0.95,
        emergenceBoost: 0.05,
        canopyDensity: 1.12,
        rootStrength: 0.96,
      ),
      CropPlantingTechnique(
        key: 'wide_rows',
        label: 'Wide rows',
        description: 'More airflow and stronger root spread.',
        waterEfficiency: 1.08,
        nutrientEfficiency: 1.01,
        pestResistance: 1.04,
        emergenceBoost: 0.02,
        canopyDensity: 0.92,
        rootStrength: 1.08,
      ),
    ];
  }

  static CropPlantingTechnique? techniqueForKey(
    String cropType,
    String key,
  ) {
    for (final technique in techniquesForCrop(cropType)) {
      if (technique.key == key) {
        return technique;
      }
    }
    return null;
  }

  static CropSimulationState updateEnvironment(
    CropSimulationState state, {
    double? temperatureC,
    int? humidity,
    double? weeklyRainfallMm,
  }) {
    return state.copyWith(
      environment: state.environment.copyWith(
        temperatureC: temperatureC,
        humidity: humidity,
        weeklyRainfallMm: weeklyRainfallMm,
      ),
    );
  }

  static CropSimulationState selectTechnique(
    CropSimulationState state,
    String techniqueKey,
  ) {
    final technique = techniqueForKey(state.farm.type, techniqueKey);
    if (technique == null || technique.key == state.techniqueKey) {
      return state;
    }
    return _appendLog(
      state.copyWith(techniqueKey: technique.key),
      title: 'Technique updated',
      details: '${technique.label} is now driving crop architecture.',
    );
  }

  static CropSimulationState updateSoilNpk(
    CropSimulationState state, {
    double? nitrogen,
    double? phosphorus,
    double? potassium,
  }) {
    return state.copyWith(
      nitrogen: (nitrogen ?? state.nitrogen).clamp(0.0, 100.0),
      phosphorus: (phosphorus ?? state.phosphorus).clamp(0.0, 100.0),
      potassium: (potassium ?? state.potassium).clamp(0.0, 100.0),
      clearHarvestedYield: state.harvested,
    );
  }

  static CropSimulationState plant(CropSimulationState state) {
    if (state.planted && !state.harvested) {
      return state;
    }

    final replanted = initialState(state.farm).copyWith(
      environment: state.environment,
      techniqueKey: state.techniqueKey,
      nitrogen: state.nitrogen,
      phosphorus: state.phosphorus,
      potassium: state.potassium,
      planted: true,
      log: const [],
    );
    return _appendLog(
      replanted,
      title: 'Crop planted',
      details:
          '${replanted.technique.label} started with NPK ${replanted.nitrogen.toStringAsFixed(0)}-${replanted.phosphorus.toStringAsFixed(0)}-${replanted.potassium.toStringAsFixed(0)}.',
    );
  }

  static CropSimulationState restart(CropSimulationState state) {
    final restarted = initialState(state.farm).copyWith(
      environment: state.environment,
      techniqueKey: state.techniqueKey,
      nitrogen: state.nitrogen,
      phosphorus: state.phosphorus,
      potassium: state.potassium,
      log: const [],
    );
    return _appendLog(
      restarted,
      title: 'Season restarted',
      details: 'Returned to the soil assessment and planting setup state.',
    );
  }

  static CropSimulationState syncToLiveAge(CropSimulationState state) {
    final targetAge = math.max(
      0,
      DateTime.now().difference(state.plantingDate).inDays,
    );
    final planted = plant(restart(state));
    final advanced = _advanceInternal(
      planted.copyWith(log: const []),
      days: targetAge,
    );
    return _appendLog(
      advanced,
      title: 'Live crop age loaded',
      details: 'Aligned the simulation to day $targetAge.',
    );
  }

  static CropSimulationState advance(
    CropSimulationState state, {
    required int days,
  }) {
    if (!state.canAdvance || days <= 0) {
      return state;
    }

    final advanced = _advanceInternal(state, days: days);
    return _appendLog(
      advanced,
      title: 'Advanced $days day${days == 1 ? '' : 's'}',
      details:
          '${advanced.growthStage} stage on day ${advanced.day}. Yield now projects at ${advanced.projectedYieldTons.toStringAsFixed(1)} tons.',
    );
  }

  static CropSimulationState irrigate(CropSimulationState state) {
    if (!state.canAdvance) {
      return state;
    }
    final next = state.copyWith(
      soilMoisture: (state.soilMoisture + 18 * state.technique.waterEfficiency)
          .clamp(0.0, 100.0),
      plantHealth: (state.plantHealth + 3.5).clamp(0.0, 100.0),
      irrigationCount: state.irrigationCount + 1,
    );
    return _appendLog(
      next,
      title: 'Irrigation applied',
      details: 'Soil moisture recovered for the next growth cycle.',
    );
  }

  static CropSimulationState weedControl(CropSimulationState state) {
    if (!state.canAdvance) {
      return state;
    }
    final next = state.copyWith(
      weedPressure: (state.weedPressure - 26).clamp(0.0, 100.0),
      plantHealth: (state.plantHealth + 2.5).clamp(0.0, 100.0),
      weedControlCount: state.weedControlCount + 1,
    );
    return _appendLog(
      next,
      title: 'Weed control done',
      details: 'Competition around the crop was reduced.',
    );
  }

  static CropSimulationState pestControl(CropSimulationState state) {
    if (!state.canAdvance) {
      return state;
    }
    final next = state.copyWith(
      pestPressure:
          (state.pestPressure - 30 * state.technique.pestResistance).clamp(
        0.0,
        100.0,
      ),
      plantHealth: (state.plantHealth + 2.5).clamp(0.0, 100.0),
      pestControlCount: state.pestControlCount + 1,
    );
    return _appendLog(
      next,
      title: 'Pest control done',
      details: 'Field damage risk dropped before it spread further.',
    );
  }

  static CropSimulationState applyRipener(CropSimulationState state) {
    if (!state.canAdvance) {
      return state;
    }
    final next = state.copyWith(
      ripenerBoost: (state.ripenerBoost + 8).clamp(0.0, 18.0),
      potassium: (state.potassium - 2).clamp(0.0, 100.0),
    );
    return _appendLog(
      next,
      title: 'Ripener scheduled',
      details: 'Late-season maturity was nudged forward.',
    );
  }

  static CropSimulationState applyFertilizer(
    CropSimulationState state,
    CropFertilizerRecommendation recommendation,
  ) {
    if (!state.canAdvance) {
      return state;
    }
    final efficiency = state.technique.nutrientEfficiency;
    final next = state.copyWith(
      nitrogen: (state.nitrogen + recommendation.nitrogenDelta * efficiency)
          .clamp(0.0, 100.0),
      phosphorus:
          (state.phosphorus + recommendation.phosphorusDelta * efficiency)
              .clamp(0.0, 100.0),
      potassium: (state.potassium + recommendation.potassiumDelta * efficiency)
          .clamp(0.0, 100.0),
      plantHealth: (state.plantHealth + 4.0).clamp(0.0, 100.0),
      fertilizationCount: state.fertilizationCount + 1,
    );
    return _appendLog(
      next,
      title: '${recommendation.label} applied',
      details: '${recommendation.formula} moved the soil closer to balance.',
    );
  }

  static CropSimulationState harvest(CropSimulationState state) {
    if (!state.canHarvest) {
      return state;
    }

    final yieldTons = state.projectedYieldTons;
    final harvested = state.copyWith(
      harvested: true,
      harvestedYieldTons: yieldTons,
    );
    return _appendLog(
      harvested,
      title: 'Crop harvested',
      details:
          'Harvest locked at ${yieldTons.toStringAsFixed(1)} tons on day ${state.day}.',
    );
  }

  static List<ScheduleAlert> recommendations(CropSimulationState state) {
    if (!state.planted || state.harvested) {
      return const <ScheduleAlert>[];
    }
    return FarmOperationsService.inputAlertsForCrop(state.farm.type, state.day);
  }

  static List<CropFertilizerRecommendation> fertilizerRecommendations(
    CropSimulationState state,
  ) {
    final stageEarly = state.day <= 60;
    final stageMid =
        state.day > 60 && state.day <= state.profile.waterDemandEndDay;
    final recommendations = <CropFertilizerRecommendation>[
      if (state.nitrogen < 55 || stageMid)
        const CropFertilizerRecommendation(
          label: 'Urea boost',
          formula: '46-0-0',
          reason:
              'Nitrogen is limiting canopy growth and vegetative vigor right now.',
          nitrogenDelta: 18,
          phosphorusDelta: 0,
          potassiumDelta: 0,
          color: Colors.green,
        ),
      if (state.phosphorus < 50 || stageEarly)
        const CropFertilizerRecommendation(
          label: 'Root starter',
          formula: '18-46-0',
          reason:
              'Phosphorus is needed for establishment, root activity, and early crop push.',
          nitrogenDelta: 6,
          phosphorusDelta: 16,
          potassiumDelta: 0,
          color: Colors.orange,
        ),
      if (state.potassium < 55 ||
          state.day >= state.profile.waterDemandEndDay ~/ 2)
        const CropFertilizerRecommendation(
          label: 'Potash support',
          formula: '0-0-60',
          reason:
              'Potassium is needed for stalk fill, stress tolerance, and later-season quality.',
          nitrogenDelta: 0,
          phosphorusDelta: 0,
          potassiumDelta: 18,
          color: Colors.deepOrange,
        ),
      const CropFertilizerRecommendation(
        label: 'Balanced complete',
        formula: '14-14-14',
        reason:
            'Use when the soil profile is generally weak and the crop needs a balanced correction.',
        nitrogenDelta: 10,
        phosphorusDelta: 10,
        potassiumDelta: 10,
        color: Colors.blue,
      ),
      const CropFertilizerRecommendation(
        label: 'Organic compost',
        formula: 'Organic',
        reason:
            'Improves overall soil condition, buffering, and slow nutrient release.',
        nitrogenDelta: 6,
        phosphorusDelta: 4,
        potassiumDelta: 5,
        color: Colors.brown,
      ),
    ];

    final deduped = <CropFertilizerRecommendation>[];
    for (final recommendation in recommendations) {
      if (deduped.any((item) => item.label == recommendation.label)) {
        continue;
      }
      deduped.add(recommendation);
    }
    return deduped.take(4).toList(growable: false);
  }

  static String npkBand(double value) {
    if (value >= 72) {
      return 'High';
    }
    if (value >= 48) {
      return 'Adequate';
    }
    if (value >= 30) {
      return 'Low';
    }
    return 'Very Low';
  }

  static String healthBand(double value) {
    if (value >= 82) {
      return 'Excellent';
    }
    if (value >= 65) {
      return 'Stable';
    }
    if (value >= 45) {
      return 'At Risk';
    }
    return 'Critical';
  }

  static CropSimulationState _advanceInternal(
    CropSimulationState state, {
    required int days,
  }) {
    var soilMoisture = state.soilMoisture;
    var nitrogen = state.nitrogen;
    var phosphorus = state.phosphorus;
    var potassium = state.potassium;
    var pestPressure = state.pestPressure;
    var weedPressure = state.weedPressure;
    var plantHealth = state.plantHealth;

    for (var offset = 0; offset < days; offset++) {
      final ageInDays = state.day + offset;
      final waterNeed = FarmOperationsService.irrigationNeed(
        state.farm.type,
        ageInDays,
        temperatureC: state.environment.temperatureC,
        humidity: state.environment.humidity,
      );
      final dailyRainGain = state.environment.weeklyRainfallMm / 7 * 0.32;
      final heatPenalty =
          math.max(0.0, state.environment.temperatureC - 31) * 0.28;
      final humidityFactor = state.environment.humidity / 100;
      final evapotranspiration = 1.6 +
          waterNeed * (2.8 / state.technique.waterEfficiency) +
          heatPenalty -
          humidityFactor * 0.35;

      soilMoisture =
          (soilMoisture + dailyRainGain - evapotranspiration).clamp(0.0, 100.0);

      final nutrientDemandBoost =
          ageInDays <= state.profile.waterDemandEndDay ? 1.0 : 0.7;
      nitrogen = (nitrogen -
              (0.22 + waterNeed * 0.12) /
                  state.technique.nutrientEfficiency *
                  nutrientDemandBoost)
          .clamp(0.0, 100.0);
      phosphorus =
          (phosphorus - 0.08 / state.technique.nutrientEfficiency).clamp(
        0.0,
        100.0,
      );
      potassium = (potassium -
              (0.12 + waterNeed * 0.08) / state.technique.nutrientEfficiency)
          .clamp(0.0, 100.0);

      final canopyShield = math.sin(
            ((ageInDays + 1) / state.profile.targetHarvestDays)
                    .clamp(0.0, 1.0) *
                math.pi,
          ) *
          0.35 *
          state.technique.canopyDensity;
      final weedGrowth = ageInDays < 130 ? 0.75 : 0.28;
      weedPressure =
          (weedPressure + weedGrowth - canopyShield * 10).clamp(0.0, 100.0);

      final pestWeatherBoost =
          ((state.environment.humidity - 65).clamp(0, 30) / 30) * 0.45 +
              ((state.environment.temperatureC - 27).clamp(0.0, 8.0) / 8) *
                  0.25;
      final potassiumShield = potassium / 100 * 0.18;
      final stagePressure =
          ageInDays >= 90 && ageInDays <= state.profile.maxHarvestDays
              ? 0.38
              : 0.18;
      pestPressure = (pestPressure +
              stagePressure +
              pestWeatherBoost -
              state.technique.pestResistance * 0.08 -
              potassiumShield)
          .clamp(0.0, 100.0);

      final moisturePenalty = soilMoisture < 35
          ? (35 - soilMoisture) / (22 * state.technique.waterEfficiency)
          : soilMoisture > 88
              ? (soilMoisture - 88) / 26
              : 0.0;
      final nitrogenPenalty = nitrogen < 40 ? (40 - nitrogen) / 18 : 0.0;
      final phosphorusPenalty = phosphorus < 35 ? (35 - phosphorus) / 22 : 0.0;
      final potassiumPenalty = potassium < 38 ? (38 - potassium) / 20 : 0.0;
      final pestPenalty = pestPressure / (155 * state.technique.pestResistance);
      final weedPenalty = weedPressure / 170;
      final careBonus = soilMoisture >= 45 &&
              soilMoisture <= 78 &&
              nitrogen >= 45 &&
              phosphorus >= 40 &&
              potassium >= 45 &&
              pestPressure <= 40 &&
              weedPressure <= 35
          ? 0.48
          : 0.0;
      final ripeningBonus = ageInDays >= state.profile.minHarvestDays
          ? state.ripenerBoost / 120
          : 0;

      plantHealth = (plantHealth +
              careBonus +
              ripeningBonus -
              moisturePenalty -
              nitrogenPenalty -
              phosphorusPenalty -
              potassiumPenalty -
              pestPenalty -
              weedPenalty)
          .clamp(0.0, 100.0);
    }

    return state.copyWith(
      day: state.day + days,
      soilMoisture: soilMoisture,
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      pestPressure: pestPressure,
      weedPressure: weedPressure,
      plantHealth: plantHealth,
    );
  }

  static CropSimulationState _appendLog(
    CropSimulationState state, {
    required String title,
    required String details,
  }) {
    final entries = <CropSimulationLogEntry>[
      CropSimulationLogEntry(
        day: state.day,
        title: title,
        details: details,
      ),
      ...state.log,
    ];

    return state.copyWith(
      log: entries.take(10).toList(growable: false),
    );
  }

  static CropTimelineProfile _profileForCrop(String cropType) {
    return FarmOperationsService.profileForCrop(cropType) ?? _fallbackProfile;
  }
}
