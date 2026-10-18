import 'presentation/wealth/finance_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'core/motion/motion.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/utils/currency_formatter.dart';
import 'l10n/l10n.dart';
import 'presentation/providers/locale_providers.dart';
import 'presentation/providers/theme_providers.dart';

class FlourishApp extends ConsumerWidget {
  const FlourishApp({super.key});

  /// Rebuilds every widget, for settings read outside the widget tree
  /// (amount privacy, date and number locale) that const widgets would
  /// otherwise keep showing stale.
  static void rebuildAll() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    CurrencyFormatter.hidden = ref.watch(hideAmountsProvider);
    ref.listen(hideAmountsProvider, (_, _) => rebuildAll());

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Honour Dynamic Type up to 1.3×, the largest size the layouts are
      // designed and tested for.
      builder: (context, child) {
        _applyLocale(Localizations.localeOf(context));
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: FinanceAppLock(child: child!),
        );
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: Motion.slow,
      themeAnimationCurve: Motion.morph,
      routerConfig: appRouter,
    );
  }

  /// Points intl (dates) and the money formatter at the resolved language.
  /// Dates keep Latin digits so they match amounts.
  static void _applyLocale(Locale locale) {
    final code = locale.languageCode;
    if (Intl.defaultLocale == code) return;
    final first = Intl.defaultLocale == null;
    Intl.defaultLocale = code;
    DateFormat.useNativeDigitsByDefaultFor(code, false);
    CurrencyFormatter.rtl = code == 'ar';
    if (!first) {
      WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAll());
    }
  }
}
