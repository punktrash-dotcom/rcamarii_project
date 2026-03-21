import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/models/schedule_alert_model.dart';
import 'package:nmd/services/guideline_localization_service.dart';

void main() {
  test('translates sugarcane guidance to Tagalog from handbook copy', () {
    final alert = ScheduleAlert(
      title: 'Land Prep & Setts',
      message: 'placeholder',
      startDay: 0,
      endDay: 30,
      icon: Icons.terrain,
    );

    final translated = GuidelineLocalizationService.translateAlert(
      alert,
      GuidelineLanguage.tagalog,
    );

    expect(translated.title, 'Paghahanda ng Lupa at Binhi');
    expect(translated.message, contains('compost'));
  });

  test('translates sugarcane guidance to Visayan from handbook copy', () {
    final alert = ScheduleAlert(
      title: 'Planting & Moisture',
      message: 'placeholder',
      startDay: 15,
      endDay: 90,
      icon: Icons.water_drop,
    );

    final translated = GuidelineLocalizationService.translateAlert(
      alert,
      GuidelineLanguage.visayan,
    );

    expect(translated.title, 'Pagtanom ug Kaumog');
    expect(translated.message, contains('2-3 ka mata'));
  });

  test('localizes category and status labels', () {
    expect(
      GuidelineLocalizationService.categoryLabel(
        'Fertilizer',
        GuidelineLanguage.tagalog,
      ),
      'Abono',
    );
    expect(
      GuidelineLocalizationService.statusLabel(
        'NEXT',
        GuidelineLanguage.visayan,
      ),
      'SUNOD',
    );
  });
}
