import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/preferences_service.dart';

const _localeKey = 'app_locale';
const _hideAmountsKey = 'hide_amounts';

/// The language the user picked, or null to follow the device.
class AppLocaleNotifier extends StateNotifier<Locale?> {
  AppLocaleNotifier() : super(_read());

  static Locale? _read() {
    final code = PreferencesService.getString(_localeKey);
    return code.isEmpty ? null : Locale(code);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await PreferencesService.remove(_localeKey);
    } else {
      await PreferencesService.setString(_localeKey, locale.languageCode);
    }
  }
}

final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale?>(
  (ref) => AppLocaleNotifier(),
);

/// Privacy mode: when true every amount is shown as dots.
class HideAmountsNotifier extends StateNotifier<bool> {
  HideAmountsNotifier() : super(PreferencesService.getBool(_hideAmountsKey));

  Future<void> toggle() async {
    state = !state;
    await PreferencesService.setBool(_hideAmountsKey, state);
  }
}

final hideAmountsProvider = StateNotifierProvider<HideAmountsNotifier, bool>(
  (ref) => HideAmountsNotifier(),
);
