import 'package:flutter/material.dart';

class ScheduleAlert {
  final String title;
  final String message;
  final int startDay;
  final int endDay;
  final IconData icon;
  final Color color;

  const ScheduleAlert({
    required this.title,
    required this.message,
    required this.startDay,
    required this.endDay,
    this.icon = Icons.info_outline,
    this.color = Colors.blue,
  });
}
