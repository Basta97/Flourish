import 'package:drift/drift.dart' show Value;
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/main.dart' as app;
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flourish/presentation/transactions/widgets/edit_transaction_sheet.dart';
import 'package:flourish/presentation/transactions/widgets/transaction_form_parts.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('calculator totals save through transaction and holding forms', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await PreferencesService.init();
    await PreferencesService.setBool('app_lock_enabled', false);
    await PreferencesService.setString('app_locale', 'en');
    await app.main();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final db = container.read(databaseProvider);
    final store = container.read(financeStoreProvider);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final accountName = 'QA calculator $stamp';
    final holdingName = 'QA calculator gold $stamp';
    final accountId = await db.insertAccount(
      AccountsCompanion.insert(
        name: accountName,
        type: 'bank',
        color: 0,
        icon: 'account_balance',
        currency: const Value('EGP'),
        balance: const Value(1000),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find
              .byWidgetPredicate(
                (w) =>
                    w is Scrollable &&
                    w.axisDirection == AxisDirection.down &&
                    w.physics is! NeverScrollableScrollPhysics,
              )
              .last,
        );
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> key(String value) =>
        tap(find.byKey(ValueKey('calculator-$value')));

    Future<void> screenshot(String name) async {
      await binding.takeScreenshot(name);
    }

    Finder calculator(Finder parent) =>
        find.descendant(of: parent, matching: find.byTooltip('Calculator'));

    await tap(find.bySemanticsLabel('Add'));
    await tap(find.text('Expense'));
    final amount = find.descendant(
      of: find.byType(AmountInput),
      matching: find.byType(TextField),
    );
    await tap(calculator(find.byType(AmountInput)));
    for (final value in [
      '1',
      '2',
      '5',
      '+',
      '7',
      '5',
      '×',
      '2',
      '−',
      '1',
      '0',
      '÷',
      '2',
    ]) {
      await key(value);
    }
    await screenshot('amount-calculator-expression');
    await key('=');
    expect(tester.widget<TextField>(amount).controller!.text, '270');
    await screenshot('amount-calculator-total');
    // Select the fixture account through the real horizontal account picker.
    final chips = find.byType(AccountChips);
    final horizontal = find.descendant(
      of: chips,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text(accountName),
      250,
      scrollable: horizontal,
      maxScrolls: 80,
    );
    await tap(find.text(accountName));
    await tap(find.text('Add Expense'));
    final transaction = (await db.getAllTransactions()).singleWhere(
      (t) => t.accountId == accountId,
    );
    expect(transaction.amount, 270);
    expect(await store.balance(accountId), Amount('730'));

    // Editing uses the same calculator and still saves via the ledger.
    showSpringBottomSheet(
      context: tester.element(find.byType(Scaffold).first),
      builder: (_) => EditTransactionSheet(transaction: transaction),
    );
    await tester.pumpAndSettle();
    await tap(calculator(find.byType(AmountInput)));
    await key('+');
    await key('5');
    await key('=');
    expect(tester.widget<TextField>(amount).controller!.text, '275');
    await tap(find.text('Save Changes'));
    expect((await db.getTransactionById(transaction.id))!.amount, 275);
    expect(await store.balance(accountId), Amount('725'));

    await tap(find.bySemanticsLabel('Insights'));
    await tap(find.text('Holdings'));
    await tap(find.widgetWithText(FilledButton, 'Add holding'));
    await tester.enterText(find.byKey(const ValueKey('name')), holdingName);
    await tap(calculator(find.byKey(const ValueKey('cost'))));
    for (final value in ['1', '0', '0', '+', '5', '0', '×', '2', '=']) {
      await key(value);
    }
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('cost')))
          .controller!
          .text,
      '200',
    );
    await tap(find.widgetWithText(FilledButton, 'Save'));
    final holding =
        (await container.read(financialLedgerProvider).portfolio.getAll())
            .singleWhere((h) => h.name == holdingName);
    expect(holding.costBasis, Amount('200'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
    // Reopen the real database after closing the app and its connection.
    final reopened = AppDatabase();
    try {
      expect((await reopened.getTransactionById(transaction.id))!.amount, 275);
      final savedHolding = (await FinancialLedgerService(
        reopened,
      ).portfolio.getAll()).singleWhere((h) => h.id == holding.id);
      expect(savedHolding.costBasis, Amount('200'));
    } finally {
      await reopened.close();
    }
  });
}
