import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';
import 'payment_instruments_table.dart';

class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.setNull)();
  RealColumn get amount => real()();
  TextColumn get type => text()();
  TextColumn get note => text().nullable()();
  TextColumn get frequency => text()();
  DateTimeColumn get nextDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Destination of a recurring transfer (card autopay, savings).
  IntColumn get toAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Optional destination amount for transfers across currencies.
  RealColumn get toAmount => real().nullable()();
  IntColumn get paymentInstrumentId => integer().nullable().references(
    PaymentInstruments,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The last date a payment may post; the rule stops afterwards.
  DateTimeColumn get endDate => dateTime().nullable()();
  // Filled in by the app on every insert. Databases upgraded through the v5
  // rebuild carry a TEXT `CURRENT_TIMESTAMP` column default, which Drift cannot
  // read back as a date, so the SQL default must never be relied on.
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('income', 'expense', 'transfer'))",
    "CHECK ((type = 'transfer') = (to_account_id IS NOT NULL))",
  ];
}
