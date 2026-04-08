import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/models/farm_model.dart';
import 'package:nmd/services/crop_simulation_service.dart';

void main() {
  Farm buildFarm() {
    return Farm(
      id: '1',
      name: 'North Block',
      type: 'Sugarcane',
      area: 2,
      city: 'Malaybalay',
      province: 'Bukidnon',
      date: DateTime.now().subtract(const Duration(days: 120)),
      owner: 'RCAMARii',
      ratoonCount: 1,
      seasonNumber: 2,
    );
  }

  test('soil NPK and technique change projected yield', () {
    final farm = buildFarm();
    final planted = CropSimulationService.plant(
      CropSimulationService.initialState(farm),
    );

    final lowNpk = CropSimulationService.advance(
      CropSimulationService.updateSoilNpk(
        planted,
        nitrogen: 20,
        phosphorus: 20,
        potassium: 20,
      ),
      days: 60,
    );
    final highNpk = CropSimulationService.advance(
      CropSimulationService.updateSoilNpk(
        planted,
        nitrogen: 80,
        phosphorus: 75,
        potassium: 78,
      ),
      days: 60,
    );
    final precision = CropSimulationService.selectTechnique(
      highNpk,
      'mulch_drip_precision',
    );

    expect(highNpk.projectedYieldTons, greaterThan(lowNpk.projectedYieldTons));
    expect(
      precision.projectedYieldTons,
      greaterThanOrEqualTo(highNpk.projectedYieldTons),
    );
  });

  test('fast forward advances crop age and preserves planted state', () {
    final farm = buildFarm();
    final planted = CropSimulationService.plant(
      CropSimulationService.initialState(farm),
    );
    final advanced = CropSimulationService.advance(planted, days: 30);

    expect(advanced.planted, isTrue);
    expect(advanced.day, 30);
    expect(advanced.growthStage, isNot('Ready to Plant'));
  });

  test('fertilizer recommendations respond to phosphorus deficiency', () {
    final farm = buildFarm();
    final planted = CropSimulationService.plant(
      CropSimulationService.initialState(farm),
    );
    final lowP = CropSimulationService.updateSoilNpk(planted, phosphorus: 18);
    final recommendations =
        CropSimulationService.fertilizerRecommendations(lowP);

    expect(
      recommendations.any((item) => item.formula == '18-46-0'),
      isTrue,
    );
  });
}
