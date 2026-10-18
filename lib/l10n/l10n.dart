import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  /// Strings for the app's current language. Falls back to English where no
  /// [AppLocalizations] delegate is installed (bare widget tests).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? _english;
}

final AppLocalizations _english = lookupAppLocalizations(const Locale('en'));

/// Strings for code without a [BuildContext] (formatters, services), in the
/// language the app last resolved.
AppLocalizations get currentL10n {
  final code = (Intl.defaultLocale ?? 'en').split(RegExp('[_-]')).first;
  return AppLocalizations.delegate.isSupported(Locale(code))
      ? lookupAppLocalizations(Locale(code))
      : _english;
}

/// True when the app runs in a right-to-left language.
bool get isRtlLocale => (Intl.defaultLocale ?? 'en').startsWith('ar');
