import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/credit_card_service.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flourish/presentation/accounts/widgets/credit_card_panel.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flourish/presentation/transactions/widgets/add_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the real add sheet and card panel against an in-memory database.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
  });

  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));

  /// Alternates real time (for the database) and fake time (for widgets and
  /// work the widgets started) until both are idle.
  Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: child),
        ),
      ),
    );
    await settle(tester);
  }

  /// Runs database work started from the test body (fake time) to
  /// completion. Mixing it with runAsync would deadlock on Drift's lock while
  /// widget-started work is still pending in fake time.
  Future<T> drive<T>(WidgetTester tester, Future<T> work) async {
    var done = false;
    late T result;
    Object? error;
    work.then(
      (value) {
        result = value;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    for (var i = 0; i < 400 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
    if (error != null) throw error!;
    if (!done) throw StateError('Database work did not finish');
    return result;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await drive(tester, db.close());
  }

  testWidgets('records a foreign-currency purchase with the card used', (
    tester,
  ) async {
    late int bank, card;
    await tester.runAsync(() async {
      bank = await db.insertAccount(
        AccountsCompanion.insert(
          name: 'CIB account',
          type: 'bank',
          color: 0,
          icon: 'account_balance',
          currency: const Value('EGP'),
          balance: const Value(10000),
        ),
      );
      card = await db.savePaymentInstrument(
        PaymentInstrumentsCompanion.insert(
          accountId: bank,
          name: 'CIB',
          kind: 'debit_card',
          network: const Value('visa'),
          last4: const Value('1234'),
          isDefault: const Value(true),
          terms: const Value('{"fxFeePercent": "3"}'),
        ),
      );
    });
    await show(tester, AddTransactionSheet(initialAccountId: bank));

    // The default card is preselected.
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'CIB Visa ••1234'),
          )
          .selected,
      isTrue,
    );
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.scrollUntilVisible(
      find.text('Paid in another currency'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Paid in another currency'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Price in USD'),
      '٢٠',
    );
    await settle(tester);
    expect(find.textContaining('Foreign transaction fee 3%'), findsOneWidget);
    final merchant = find.widgetWithText(
      TextField,
      'Merchant or payee (optional)',
    );
    await tester.scrollUntilVisible(
      merchant,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(merchant, 'Netflix.com');
    await tester.scrollUntilVisible(
      find.text('Add Expense'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add Expense'));
    // Saving runs a database transaction and a 420 ms success animation.
    await settle(tester, rounds: 20);

    final rows = await drive(tester, db.getAllTransactions());
    final main = rows.firstWhere(
      (t) => t.merchant == 'Netflix.com' && t.amount == 1000,
    );
    final details = await drive(
      tester,
      FinancialLedgerService(db).store.transactionDetails(main.id),
    );
    expect(rows, hasLength(2));
    final purchase = rows.firstWhere((t) => t.amount == 1000);
    expect(purchase.paymentInstrumentId, card);
    expect(details?['original'], {'amount': '20', 'currency': 'USD'});
    expect(rows.firstWhere((t) => t.amount == 30).merchant, 'Netflix.com');
    await finish(tester);
  });

  testWidgets('a credit card shows limit, availability and minimum due', (
    tester,
  ) async {
    late Account account;
    await tester.runAsync(() async {
      final ledger = FinancialLedgerService(db);
      final id = await CreditCardService(ledger).createCard(
        name: 'NBE Mastercard',
        currency: 'EGP',
        owed: Amount('2000'),
        terms: CardTerms(creditLimit: Amount('10000')),
        purchaseApr: Amount('30'),
        statementDay: 1,
        paymentDay: 20,
      );
      account = (await db.getAccountById(id))!;
    });
    await show(
      tester,
      SingleChildScrollView(child: CreditCardPanel(account: account)),
    );
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('EGP 8,000.00'), findsOneWidget);
    expect(find.text('EGP 10,000.00'), findsOneWidget);
    expect(find.textContaining('20% of the limit used'), findsOneWidget);
    expect(find.text('Pay card'), findsOneWidget);
    await finish(tester);
  });
}
