import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);

  static const Color secondary = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static const Color income = Color(0xFF10B981);
  static const Color expense = Color(0xFFEF4444);

  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF0F172A);

  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E293B);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF334155);

  static const List<Color> gradientPrimary = [Color(0xFF4F46E5), Color(0xFF0EA5E9)];
  static const List<Color> gradientIncome = [Color(0xFF10B981), Color(0xFF34D399)];
  static const List<Color> gradientExpense = [Color(0xFFEF4444), Color(0xFFF87171)];
  static const List<Color> gradientNetWorth = [Color(0xFF4F46E5), Color(0xFF7C3AED)];

  static List<List<Color>> accountGradients = [
    [const Color(0xFF4F46E5), const Color(0xFF818CF8)],
    [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)],
    [const Color(0xFF10B981), const Color(0xFF34D399)],
    [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
    [const Color(0xFFEC4899), const Color(0xFFF472B6)],
    [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
    [const Color(0xFFEF4444), const Color(0xFFF87171)],
    [const Color(0xFF14B8A6), const Color(0xFF2DD4BF)],
  ];

  static int accountGradientIndex(String iconName) {
    return iconName.length % accountGradients.length;
  }

  static Color hex(int hex) => Color(hex);
}
