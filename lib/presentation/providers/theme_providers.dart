import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/services/preferences_service.dart';

final appThemeModeProvider = StateProvider<AppThemeMode>((ref) {
  final value = PreferencesService.getString(
    'app_theme_mode',
    defaultValue: 'system',
  );
  return AppThemeMode.values.firstWhere(
    (e) => e.name == value,
    orElse: () => AppThemeMode.system,
  );
});

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

final defaultCurrencyProvider = StateProvider<String>((ref) {
  return PreferencesService.getString(
    'default_currency',
    defaultValue: AppConstants.defaultCurrency,
  );
});

final monthlyAutoIncomeProvider = StateProvider<bool>((ref) {
  return PreferencesService.getBool('monthly_auto_income', defaultValue: false);
});

final monthlyIncomeAmountProvider = StateProvider<double>((ref) {
  return PreferencesService.getDouble('monthly_income_amount', defaultValue: 0);
});

final monthlyIncomeDayProvider = StateProvider<int>((ref) {
  return PreferencesService.getInt('monthly_income_day', defaultValue: 1);
});

final monthlyIncomeAccountIdProvider = StateProvider<int?>((ref) {
  return PreferencesService.getInt(
            'monthly_income_account_id',
            defaultValue: -1,
          ) ==
          -1
      ? null
      : PreferencesService.getInt('monthly_income_account_id');
});

final monthlyIncomeCategoryIdProvider = StateProvider<int?>((ref) {
  return PreferencesService.getInt(
            'monthly_income_category_id',
            defaultValue: -1,
          ) ==
          -1
      ? null
      : PreferencesService.getInt('monthly_income_category_id');
});

final lastAutoIncomeMonthProvider = StateProvider<String?>((ref) {
  return PreferencesService.getString('last_auto_income_month').isEmpty
      ? null
      : PreferencesService.getString('last_auto_income_month');
});

Future<void> persistSettings(WidgetRef ref) async {
  await PreferencesService.setString(
    'app_theme_mode',
    ref.read(appThemeModeProvider).name,
  );
  await PreferencesService.setString(
    'default_currency',
    ref.read(defaultCurrencyProvider),
  );
  await PreferencesService.setBool(
    'monthly_auto_income',
    ref.read(monthlyAutoIncomeProvider),
  );
  await PreferencesService.setDouble(
    'monthly_income_amount',
    ref.read(monthlyIncomeAmountProvider),
  );
  await PreferencesService.setInt(
    'monthly_income_day',
    ref.read(monthlyIncomeDayProvider),
  );

  final accountId = ref.read(monthlyIncomeAccountIdProvider);
  await PreferencesService.setInt('monthly_income_account_id', accountId ?? -1);

  final categoryId = ref.read(monthlyIncomeCategoryIdProvider);
  await PreferencesService.setInt(
    'monthly_income_category_id',
    categoryId ?? -1,
  );

  final lastMonth = ref.read(lastAutoIncomeMonthProvider);
  if (lastMonth != null) {
    await PreferencesService.setString('last_auto_income_month', lastMonth);
  } else {
    await PreferencesService.remove('last_auto_income_month');
  }
}
