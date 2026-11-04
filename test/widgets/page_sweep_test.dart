import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flourish/core/router/app_router.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:shared_preferences/shared_preferences.dart';

/// Opens every page in English and Arabic and fails on any framework error
/// (exceptions, overflows). SWEEP_DB points it at a copy of a real database
/// instead of the small seeded one.
void main() {
  const pages = [
    '/dashboard',
    '/transactions',
    '/accounts',
    '/search',
    '/insights?tab=spending',
    '/insights?tab=budgets',
    '/insights?tab=goals',
    '/insights?tab=holdings',
    '/insights?tab=obligations',
    '/settings',
    '/settings?section=data',
    '/settings/ai',
    '/settings/detection',
    '/settings/detection/iphone',
    '/categories/manage',
    '/recurring',
    '/inbox',
    '/catch-up',
    '/payment-methods',
    '/templates',
    '/exchange-rates',
    '/smart-import',
    '/widget/add',
    '/widget/template',
  ];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'default_currency': 'EGP',
      'setup_done': true,
    });
    await PreferencesService.init();
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    CurrencyFormatter.rtl = false;
    Intl.defaultLocale = null;
  });

  Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// A card-paid expense: an untyped card list once crashed Insights.
  Future<void> seed(AppDatabase db) async {
    final bank = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Bank',
        type: 'bank',
        color: 0,
        icon: 'account_balance',
        currency: const Value('EGP'),
        balance: const Value(5000),
      ),
    );
    final card = await db.savePaymentInstrument(
      PaymentInstrumentsCompanion.insert(
        accountId: bank,
        name: 'Visa',
        kind: 'debit_card',
        last4: const Value('4242'),
      ),
    );
    final category = (await db.getAllCategories()).first;
    await db.insertTransaction(
      TransactionsCompanion.insert(
        accountId: bank,
        categoryId: category.id,
        amount: 250,
        type: 'expense',
        transactionDate: DateTime.now(),
        paymentInstrumentId: Value(card),
        paymentMethod: const Value('card'),
        merchant: const Value('Grocer'),
      ),
    );
  }

  AppDatabase open() {
    final source = Platform.environment['SWEEP_DB'];
    if (source == null) {
      return AppDatabase.forTesting(NativeDatabase.memory());
    }
    final copy = File(
      '${Directory.systemTemp.createTempSync('sweep').path}/f.db',
    );
    File(source).copySync(copy.path);
    for (final suffix in ['-wal', '-shm']) {
      final extra = File('$source$suffix');
      if (extra.existsSync()) extra.copySync('${copy.path}$suffix');
    }
    return AppDatabase.forTesting(NativeDatabase(copy));
  }

  for (final (name, locale, dark) in [
    ('en', const Locale('en'), false),
    ('ar', const Locale('ar'), true),
  ]) {
    for (final page in pages) {
      testWidgets(
        '$page opens without errors ($name)',
        (tester) async {
          tester.view.physicalSize = const Size(1206, 2622);
          tester.view.devicePixelRatio = 3;
          tester.view.padding = const FakeViewPadding(top: 186, bottom: 102);
          tester.view.viewPadding = const FakeViewPadding(
            top: 186,
            bottom: 102,
          );
          addTearDown(tester.view.reset);
          Intl.defaultLocale = locale.languageCode;
          CurrencyFormatter.rtl = locale.languageCode == 'ar';

          final db = open();
          if (Platform.environment['SWEEP_DB'] == null) {
            await tester.runAsync(() => seed(db));
          }
          appRouter.go(page);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [databaseProvider.overrideWithValue(db)],
              child: MaterialApp.router(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                routerConfig: appRouter,
              ),
            ),
          );
          await settle(tester);
          // Scroll to the end so lazily built sections are built too.
          for (final element in find.byType(Scrollable).evaluate().toList()) {
            if (!element.mounted) continue;
            final state = (element as StatefulElement).state as ScrollableState;
            if (state.position.axis != Axis.vertical) continue;
            state.position.jumpTo(state.position.maxScrollExtent);
            await tester.pump(const Duration(milliseconds: 100));
          }
          await settle(tester, rounds: 3);
          await tester.pumpWidget(const SizedBox());
          var done = false;
          db.close().whenComplete(() => done = true);
          for (var i = 0; i < 400 && !done; i++) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 2)),
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    }
  }
}
