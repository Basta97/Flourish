import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/fx_policy.dart';
import 'package:flourish/core/finance/ledger_maintenance.dart';
import 'package:flourish/core/finance/system_categories.dart';
import 'package:flourish/core/finance/transaction_classifier.dart';
import 'package:flourish/core/finance/valuation_service.dart';
import 'package:flourish/core/services/category_suggester.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/data/finance/finance_store.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flourish/presentation/budgets/budgets_screen.dart'
    show budgetPeriodStart;

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late FinanceStore store;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    store = ledger.store;
  });
  tearDown(() => db.close());

  Future<int> account(String name, {String currency = 'EGP'}) =>
      db.insertAccount(
        AccountsCompanion.insert(
          name: name,
          type: 'bank',
          color: 0,
          icon: 'account_balance',
          currency: Value(currency),
          balance: const Value(1000),
        ),
      );
  Future<FlowClass> classOf(int id) async {
    final t = (await db.getTransactionById(id))!;
    return TransactionClassifier.classify(
      t,
      await store.transactionDetails(id),
      await db.getCategoryById(t.categoryId),
    );
  }

  test(
    'transfers book into Transfer Out / Transfer In and are excluded',
    () async {
      final a = await account('A'), b = await account('B');
      await ledger.transfer(
        fromAccountId: a,
        toAccountId: b,
        amount: Amount('100'),
        fee: Amount('2'),
      );
      final names = {
        for (final t in await db.getAllTransactions())
          (await db.getCategoryById(t.categoryId))!.name,
      };
      expect(names, {'Transfer Out', 'Transfer In', 'Bank fees'});
      expect(names.any((n) => n.contains('transfer transfer')), isFalse);
      final classes = [
        for (final t in await db.getAllTransactions()) await classOf(t.id),
      ];
      expect(classes.where((c) => c == FlowClass.transfer), hasLength(2));
      // The fee is real spending.
      expect(classes.where((c) => c == FlowClass.spending), hasLength(1));
    },
  );

  test('legacy system categories are merged once', () async {
    final a = await account('A');
    final legacy = await db.insertCategory(
      CategoriesCompanion.insert(
        name: 'Transfer transfer',
        icon: 'swap_horiz',
        color: 0,
        type: 'expense',
      ),
    );
    final tx = await ledger.recordCash(
      accountId: a,
      amount: Amount('5'),
      type: 'expense',
      categoryId: legacy,
    );
    await store.put('templates', 't1', {'id': 't1', 'category': '$legacy'});
    await LedgerMaintenance(db).run(preferredCurrency: 'EGP');
    expect(await db.getCategoryById(legacy), isNull);
    final moved = (await db.getTransactionById(tx))!;
    expect((await db.getCategoryById(moved.categoryId))!.name, 'Transfer Out');
    expect(await classOf(tx), FlowClass.transfer);
    expect(
      (await store.get('templates', 't1'))!['category'],
      '${moved.categoryId}',
    );
  });

  test('untouched seeded USD accounts follow the reporting currency', () async {
    final seeded = (await db.getAllAccounts()).firstWhere(
      (a) => a.name == 'Cash',
    );
    await db.customStatement(
      "UPDATE accounts SET currency = 'USD' WHERE id = ${seeded.id}",
    );
    await LedgerMaintenance(db).run(preferredCurrency: 'EGP');
    expect((await db.getAccountById(seeded.id))!.currency, 'EGP');
  });

  group('categories', () {
    test('system categories cannot be deleted or picked when hidden', () async {
      final out = await SystemCategories.idFor(db, 'transfer_out');
      await expectLater(
        db.deleteCategoryAndReassignTransactions(out),
        throwsA(isA<TransactionLogicException>()),
      );
      final pickable = SystemCategories.pickable(await db.getAllCategories());
      expect(pickable.any((c) => c.id == out), isFalse);
      expect(pickable.any((c) => c.name == 'Food & Drinks'), isTrue);
    });

    test(
      'deleting a category moves spending to Other, never a transfer',
      () async {
        final a = await account('A');
        await SystemCategories.idFor(db, 'transfer_out');
        final food = (await db.getAllCategories()).firstWhere(
          (c) => c.name == 'Food & Drinks',
        );
        final tx = await ledger.recordCash(
          accountId: a,
          amount: Amount('50'),
          type: 'expense',
          categoryId: food.id,
        );
        await db.deleteCategoryAndReassignTransactions(food.id);
        final moved = (await db.getTransactionById(tx))!;
        expect((await db.getCategoryById(moved.categoryId))!.name, 'Other');
        expect(await classOf(tx), FlowClass.spending);
      },
    );
  });

  group('exchange rates', () {
    Future<void> rate(String value, DateTime at, {bool manual = false}) =>
        store.put(
          'fx',
          'USD/EGP:$at:$manual',
          MarketObservation(
            key: 'USD/EGP',
            currency: 'EGP',
            source: 'fixture',
            value: Amount(value),
            effectiveAt: at,
            retrievedAt: at,
            manual: manual,
          ).toJson(),
        );

    test('a rate older than the window never prices a new entry', () async {
      await rate('15.7', DateTime.utc(2024, 1, 1), manual: true);
      final usd = await account('Card', currency: 'USD');
      final tx = await ledger.recordCash(
        accountId: usd,
        amount: Amount('10'),
        type: 'expense',
        date: DateTime(2026, 3, 1),
      );
      final valuation = ValuationService(store);
      expect(await valuation.transactionValue(tx, 'EGP'), isNull);
      await rate('50', DateTime.utc(2026, 2, 27));
      expect(await valuation.transactionValue(tx, 'EGP'), Amount('500'));
      expect(
        FxPolicy.usableFor(DateTime.utc(2026, 2, 20), DateTime(2026, 3, 1)),
        isFalse,
      );
    });

    test('maintenance drops stale legacy snapshot rates', () async {
      final usd = await account('Card', currency: 'USD');
      final tx = await ledger.recordCash(
        accountId: usd,
        amount: Amount('10'),
        type: 'expense',
        date: DateTime(2026, 3, 1),
      );
      // A snapshot written by an earlier version, with a rate of unknown age.
      final details = (await store.transactionDetails(tx))!;
      await store.setTransactionDetails(tx, {
        for (final e in details.entries)
          if (e.key != 'ratesAt') e.key: e.value,
        'rates': {'USD': '1', 'EGP': '15.7'},
      });
      await LedgerMaintenance(db).run(preferredCurrency: 'EGP');
      final repaired = (await store.transactionDetails(tx))!;
      expect((repaired['rates'] as Map).containsKey('EGP'), isFalse);
      expect(repaired['ratesAt'], isNotNull);
    });
  });

  test('budgets start on the reporting month day or locale week start', () {
    final now = DateTime(2026, 3, 10, 15);
    expect(
      budgetPeriodStart('monthly', now, monthStartDay: 25),
      DateTime(2026, 2, 25),
    );
    expect(budgetPeriodStart('monthly', now), DateTime(2026, 3, 1));
    // 2026-03-10 is a Tuesday; Saturday-first locales start on the 7th.
    expect(
      budgetPeriodStart('weekly', now, firstWeekday: 6),
      DateTime(2026, 3, 7),
    );
    expect(
      budgetPeriodStart('weekly', now, firstWeekday: 1),
      DateTime(2026, 3, 9),
    );
    expect(budgetPeriodStart('yearly', now), DateTime(2026, 1, 1));
  });

  test(
    'category suggestions understand Egyptian merchants and Arabic',
    () async {
      final categories = await db.getAllCategories();
      String? name(int? id) =>
          categories.where((c) => c.id == id).firstOrNull?.name;
      expect(
        name(
          CategorySuggester.suggest(
            'Talabat order',
            const [],
            categories: categories,
            type: 'expense',
          ),
        ),
        'Food & Drinks',
      );
      expect(
        name(
          CategorySuggester.suggest(
            'رحلة أوبر',
            const [],
            categories: categories,
            type: 'expense',
          ),
        ),
        'Transport',
      );
    },
  );
}
