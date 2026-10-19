import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flourish/main.dart' as app;
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/presentation/providers/database_provider.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flourish/presentation/transactions/widgets/transaction_form_parts.dart';
import 'package:flourish/presentation/transactions/widgets/edit_transaction_sheet.dart';
import 'package:flourish/shared/widgets/spring_bottom_sheet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Home → Tools → template presets → reviewed transaction → edit', (
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
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final db = container.read(databaseProvider),
        store = container.read(financeStoreProvider);
    final accountName = 'QA template account $stamp';
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
    final category = (await db.getAllCategories()).firstWhere(
      (c) => c.type == 'expense' && c.name == 'Food & Drinks',
    );
    await tester.pumpAndSettle();
    Future<void> tap(Finder finder) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
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

    Future<void> field(String key, String text) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.enterText(f, text);
      await tester.pumpAndSettle();
    }

    Future<void> choose(String key, String text) async {
      await tap(find.byKey(ValueKey(key)));
      await tap(find.text(text).last);
    }

    await tap(find.bySemanticsLabel('Tools'));
    expect(find.text('Tools'), findsOneWidget);
    await tap(find.text('Saved transaction templates'));
    await tap(find.text('New template'));
    await field('name', 'QA coffee $stamp');
    await choose('account', '$accountName (EGP)');
    await choose('category', '${category.name} (expense)');
    await field('amount0', '25');
    await field('amount1', '50');
    await field('amount2', '75');
    await tap(find.widgetWithText(FilledButton, 'Save'));
    final templates = await store.list('templates');
    final template = templates.firstWhere(
      (t) => t['name'] == 'QA coffee $stamp',
    );
    final transactionsBefore = (await db.getAllTransactions()).length;
    await tap(find.text('Use template').last);
    expect(find.text('Choose an amount'), findsOneWidget);
    await tap(find.text('50'));
    expect((await db.getAllTransactions()).length, transactionsBefore);
    final input = find.descendant(
      of: find.byType(AmountInput),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, '60');
    await tap(find.text('Add Expense'));
    final row = (await db.getAllTransactions()).firstWhere(
      (t) => t.sourceRef == template['id'],
    );
    expect(row.source, 'template');
    expect(row.amount, 60);
    expect(await store.balance(accountId), Amount('940'));
    // Use the production transaction editor on the recorded row.
    final context = tester.element(find.byType(Scaffold).first);
    showSpringBottomSheet(
      context: context,
      builder: (_) => EditTransactionSheet(transaction: row),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AmountInput),
        matching: find.byType(TextField),
      ),
      '65',
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(EditTransactionSheet)),
    )!;
    await tap(find.text(l.saveChanges));
    expect((await db.getTransactionById(row.id))!.amount, 65);
    expect(await store.balance(accountId), Amount('935'));
    // Leave the emulator on Home for visual/widget inspection, retaining the QA fixture.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Tools'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tap(find.byTooltip('Settings'));
    await tap(find.text('Tools').last);
    expect(find.text('Saved transaction templates'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(find.bySemanticsLabel('Wealth'));
    expect(find.text('Tools'), findsNothing);
    expect(find.text('Reports'), findsOneWidget);
    await tap(find.bySemanticsLabel('Home'));
    await tap(find.bySemanticsLabel('Add'));
    await tap(find.text('Use template'));
    await tap(find.text('QA coffee $stamp'));
    await tap(find.text('25'));
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(AmountInput),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '25',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(find.text('New Transaction').last, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect((await db.getTransactionById(row.id))!.amount, 65);
  });
}
