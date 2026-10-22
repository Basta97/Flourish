// Writes a backup of made-up finances for Google Play screenshots, so no
// real person's data appears in the listing. Restore it on a test device
// with Settings → Restore unencrypted backup.
//
//   flutter test tool/store_demo_backup.dart
//
// Output: build/store-demo-backup.json (git-ignored). Dates are relative to
// the day it runs, so the current month always has activity.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flourish/core/finance/backup_service.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('write store demo backup', () async {
    // Runs under `flutter test` only, so the test API is the right one.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'default_currency': 'EGP'});
    await PreferencesService.init();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final ledger = FinancialLedgerService(db);
    final now = DateTime.now();
    DateTime day(int monthsAgo, int d) =>
        DateTime(now.year, now.month - monthsAgo, d, 12);

    for (final a in await db.getAllAccounts()) {
      await (db.delete(db.accounts)..where((t) => t.id.equals(a.id))).go();
    }
    Future<int> account(String name, String type, int icon, num opening) =>
        db.insertAccount(
          AccountsCompanion.insert(
            name: name,
            type: type,
            color: icon,
            icon: type == 'cash' ? 'payments' : 'account_balance',
            currency: const Value('EGP'),
            balance: Value(opening.toDouble()),
          ),
        );
    final bank = await account('Main bank', 'bank', 0xFF3B82F6, 18500);
    final cash = await account('Cash', 'cash', 0xFF10B981, 2400);
    final savings = await account('Savings', 'bank', 0xFF8B5CF6, 65000);

    final categories = {
      for (final c in await db.getAllCategories()) c.name: c.id,
    };
    Future<void> spend(
      int accountId,
      String category,
      String amount,
      DateTime date,
      String merchant,
    ) => ledger.recordCash(
      accountId: accountId,
      amount: Amount(amount),
      type: 'expense',
      categoryId: categories[category],
      date: date,
      merchant: merchant,
      note: merchant,
    );

    for (final monthsAgo in [2, 1, 0]) {
      final lastDay = monthsAgo == 0 ? now.day : 28;
      DateTime on(int d) => day(monthsAgo, d.clamp(1, lastDay));
      await ledger.recordCash(
        accountId: bank,
        amount: Amount('32000'),
        type: 'income',
        categoryId: categories['Salary'],
        date: on(1),
        note: 'Monthly salary',
      );
      await spend(bank, 'Housing', '9500', on(2), 'Rent');
      await spend(bank, 'Bills & Utilities', '1150', on(5), 'Electricity');
      await spend(bank, 'Bills & Utilities', '450', on(6), 'Internet');
      await spend(bank, 'Food & Drinks', '2350', on(8), 'Supermarket');
      await spend(cash, 'Transport', '320', on(9), 'Taxi');
      await spend(bank, 'Food & Drinks', '640', on(12), 'Restaurant');
      await spend(bank, 'Shopping', '1890', on(15), 'Clothing store');
      await spend(cash, 'Food & Drinks', '185', on(17), 'Coffee shop');
      await spend(bank, 'Health', '540', on(19), 'Pharmacy');
      await spend(bank, 'Entertainment', '260', on(21), 'Cinema');
      await ledger.transfer(
        fromAccountId: bank,
        toAccountId: savings,
        amount: Amount('5000'),
        date: on(3),
        note: 'Monthly saving',
      );
    }
    await ledger.recordCash(
      accountId: bank,
      amount: Amount('4500'),
      type: 'income',
      categoryId: categories['Freelance'],
      date: day(0, now.day.clamp(1, 28)),
      note: 'Design project',
    );

    for (final (name, amount) in [
      ('Food & Drinks', 4000.0),
      ('Transport', 1200.0),
      ('Shopping', 2500.0),
    ]) {
      final start = DateTime(now.year, now.month, 1);
      final id = await db.insertBudget(
        BudgetsCompanion.insert(
          categoryId: categories[name]!,
          amount: amount,
          period: 'monthly',
          startDate: start,
        ),
      );
      // The budget form records the currency the limit is in.
      await ledger.store.put('budgetCurrencies', '$id', {'currency': 'EGP'});
    }
    await db.insertGoal(
      GoalsCompanion.insert(
        name: 'Emergency fund',
        targetAmount: 100000,
        currentAmount: const Value(65000),
        deadline: DateTime(now.year + 1, 6, 30),
        accountId: savings,
        color: 0xFF10B981,
        icon: 'savings',
      ),
    );

    final data = await BackupService(db).exportData();
    final out = File(
      Platform.environment['DEMO_OUT'] ?? 'build/store-demo-backup.json',
    );
    await out.parent.create(recursive: true);
    await out.writeAsString(jsonEncode(data));
    await db.close();
  });
}
