import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_theme.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flourish/presentation/transactions/widgets/add_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editing goes through the same sheet as adding, for every kind of entry.
void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
  });

  late AppDatabase db;
  late FinancialLedgerService ledger;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
  });

  Future<void> settle(WidgetTester tester, {int rounds = 5}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

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
    return result;
  }

  Future<void> edit(WidgetTester tester, Transaction t) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: AddTransactionSheet(editing: t)),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Save Changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(find.text('Save Changes'));
    await settle(tester, rounds: 20);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await drive(tester, db.close());
  }

  Future<int> account(String name) => db.insertAccount(
    AccountsCompanion.insert(
      name: name,
      type: 'bank',
      color: 0,
      icon: 'account_balance',
      currency: const Value('EGP'),
      balance: const Value(1000),
    ),
  );
  Future<int> food() async => (await db.getAllCategories())
      .firstWhere((c) => c.name == 'Food & Drinks')
      .id;
  final amountField = find.byType(TextField).first;

  testWidgets('an expense opens filled in and saves changes', (tester) async {
    late Transaction t;
    await tester.runAsync(() async {
      final bank = await account('Bank');
      final id = await ledger.recordCash(
        accountId: bank,
        amount: Amount('120'),
        type: 'expense',
        categoryId: await food(),
        merchant: 'Talabat',
      );
      t = (await db.getTransactionById(id))!;
    });
    await edit(tester, t);
    expect(find.text('Edit Transaction'), findsOneWidget);
    // Expense and income only; no transfer when editing.
    expect(find.text('Transfer'), findsNothing);
    await tester.enterText(amountField, '150');
    await save(tester);
    final row = await drive(tester, db.getTransactionById(t.id));
    expect(row!.amount, 150);
    expect(row.merchant, 'Talabat');
    expect(await drive(tester, ledger.store.balance(t.accountId)), Amount('850'));
    await finish(tester);
  });

  testWidgets('a refund stays a refund', (tester) async {
    late Transaction t;
    await tester.runAsync(() async {
      final bank = await account('Bank');
      final id = await ledger.recordRefund(
        accountId: bank,
        amount: Amount('40'),
        expenseCategoryId: await food(),
      );
      t = (await db.getTransactionById(id))!;
    });
    await edit(tester, t);
    expect(find.text('Expense'), findsNothing);
    await tester.enterText(amountField, '45');
    await save(tester);
    final row = await drive(tester, db.getTransactionById(t.id));
    expect(row!.amount, 45);
    expect(row.type, 'income');
    final details = await drive(tester, ledger.store.transactionDetails(t.id));
    expect(details?['kind'], 'refund');
    await finish(tester);
  });

  testWidgets('a transfer edits both legs in the same form', (tester) async {
    late int from, to;
    late Transaction incoming;
    await tester.runAsync(() async {
      from = await account('Bank');
      to = await account('Savings');
      await ledger.transfer(
        fromAccountId: from,
        toAccountId: to,
        amount: Amount('300'),
      );
      // Open it from the receiving leg, as a ledger row would.
      incoming = (await db.getAllTransactions()).firstWhere(
        (t) => t.type == 'income',
      );
    });
    await edit(tester, incoming);
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    await tester.enterText(amountField, '250');
    await save(tester);
    expect(await drive(tester, ledger.store.balance(from)), Amount('750'));
    expect(await drive(tester, ledger.store.balance(to)), Amount('1250'));
    expect(await drive(tester, db.getAllTransactions()), hasLength(2));
    await finish(tester);
  });
}
