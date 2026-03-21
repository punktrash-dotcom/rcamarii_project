import 'package:flutter/material.dart';
import '../models/schedule_alert_model.dart';

class FarmingAdviceService {
  static List<ScheduleAlert> getAdviceForCrop(String cropType, int ageInDays) {
    switch (cropType.toLowerCase()) {
      case 'rice':
        return _getRiceAdvice(ageInDays);
      case 'corn':
        return _getCornAdvice(ageInDays);
      case 'sugarcane':
        return _getSugarcaneAdvice(ageInDays);
      default:
        return [];
    }
  }

  static List<ScheduleAlert> _getRiceAdvice(int age) {
    List<ScheduleAlert> alerts = [];
    if (age >= 0 && age <= 14) {
      alerts.add(ScheduleAlert(
        title: 'Seedling Stage',
        message:
            'Maintain shallow water level (2-3cm). Monitor for golden apple snails.',
        startDay: 0,
        endDay: 14,
        icon: Icons.water_drop,
        color: Colors.blue,
      ));
    }
    if (age >= 15 && age <= 30) {
      alerts.add(ScheduleAlert(
        title: 'Early Tillering',
        message:
            'Apply first dose of Nitrogen fertilizer. Start manual weeding or apply herbicide.',
        startDay: 15,
        endDay: 30,
        icon: Icons.grass,
        color: Colors.green,
      ));
    }
    if (age >= 45 && age <= 60) {
      alerts.add(ScheduleAlert(
        title: 'Panicle Initiation',
        message: 'Apply top-dress fertilizer. Ensure consistent water supply.',
        startDay: 45,
        endDay: 60,
        icon: Icons.agriculture,
        color: Colors.orange,
      ));
    }
    return alerts;
  }

  static List<ScheduleAlert> _getCornAdvice(int age) {
    List<ScheduleAlert> alerts = [];
    if (age >= 10 && age <= 20) {
      alerts.add(ScheduleAlert(
        title: 'Early Growth',
        message: 'Apply side-dress fertilizer. Monitor for fall armyworm.',
        startDay: 10,
        endDay: 20,
        icon: Icons.bug_report,
        color: Colors.red,
      ));
    }
    if (age >= 30 && age <= 45) {
      alerts.add(ScheduleAlert(
        title: 'Knee High Stage',
        message:
            'Hilling-up and second fertilization. Keep the field weed-free.',
        startDay: 30,
        endDay: 45,
        icon: Icons.height,
        color: Colors.green,
      ));
    }
    return alerts;
  }

  static List<ScheduleAlert> _getSugarcaneAdvice(int age) {
    final alerts = <ScheduleAlert>[];
    if (age >= 0 && age <= 30) {
      alerts.add(ScheduleAlert(
        title: 'Land Prep & Setts',
        message:
            'Deep plow 30–45 cm, add 10–15 t/ha of compost, and set up ridges/furrows before planting setts.',
        startDay: 0,
        endDay: 30,
        icon: Icons.terrain,
        color: Colors.brown.shade400,
      ));
    }
    if (age >= 15 && age <= 90) {
      alerts.add(ScheduleAlert(
        title: 'Planting & Moisture',
        message:
            'Place 30–45 cm setts with 2–3 buds, keep 75–150 cm spacing, and retain 1,500–2,500 mm water through gentle irrigation.',
        startDay: 15,
        endDay: 90,
        icon: Icons.cloudy_snowing,
        color: Colors.blue.shade400,
      ));
    }
    if (age >= 30 && age <= 150) {
      alerts.add(ScheduleAlert(
        title: 'Fertilizer Timing',
        message:
            'Apply all P/K at planting, split Nitrogen during tillering, and use band placement plus earthing-up/detrashing to boost nutrient uptake.',
        startDay: 30,
        endDay: 150,
        icon: Icons.grass,
        color: Colors.green.shade400,
      ));
    }
    if (age >= 90 && age <= 240) {
      alerts.add(ScheduleAlert(
        title: 'Grand Growth & Pests',
        message:
            'Focus on Potassium for stalk strength, maintain fertile moisture, and deploy Trichogramma cards before borers or red rot escalate.',
        startDay: 90,
        endDay: 240,
        icon: Icons.bug_report,
        color: Colors.red.shade300,
      ));
    }
    if (age >= 210 && age <= 360) {
      alerts.add(ScheduleAlert(
        title: 'Ripening & Harvest Prep',
        message:
            'Stop Nitrogen 2 months before harvest, reduce water to concentrate sugar, and ready harvesting crews for the 10–18 month window.',
        startDay: 210,
        endDay: 360,
        icon: Icons.cut,
        color: Colors.amber.shade300,
      ));
    }
    if (age >= 300) {
      alerts.add(ScheduleAlert(
        title: 'Ratoon Refresh',
        message:
            'Shave stubble 5 cm below soil, off-bar, mulch trash, and push fertigation early so ratoons start strong without replanting.',
        startDay: 300,
        endDay: 480,
        icon: Icons.support_agent,
        color: Colors.teal.shade300,
      ));
    }
    return alerts;
  }

  static String getVarietyRecommendation(String province) {
    // Basic recommendation based on Philippine regions
    final p = province.toLowerCase();
    if (p.contains('negros') || p.contains('iloilo')) {
      return 'Crops: Sugarcane (Phil 97-3933), Rice (NSIC Rc222). Climate: Dry/Wet seasons are distinct.';
    } else if (p.contains('isabela') || p.contains('cagayan')) {
      return 'Crops: Corn (Yellow Corn Hybrid), Rice (NSIC Rc160). Climate: Prone to typhoons, use resilient varieties.';
    } else if (p.contains('bukidnon') || p.contains('davao')) {
      return 'Crops: Pineapple, Banana, High-value Corn. Climate: Relatively stable rainfall year-round.';
    }
    return 'Variety: Consult your local DA office for NSIC certified seeds best for $province climate.';
  }
}
