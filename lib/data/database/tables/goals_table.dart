import 'package:drift/drift.dart';
import 'accounts_table.dart';

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime()();
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get color => integer()();
  TextColumn get icon => text()();
  // Filled in by the app on every insert. Databases upgraded through the v5
  // rebuild carry a TEXT `CURRENT_TIMESTAMP` column default, which Drift cannot
  // read back as a date, so the SQL default must never be relied on.
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
}
