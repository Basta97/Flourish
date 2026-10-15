import 'package:drift/drift.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  IntColumn get color => integer()();
  TextColumn get icon => text()();
  // Filled in by the app on every insert. Databases upgraded through the v5
  // rebuild carry a TEXT `CURRENT_TIMESTAMP` column default, which Drift cannot
  // read back as a date, so the SQL default must never be relied on.
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('bank', 'cash', 'ewallet', 'credit'))",
  ];
}
