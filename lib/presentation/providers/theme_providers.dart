import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';

final appThemeModeProvider = StateProvider<AppThemeMode>((ref) => AppThemeMode.system);

final themeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(appThemeModeProvider);
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
});

final defaultCurrencyProvider = StateProvider<String>((ref) => 'USD');

final monthlyAutoIncomeProvider = StateProvider<bool>((ref) => false);

final monthlyIncomeAmountProvider = StateProvider<double>((ref) => 0);

final monthlyIncomeDayProvider = StateProvider<int>((ref) => 1);

final monthlyIncomeAccountIdProvider = StateProvider<int?>((ref) => null);

final monthlyIncomeCategoryIdProvider = StateProvider<int?>((ref) => null);

final lastAutoIncomeMonthProvider = StateProvider<String?>((ref) => null);
