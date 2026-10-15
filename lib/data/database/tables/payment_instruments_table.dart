import 'package:drift/drift.dart';
import 'accounts_table.dart';

/// Something that pays out of an account: a debit or credit card, a mobile
/// wallet, an InstaPay address, a BNPL line. Several can share one account
/// (a bank account with a Visa debit card and an InstaPay address).
@DataClassName('PaymentInstrument')
class PaymentInstruments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// debit_card, credit_card, prepaid_card, mobile_wallet, instapay,
  /// bank_transfer, bnpl, other.
  TextColumn get kind => text()();

  /// visa, mastercard, meeza, amex, unionpay, other.
  TextColumn get network => text().nullable()();
  TextColumn get last4 => text().nullable()();

  /// Issuer id from the detection registry (cib, nbe, vodafone_cash…).
  TextColumn get issuer => text().nullable()();

  /// Masked phone number or InstaPay address for wallets.
  TextColumn get handle => text().nullable()();

  /// JSON with decimal strings: fxFeePercent, atmFee, transferFeePercent…
  TextColumn get terms => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  List<String> get customConstraints => [
    "CHECK (kind IN ('debit_card', 'credit_card', 'prepaid_card', "
        "'mobile_wallet', 'instapay', 'bank_transfer', 'bnpl', 'other'))",
  ];
}
