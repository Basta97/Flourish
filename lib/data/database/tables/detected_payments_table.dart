import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';
import 'payment_instruments_table.dart';
import 'transactions_table.dart';

/// A payment found in a bank or wallet message, waiting for review or
/// already turned into a ledger entry.
@DataClassName('DetectedPayment')
class DetectedPayments extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Hash of source, sender, text and minute; repeats are ignored.
  TextColumn get fingerprint => text().unique()();

  /// android_notification, android_share, ios_shortcut, ios_wallet,
  /// ios_share, paste, ocr.
  TextColumn get source => text()();
  TextColumn get sender => text().nullable()();
  TextColumn get packageName => text().nullable()();

  /// The message with card numbers, IDs and codes removed; cleared after
  /// the retention period.
  TextColumn get rawText => text().nullable()();
  DateTimeColumn get receivedAt => dateTime()();

  /// ParsedPayment as JSON.
  TextColumn get parsed => text()();
  IntColumn get parserVersion => integer()();

  /// Exact decimal text.
  TextColumn get amount => text().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get direction => text()();
  TextColumn get kind => text().nullable()();
  TextColumn get merchant => text().nullable()();
  TextColumn get last4 => text().nullable()();
  DateTimeColumn get occurredAt => dateTime().nullable()();
  TextColumn get balanceAfter => text().nullable()();
  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get toAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get instrumentId => integer().nullable().references(
    PaymentInstruments,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get confidence => real()();

  /// pending, confirmed, dismissed, duplicate.
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get transactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// An existing ledger entry that may already record this payment.
  IntColumn get matchTransactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get duplicateOfId => integer().nullable()();
  BoolColumn get autoConfirmed =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('pending', 'confirmed', 'dismissed', 'duplicate'))",
    "CHECK (direction IN ('income', 'expense'))",
  ];
}
