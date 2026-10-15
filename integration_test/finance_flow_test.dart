import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flourish/main.dart' as app;
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flourish/presentation/providers/database_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'account → holding → purchase → coupon → reports persists in real SQLite',
    (tester) async {
      // Reduce Motion stops the app's ambient loops (aurora, floating empty
      // states, shimmer) so pumpAndSettle can settle.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await app.main();
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final cashName = 'QA cash $stamp',
          goldName = 'QA gold $stamp',
          contractName = 'QA certificate $stamp';
      Future<void> tap(Finder finder) async {
        // Hide the keyboard first, as a user would: while it is up, sheets
        // shrink and lazily drop off-screen buttons, and the last Scrollable
        // can be the one inside a TextField.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            200,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      // Waits for async results (database reads behind static placeholders)
      // rather than relying on animations to keep pumpAndSettle busy.
      Future<void> waitFor(Finder finder) async {
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> field(String key, String value) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
        await tester.pumpAndSettle();
      }

      Future<void> choose(String key, String label) async {
        await tap(find.byKey(ValueKey(key)));
        await tap(find.text(label).last);
      }

      await tap(find.bySemanticsLabel('Accounts'));
      await tap(find.bySemanticsLabel('Add'));
      await tester.enterText(find.byType(TextField).at(0), cashName);
      await tester.enterText(find.byType(TextField).at(1), '10000');
      await tap(find.widgetWithText(FilledButton, 'Add Account'));
      expect(find.text(cashName), findsOneWidget);

      await tap(find.bySemanticsLabel('Wealth'));
      await tap(find.widgetWithText(FilledButton, 'Add holding'));
      await field('name', goldName);
      await field('quantity', '2');
      await field('cost', '6000');
      await field('price', '3500');
      await tap(find.widgetWithText(FilledButton, 'Save'));
      expect(find.text(goldName), findsOneWidget);
      await tap(find.text(goldName));
      await tap(find.widgetWithText(OutlinedButton, 'Buy'));
      await choose('account', '$cashName (EGP)');
      await field('quantity', '1');
      await field('amount', '3600');
      await field('fee', '10');
      await tap(find.widgetWithText(FilledButton, 'Save'));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
        listen: false,
      );
      final store = container.read(financeStoreProvider),
          db = container.read(databaseProvider);
      final cash = (await db.getAllAccounts()).firstWhere(
        (a) => a.name == cashName,
      );
      expect(await store.balance(cash.id), Amount('6390'));
      final holding =
          (await container.read(financialLedgerProvider).portfolio.getAll())
              .firstWhere((h) => h.name == goldName);
      expect(holding.quantity, Amount('3'));
      expect(holding.costBasis, Amount('9610'));

      await tap(find.text('Obligations'));
      await tap(find.widgetWithText(FilledButton, 'Add contract or debt'));
      await field('name', contractName);
      await field('principal', '1200');
      await field('rate', '12');
      await choose('account', '$cashName (EGP)');
      await tap(find.widgetWithText(FilledButton, 'Save'));
      expect(
        await store.balance(cash.id),
        Amount('6390'),
        reason: 'Expected coupons never change cash',
      );
      await tap(find.text(contractName));
      await tap(find.widgetWithText(TextButton, 'Confirm').first);
      await tap(find.widgetWithText(FilledButton, 'Confirm'));
      expect(await store.balance(cash.id), Amount('6402'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(find.text('Reports'));
      expect(find.text('Spending by category'), findsOneWidget);
      await tap(find.bySemanticsLabel('Home'));
      await tap(find.bySemanticsLabel('Budgets'));
      await tap(find.bySemanticsLabel('Add'));
      await tap(find.byType(DropdownButtonFormField<int>));
      await tap(find.text('Food & Drinks').last);
      await tester.enterText(find.byType(TextField).first, '1000');
      await tap(find.widgetWithText(FilledButton, 'Create Budget'));
      await waitFor(find.textContaining('EGP 0.00 / 1000.00'));
      expect(find.textContaining('EGP 0.00 / 1000.00'), findsWidgets);
      await tap(find.bySemanticsLabel('Ledger'));
      await tap(find.byIcon(Icons.calendar_month));
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await db.close();
      final reopened = AppDatabase();
      final saved = (await reopened.getAllAccounts()).firstWhere(
        (a) => a.id == cash.id,
      );
      expect(saved.balance, 6402);
      await reopened.close();
    },
  );
}
