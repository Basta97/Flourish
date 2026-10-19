import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/detection/catch_up_screen.dart';
import 'package:flourish/presentation/detection/iphone_guide_screen.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home, {AppDatabase? db, Locale locale = const Locale('en')}) =>
    ProviderScope(
      overrides: [if (db != null) databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
  });

  testWidgets('pasted alerts: only the missing payment is offered', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    late int bank;
    await tester.runAsync(() async {
      for (final a in await db.getAllAccounts()) {
        await (db.delete(db.accounts)..where((t) => t.id.equals(a.id))).go();
      }
      bank = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'CIB',
          type: 'bank',
          color: 0,
          icon: 'account_balance',
          currency: const Value('EGP'),
          balance: const Value(5000),
        ),
      );
      await db.savePaymentInstrument(
        PaymentInstrumentsCompanion.insert(
          accountId: bank,
          name: 'CIB',
          kind: 'debit_card',
          last4: const Value('1234'),
          issuer: const Value('cib'),
        ),
      );
      await FinancialLedgerService(db).recordCash(
        accountId: bank,
        amount: Amount('250'),
        type: 'expense',
        date: DateTime.now().subtract(const Duration(days: 1)),
      );
    });

    Future<void> settle([int rounds = 10]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<T> drive<T>(Future<T> work) async {
      var done = false;
      late T result;
      work.then((v) {
        result = v;
        done = true;
      });
      for (var i = 0; i < 400 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      return result;
    }

    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const CatchUpScreen(), db: db));
    await settle();

    await tester.enterText(
      find.byType(TextField),
      'Card ending 1234 was charged EGP 250.00 at Talabat\n\n'
      'Card ending 1234 was charged EGP 99.00 at Seoudi',
    );
    await tester.tap(find.text('Check'));
    await settle(14);

    expect(find.text('1 payment is not in Flourish'), findsOneWidget);
    expect(find.text('Seoudi'), findsOneWidget);
    expect(find.text('1 already in Flourish'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(14);
    expect(find.text('Added'), findsOneWidget);

    final rows = await drive(db.getAllTransactions());
    expect(rows.where((t) => t.amount == 99), hasLength(1));
    expect(rows.where((t) => t.amount == 250), hasLength(1), reason: 'not added twice');

    await tester.pumpWidget(const SizedBox());
    await drive(db.close());
  });

  testWidgets('the iPhone guide renders in English and Arabic', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const IphoneGuideScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Automatic detection on iPhone'), findsOneWidget);
    expect(find.text('Open Shortcuts'), findsOneWidget);

    await tester.pumpWidget(app(const IphoneGuideScreen(), locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('الاكتشاف التلقائي على iPhone'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(ListView))),
      TextDirection.rtl,
    );
  });
}
