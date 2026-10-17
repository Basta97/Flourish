import '../../../domain/finance/amount.dart';

/// Order of day, month and year in numeric dates such as `03/04/2024`.
enum DateOrder { dmy, mdy, ymd }

/// One transaction read from an import file, before it is matched against
/// accounts and categories. Every source (OFX, QIF, CSV presets) produces
/// these, so the rest of the import pipeline never sees file formats.
final class RawImportRow {
  /// Wall-clock date and time as written in the file; time zones in the file
  /// are dropped so the calendar day never shifts.
  final DateTime date;

  /// Always positive; the direction lives in [type].
  final Amount amount;

  /// `'income'`, `'expense'` or `'transfer'`.
  final String type;

  /// The account the money left (or, for income, arrived in).
  final String? account;

  /// Only for transfers: the account the money arrived in.
  final String? destinationAccount;
  final String? category;
  final String? subcategory;
  final String? payee;
  final String? note;

  /// Upper-case ISO 4217 code, when the file or [ImportOptions] gives one.
  final String? currency;

  /// Identifier the file assigns to the transaction (OFX FITID), useful for
  /// de-duplicating re-imports.
  final String? externalId;

  /// 1-based line (QIF/OFX) or record number (CSV, header included) the row
  /// came from, for error messages and previews.
  final int sourceLine;

  RawImportRow({
    required this.date,
    required this.amount,
    required this.type,
    this.account,
    this.destinationAccount,
    this.category,
    this.subcategory,
    this.payee,
    this.note,
    this.currency,
    this.externalId,
    required this.sourceLine,
  }) {
    if (amount <= Amount.zero) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }
    if (!const {'income', 'expense', 'transfer'}.contains(type)) {
      throw ArgumentError.value(type, 'type');
    }
  }

  RawImportRow copyWith({
    DateTime? date,
    Amount? amount,
    String? type,
    String? account,
    String? destinationAccount,
    String? category,
    String? subcategory,
    String? payee,
    String? note,
    String? currency,
    String? externalId,
    int? sourceLine,
  }) => RawImportRow(
    date: date ?? this.date,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    account: account ?? this.account,
    destinationAccount: destinationAccount ?? this.destinationAccount,
    category: category ?? this.category,
    subcategory: subcategory ?? this.subcategory,
    payee: payee ?? this.payee,
    note: note ?? this.note,
    currency: currency ?? this.currency,
    externalId: externalId ?? this.externalId,
    sourceLine: sourceLine ?? this.sourceLine,
  );

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'amount': '$amount',
    'type': type,
    'account': account,
    'destinationAccount': destinationAccount,
    'category': category,
    'subcategory': subcategory,
    'payee': payee,
    'note': note,
    'currency': currency,
    'externalId': externalId,
    'sourceLine': sourceLine,
  };

  @override
  String toString() => 'RawImportRow(${toJson()})';
}

/// A problem tied to one place in the file.
final class ImportIssue {
  final int line;
  final String message;
  const ImportIssue(this.line, this.message);
  @override
  String toString() => line > 0 ? 'Line $line: $message' : message;
}

/// What a source read: the rows it could read, the rows it could not
/// ([errors]) and things the user should know about ([warnings], such as
/// skipped mirror legs of transfers). Parsing never throws for bad rows.
final class ImportParseResult {
  final String sourceId;
  final List<RawImportRow> rows;
  final List<ImportIssue> errors;
  final List<ImportIssue> warnings;
  const ImportParseResult(
    this.sourceId,
    this.rows, {
    this.errors = const [],
    this.warnings = const [],
  });
  bool get hasErrors => errors.isNotEmpty;
}

/// User choices that override what a source would detect on its own.
final class ImportOptions {
  /// Currency for rows whose file names none.
  final String? defaultCurrency;

  /// Account for rows whose file names none (single-account QIF, bank CSV).
  final String? defaultAccount;

  /// `intl` pattern such as `dd.MM.yyyy`; when set it is the only date
  /// format tried.
  final String? dateFormat;

  /// Order of numeric dates; detected from the whole file when null.
  final DateOrder? dateOrder;

  /// `'.'` or `','`; detected from the file's amounts when null.
  final String? decimalSeparator;

  /// QIF splits become one row each (true) or stay one row with the total.
  final bool expandSplits;

  const ImportOptions({
    this.defaultCurrency,
    this.defaultAccount,
    this.dateFormat,
    this.dateOrder,
    this.decimalSeparator,
    this.expandSplits = true,
  });
}

/// One file format the importer understands.
abstract class ImportSource {
  /// Stable identifier, e.g. `ofx`, `qif`, `csv.ynab`.
  String get id;

  /// Human-readable name for the import UI.
  String get name;

  /// Cheap check on the file name and the first few KB of text.
  bool canRead(String fileName, String headOfFile);

  ImportParseResult parse(
    String content, {
    ImportOptions options = const ImportOptions(),
  });
}
