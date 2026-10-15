import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';

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
  // Filled in by the app on every insert. Databases upgraded through the v5
  // rebuild carry a TEXT `CURRENT_TIMESTAMP` column default, which Drift cannot
  // read back as a date, so the SQL default must never be relied on.
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('income', 'expense'))",
  ];
}
