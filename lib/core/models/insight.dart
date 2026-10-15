import 'package:flutter/material.dart';

enum InsightType { anomaly, suggestion, forecast, achievement, warning, habit }

class Insight {
  final String id;
  final InsightType type;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final double? metricValue;
  final String? metricLabel;
  final DateTime generatedAt;

  Insight({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.metricValue,
    this.metricLabel,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();
}
