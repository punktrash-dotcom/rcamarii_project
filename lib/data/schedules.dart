import 'package:flutter/material.dart';
import '../models/schedule_alert_model.dart';

final List<ScheduleAlert> riceSchedules = [
  ScheduleAlert(
      title: 'Herbicide Application',
      message:
          'Ideal time to apply post-emergence herbicides to control weeds.',
      startDay: 5,
      endDay: 10,
      icon: Icons.grass,
      color: Colors.orange.shade300),
  ScheduleAlert(
      title: 'First Fertilizer Application',
      message:
          'Apply basal fertilizer (NPK) to provide essential nutrients for early growth.',
      startDay: 10,
      endDay: 15,
      icon: Icons.grain,
      color: Colors.green.shade300),
  ScheduleAlert(
      title: 'Top-Dressing Fertilizer',
      message:
          'Time for top-dressing with Nitrogen fertilizer to boost vegetative growth.',
      startDay: 30,
      endDay: 40,
      icon: Icons.eco,
      color: Colors.green.shade400),
  ScheduleAlert(
      title: 'Panicle Initiation',
      message:
          'Ensure adequate water and apply another round of fertilizer if needed. This stage is critical for yield.',
      startDay: 55,
      endDay: 65,
      icon: Icons.spoke,
      color: Colors.teal.shade300),
  ScheduleAlert(
      title: 'Flowering Stage',
      message:
          'The crop is now flowering. Avoid any pesticide sprays unless absolutely necessary.',
      startDay: 70,
      endDay: 85,
      icon: Icons.filter_vintage,
      color: Colors.purple.shade200),
  ScheduleAlert(
      title: 'Harvesting Window',
      message:
          'Prepare for harvest. Check for maturity (80-85% of grains are straw-colored).',
      startDay: 90,
      endDay: 120,
      icon: Icons.cut,
      color: Colors.amber.shade300),
];

final List<ScheduleAlert> sugarcaneSchedules = [
  ScheduleAlert(
      title: 'Land Preparation',
      message:
          'Final land preparation. Ensure good soil tilth before planting.',
      startDay: -15,
      endDay: 0,
      icon: Icons.terrain,
      color: Colors.brown.shade300),
  ScheduleAlert(
      title: 'Planting Season',
      message:
          'Optimal planting window for sugarcane is typically at the start of the dry season (Nov-Dec).',
      startDay: 0,
      endDay: 30),
  ScheduleAlert(
      title: 'First Weeding & Fertilizer',
      message:
          'Perform manual weeding and apply the first dose of fertilizer to boost initial growth.',
      startDay: 30,
      endDay: 45,
      icon: Icons.grass,
      color: Colors.orange.shade300),
  ScheduleAlert(
      title: 'Hilling-Up',
      message:
          'Perform hilling-up to cover the base of the plants, support them, and control weeds.',
      startDay: 90,
      endDay: 120,
      icon: Icons.landscape,
      color: Colors.brown.shade400),
  ScheduleAlert(
      title: 'Second Fertilizer Application',
      message:
          'Apply the second and final dose of fertilizer to support stalk development.',
      startDay: 120,
      endDay: 150,
      icon: Icons.eco,
      color: Colors.green.shade400),
  ScheduleAlert(
      title: 'Maturing Stage',
      message:
          'Ensure proper irrigation and monitor for pests. The crop is now maturing.',
      startDay: 240,
      endDay: 300,
      icon: Icons.wb_sunny,
      color: Colors.yellow.shade300),
  ScheduleAlert(
      title: 'Harvesting Window',
      message:
          'Sugarcane is typically ready for harvest 10-14 months after planting. Check for maturity.',
      startDay: 300,
      endDay: 420,
      icon: Icons.cut,
      color: Colors.amber.shade300),
];

final List<ScheduleAlert> cornSchedules = [
  ScheduleAlert(
      title: 'Planting Season',
      message:
          'Best planted during the wet season (May-June) or a secondary planting in Oct-Nov.',
      startDay: 0,
      endDay: 30,
      icon: Icons.grain,
      color: Colors.yellow.shade700),
  ScheduleAlert(
      title: 'First Fertilizer & Herbicide',
      message:
          'Apply initial fertilizer and pre-emergence herbicide within the first week of planting.',
      startDay: 1,
      endDay: 7,
      icon: Icons.scatter_plot,
      color: Colors.green.shade300),
  ScheduleAlert(
      title: 'Weeding',
      message:
          'Perform shallow cultivation or hand weeding to manage weeds without damaging roots.',
      startDay: 20,
      endDay: 25,
      icon: Icons.grass,
      color: Colors.orange.shade300),
  ScheduleAlert(
      title: 'Second Fertilizer (Sidedress)',
      message:
          'Apply a second dose of Nitrogen fertilizer (sidedressing) when the corn is knee-high.',
      startDay: 30,
      endDay: 45,
      icon: Icons.eco,
      color: Colors.green.shade400),
  ScheduleAlert(
      title: 'Tasseling Stage',
      message:
          'Critical stage for pollination. Ensure adequate water and watch for pests like the corn borer.',
      startDay: 45,
      endDay: 55,
      icon: Icons.filter_vintage,
      color: Colors.purple.shade200),
  ScheduleAlert(
      title: 'Green Corn Harvest',
      message:
          'If harvesting for green corn (elote), the ideal window is around 70-80 days.',
      startDay: 70,
      endDay: 80,
      icon: Icons.shopping_basket,
      color: Colors.lightGreen.shade300),
  ScheduleAlert(
      title: 'Grain Harvest Window',
      message:
          "For mature grain, harvest when a 'black layer' forms at the kernel base, typically 100-120 days after planting.",
      startDay: 100,
      endDay: 120,
      icon: Icons.cut,
      color: Colors.amber.shade300),
];
