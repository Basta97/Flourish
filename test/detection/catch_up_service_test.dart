import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flourish/core/detection/catch_up_service.dart';
import 'package:flourish/core/detection/detection_service.dart';
import 'package:flourish/core/finance/financial_ledger_service.dart';
import 'package:flourish/core/finance/import/import_source.dart';
import 'package:flourish/core/finance/import/import_window.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/domain/finance/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FinancialLedgerService ledger;
  late DetectionService detection;
  late CatchUpService catchUp;
  late int bank;
  final now = DateTime(2026, 10, 19, 12);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = FinancialLedgerService(db);
    detection = DetectionService(ledger);
    catchUp = CatchUpService(detection);
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
        balance: const Value(10000),
      ),
    );
    await db.insertAccount(
      AccountsCompanion.insert(
        name: 'Wallet',
        type: 'bank',
        color: 0,
        icon: 'wallet',
        currency: const Value('EGP'),
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
  });
  tearDown(() => db.close());

  test(
    'keeps only payments from the last 7 days that are not in Flourish',
    () async {
      // Entered by hand yesterday.
      await ledger.recordCash(
        accountId: bank,
        amount: Amount('250'),
        type: 'expense',
        date: DateTime(2026, 10, 18, 9),
      );
      final result = await catchUp.fromText(
        'Card ending 1234 was charged EGP 250.00 at Talabat on 18/10/2026\n\n'
        'Card ending 1234 was charged EGP 99.00 at Seoudi on 17/10/2026\n\n'
        'Card ending 1234 was charged EGP 40.00 at Kiosk on 01/10/2026\n\n'
        'Your OTP is 482913. Do not share it.',
        now: now,
      );
      expect(result.already, hasLength(1));
      expect(result.already.single.payment.amount, '250');
      expect(result.missing, hasLength(1));
      expect(result.missing.single.amount, '99');
      expect(result.older, 1);
      expect(result.ignored, 1);
    },
  );

  test('an alert with an unknown account still matches by currency', () async {
    await ledger.recordCash(
      accountId: bank,
      amount: Amount('75'),
      type: 'expense',
      date: DateTime(2026, 10, 17, 20),
    );
    final result = await catchUp.fromText(
      'Purchase of EGP 75.00 at Zed on 17/10/2026',
      now: now,
    );
    expect(result.missing, isEmpty);
    expect(result.already.single.transactionId, isNotNull);
  });

  test('pasting the same alerts again does not add them twice', () async {
    const text =
        'Card ending 1234 was charged EGP 99.00 at Seoudi on 17/10/2026';
    final first = await catchUp.fromText(text, now: now);
    expect(first.missing, hasLength(1));
    final again = await catchUp.fromText(text, now: now);
    expect(again.missing, isEmpty);
  });

  test(
    'marking as already recorded clears the inbox without new entries',
    () async {
      await ledger.recordCash(
        accountId: bank,
        amount: Amount('250'),
        type: 'expense',
        date: DateTime(2026, 10, 18, 9),
      );
      final result = await catchUp.fromText(
        'Card ending 1234 was charged EGP 250.00 at Talabat on 18/10/2026',
        now: now,
      );
      final before = (await db.getAllTransactions()).length;
      await catchUp.markRecorded(result.already);
      final row = await detection.get(result.already.single.payment.id);
      expect(row!.status, 'confirmed');
      expect((await db.getAllTransactions()).length, before);
    },
  );

  test('statement rows older than the window are left out with a note', () {
    final parsed = ImportParseResult('ofx', [
      RawImportRow(
        date: DateTime(2026, 10, 1),
        amount: Amount('10'),
        type: 'expense',
        sourceLine: 1,
      ),
      RawImportRow(
        date: DateTime(2026, 10, 15),
        amount: Amount('20'),
        type: 'expense',
        sourceLine: 2,
      ),
    ]);
    final recent = parsed.since(
      CatchUpService.since(now),
      olderWarning: (n) => '$n older',
    );
    expect(recent.rows.single.amount, Amount('20'));
    expect(recent.warnings.single.message, '1 older');
  });

  test('undated alerts are compared across the whole window, one match each', () async {
    for (final day in [15, 17]) {
      await ledger.recordCash(
        accountId: bank,
        amount: Amount('45'),
        type: 'expense',
        date: DateTime(2026, 10, day, 8),
      );
    }
    final result = await catchUp.fromText(
      'Card ending 1234 was charged EGP 45.00 at Costa\n\n'
      'Card ending 1234 was charged EGP 45.00 at Costa Zayed\n\n'
      'Card ending 1234 was charged EGP 45.00 at Costa Maadi',
      now: DateTime(2026, 10, 19, 12, 0, 7),
    );
    expect(result.already, hasLength(2));
    expect(result.missing, hasLength(1));
  });
}
