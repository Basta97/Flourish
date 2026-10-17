import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/ai/ai_config.dart';
import 'package:flourish/core/detection/category_resolver.dart';
import 'package:flourish/core/detection/detection_pipeline.dart';
import 'package:flourish/core/detection/transaction_candidate.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late DetectionPipeline pipeline;
  late int egp, usd;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    for (final a in await db.getAllAccounts()) {
      await db.deleteAccount(a.id);
    }
    egp = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'CIB Current',
        type: 'bank',
        color: 0,
        icon: 'account_balance',
        currency: const Value('EGP'),
      ),
    );
    usd = await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Travel card',
        type: 'bank',
        color: 0,
        icon: 'credit_card',
        currency: const Value('USD'),
      ),
    );
    pipeline = DetectionPipeline(
      db: db,
      store: ledger.store,
      settings: const AiSettings(),
    );
  });
  tearDown(() => db.close());

  test('splits, picks accounts by bank and currency, resolves categories', () async {
    final result = await pipeline.detectText(
      'CIB: You paid 89.00 EGP to Uber on card **** 7788\n\n'
      'Apple Pay: spent 24.90 USD at Starbucks\n\n'
      'Your OTP is 482913. Do not share it.',
    );
    expect(result.items, hasLength(3));
    final [uber, coffee, otp] = result.items;
    expect(uber.accountId, egp);
    expect(coffee.accountId, usd);
    expect(uber.category.reason, CategoryReason.concept);
    expect(otp.selectedByDefault, isFalse);
  });

  test('learning: memory, card account and exact duplicates', () async {
    final first = (await pipeline.detectText(
      'Paid 45.00 USD at Zed Pharmacy card ending 1111',
    )).items.single;
    final bills = (await db.getAllCategories())
        .firstWhere((c) => c.name == 'Bills & Utilities');
    await ledger.recordCash(
      accountId: egp,
      amount: first.candidate.amount!,
      type: 'expense',
      categoryId: bills.id,
      date: DateTime.now(),
    );
    await pipeline.learnFromSave(
      first.candidate,
      accountId: egp,
      categoryId: bills.id,
      type: 'expense',
    );

    final again = (await pipeline.detectText(
      'Paid 45.00 USD at Zed Pharmacy card ending 1111',
    )).items.single;
    expect(again.duplicate?.kind, DuplicateKind.sameMessage);
    expect(again.selectedByDefault, isFalse);

    final similar = (await pipeline.detectText(
      'Charged 45 USD at ZED PHARMACY card ending 1111',
    )).items.single;
    expect(similar.accountId, egp, reason: 'card 1111 was learned');
    expect(similar.category.categoryId, bills.id);
    expect(similar.category.reason, CategoryReason.memory);
    expect(similar.duplicate?.kind, DuplicateKind.similarTransaction);
  });

  test('new categories are created once and linked to their parent', () async {
    final food = (await db.getAllCategories())
        .firstWhere((c) => c.name == 'Food & Drinks');
    const proposal = ProposedCategory(
      name: 'Groceries',
      type: 'expense',
      icon: 'local_grocery_store',
      colorIndex: 2,
      parentName: 'Food & Drinks',
    );
    final id = await pipeline.learning.ensureCategory(proposal);
    final again = await pipeline.learning.ensureCategory(proposal);
    expect(again, id);
    final link = await ledger.store.get('categoryParents', '$id');
    expect(link?['parent'], food.id);
  });

  test('amounts stay exact', () async {
    final item = (await pipeline.detectText('KWD 1.255 debited at Sultan')).items.single;
    expect(item.candidate.amount, Amount('1.255'));
    expect(item.candidate.kind, TransactionKind.purchase);
  });
}
