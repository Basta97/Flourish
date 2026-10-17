import '../../../domain/finance/amount.dart';
import 'csv_table.dart';
import 'import_source.dart';
import 'import_values.dart';
import 'transfer_legs.dart';

/// What a preset's reader returns for one record.
///
/// [recordedIn] is the account register the record came from, which lets
/// both sides of a transfer collapse into one row. [unpairedLeg] marks a
/// transfer leg that names no other account (Wallet, Spendee) and must be
/// matched with its opposite leg; such rows are typed income/expense.
typedef CsvRead = ({RawImportRow row, String? recordedIn, bool unpairedLeg});

/// Helpers handed to preset readers for the current record.
final class CsvContext {
  final ImportOptions options;
  final DateOrder dateOrder;
  final String? decimalSeparator;
  final List<ImportIssue> warnings;
  final int line;
  const CsvContext(
    this.options,
    this.dateOrder,
    this.decimalSeparator,
    this.warnings,
    this.line,
  );

  DateTime date(String? raw) => raw == null
      ? throw const FormatException('Missing date')
      : ImportValues.date(raw, pattern: options.dateFormat, order: dateOrder);

  Amount amount(String? raw) => raw == null
      ? throw const FormatException('Missing amount')
      : ImportValues.amount(raw, decimalSeparator: decimalSeparator);

  /// [raw] as an ISO code, the default currency when empty, and an error
  /// when it is something unrecognisable.
  String? currency(String? raw) {
    final code = ImportValues.currency(raw);
    if (raw != null && code == null) {
      throw FormatException('Unknown currency "$raw"');
    }
    return code ?? options.defaultCurrency;
  }

  String? account(String? raw) =>
      ImportValues.text(raw) ?? options.defaultAccount;

  void warn(String message) => warnings.add(ImportIssue(line, message));
}

typedef CsvReader = CsvRead? Function(CsvRecord record, CsvContext ctx);

/// A known CSV export layout. It is detected by its header [signature]:
/// every group must be present (any alias of the group will do), extra
/// columns and BOMs are ignored, and the header may sit below title lines.
final class CsvPreset implements ImportSource {
  @override
  final String id;
  @override
  final String name;

  /// Whether the layout was checked against a real export file. Unverified
  /// presets follow third-party documentation cited in [reference].
  final bool verified;
  final String reference;

  /// Header keys (see [headerKey]); each inner list is one required column.
  final List<List<String>> signature;

  /// Wins over lower priorities when several presets match.
  final int priority;
  final List<String> dateColumns, amountColumns;

  /// Order for numeric dates the file itself cannot settle.
  final DateOrder defaultDateOrder;
  final CsvReader read;

  const CsvPreset({
    required this.id,
    required this.name,
    required this.verified,
    required this.reference,
    required this.signature,
    required this.priority,
    required this.dateColumns,
    required this.amountColumns,
    required this.read,
    this.defaultDateOrder = DateOrder.dmy,
  });

  static const _headerSearchDepth = 20;

  bool matchesHeader(List<String> header) {
    final keys = headerColumns(header);
    return signature.every((group) => group.any(keys.containsKey));
  }

  /// Index of the header record in [table], or null when it is not there.
  int? headerIndex(CsvTable table) {
    final depth = table.records.length < _headerSearchDepth
        ? table.records.length
        : _headerSearchDepth;
    for (var i = 0; i < depth; i++) {
      if (matchesHeader(table.records[i])) return i;
    }
    return null;
  }

  @override
  bool canRead(String fileName, String headOfFile) {
    final lower = fileName.toLowerCase();
    if (RegExp(r'\.(ofx|qfx|qif|xlsx?|pdf)$').hasMatch(lower)) return false;
    return headerIndex(CsvTable.decode(_completeLines(headOfFile))) != null;
  }

  @override
  ImportParseResult parse(
    String content, {
    ImportOptions options = const ImportOptions(),
  }) {
    final table = CsvTable.decode(content);
    final header = headerIndex(table);
    if (header == null) {
      return ImportParseResult(
        id,
        const [],
        errors: [ImportIssue(0, 'No $name header row found')],
      );
    }
    final columns = headerColumns(table.records[header]);
    final records = [
      for (var i = header + 1; i < table.records.length; i++)
        CsvRecord(table.records[i], columns, i + 1 + table.lineOffset),
    ].where((r) => !r.isBlank).toList();
    final order =
        options.dateOrder ??
        ImportValues.detectDateOrder(
          records.map((r) => r.get(dateColumns)).nonNulls,
        ) ??
        defaultDateOrder;
    final decimal =
        options.decimalSeparator ??
        ImportValues.detectDecimalSeparator(
          records.expand((r) => amountColumns.map((c) => r.get([c])).nonNulls),
        ) ??
        (table.delimiter == ';' ? ',' : null);

    final errors = <ImportIssue>[], warnings = <ImportIssue>[];
    final reads = <CsvRead>[];
    for (final record in records) {
      final ctx = CsvContext(options, order, decimal, warnings, record.line);
      try {
        final result = read(record, ctx);
        if (result != null) reads.add(result);
      } on FormatException catch (e) {
        errors.add(ImportIssue(record.line, e.message));
      } on ArgumentError catch (e) {
        errors.add(ImportIssue(record.line, '${e.message}'));
      }
    }
    var rows = mergeMirroredTransfers(
      reads.map((r) => (row: r.row, recordedIn: r.recordedIn)),
      warnings,
    );
    final legs = {
      for (final r in reads)
        if (r.unpairedLeg) r.row,
    };
    if (legs.isNotEmpty) rows = pairTransferLegs(rows, legs, warnings);
    return ImportParseResult(id, rows, errors: errors, warnings: warnings);
  }
}

/// Drops a trailing partial line so a header cut mid-way is not misread.
String _completeLines(String head) {
  final cut = head.lastIndexOf(RegExp(r'\r\n|\r|\n'));
  return cut <= 0 ? head : head.substring(0, cut);
}

CsvRead _plain(RawImportRow row, [String? recordedIn]) =>
    (row: row, recordedIn: recordedIn, unpairedLeg: false);

/// Income/expense from a signed amount; zero amounts are skipped.
RawImportRow? _signed(
  CsvContext ctx,
  Amount signed, {
  required DateTime date,
  String? account,
  String? category,
  String? subcategory,
  String? payee,
  String? note,
  String? currency,
  String? externalId,
  String? forceType,
}) {
  if (signed == Amount.zero) {
    ctx.warn('Skipped a zero-amount entry');
    return null;
  }
  return RawImportRow(
    date: date,
    amount: signed.abs,
    type: forceType ?? (signed < Amount.zero ? 'expense' : 'income'),
    account: account,
    category: category,
    subcategory: subcategory,
    payee: payee,
    note: note,
    currency: currency,
    externalId: externalId,
    sourceLine: ctx.line,
  );
}

String? _joinNotes(String? a, String? b) {
  final parts = [a, b].map(ImportValues.text).nonNulls.toSet();
  return parts.isEmpty ? null : parts.join('\n');
}

/// Every preset, most specific first. The generic bank layout comes last.
abstract final class CsvPresets {
  /// Flourish's own "Export CSV" (exportCsv in
  /// lib/presentation/wealth/finance_tools_view.dart). Transfers are
  /// exported as their income and expense legs and are read back as such.
  static final flourish = CsvPreset(
    id: 'csv.flourish',
    name: 'Flourish export',
    verified: true,
    reference: 'exportCsv in lib/presentation/wealth/finance_tools_view.dart',
    signature: const [
      ['date'],
      ['incomeexpense'],
      ['account'],
      ['category'],
      ['amount'],
      ['currency'],
      ['note'],
    ],
    priority: 90,
    dateColumns: const ['date'],
    amountColumns: const ['amount'],
    read: (r, ctx) {
      final type = r.get(['incomeexpense'])?.toLowerCase();
      if (!const {'income', 'expense', 'transfer'}.contains(type)) {
        throw FormatException('Unknown type "${r.get(['incomeexpense'])}"');
      }
      final amount = ctx.amount(r.get(['amount']));
      final row = _signed(
        ctx,
        amount,
        date: ctx.date(r.get(['date'])),
        account: ctx.account(r.get(['account'])),
        category: r.get(['category']),
        payee: r.get(['merchant']),
        note: r.get(['note']),
        currency: ctx.currency(r.get(['currency'])),
        forceType: type,
      );
      return row == null ? null : _plain(row, row.account);
    },
  );

  /// Money Manager by Realbyte (Android/iOS), "Export to Excel" saved as
  /// CSV/TSV. Columns: Period, Accounts, Category, Subcategory, Note,
  /// <main currency code>, Income/Expense, Description, Amount, Currency,
  /// Accounts. Income/Expense holds `Income`, `Exp.`, `Transfer-Out` or
  /// `Transfer-In`; for transfers Category is the other account.
  ///
  /// UNVERIFIED: no first-party sample. Column set from the integration plan
  /// and third-party importers: github.com/rizaardiyanto1412/money-manager
  /// (README, "Transfer-Out uses Category as the destination account",
  /// mm/dd/yyyy dates) and github.com/pratikstemkar/money-manager
  /// (lib/importer/money-manager.ts header aliases).
  static final moneyManager = CsvPreset(
    id: 'csv.money_manager',
    name: 'Money Manager (Realbyte)',
    verified: false,
    reference:
        'github.com/rizaardiyanto1412/money-manager; '
        'github.com/pratikstemkar/money-manager',
    signature: const [
      ['period', 'date'],
      ['accounts', 'account'],
      ['category'],
      ['incomeexpense'],
    ],
    priority: 80,
    dateColumns: const ['period', 'date'],
    amountColumns: const ['amount'],
    defaultDateOrder: DateOrder.mdy,
    read: (r, ctx) {
      final account = ctx.account(r.get(['accounts', 'account']));
      // The main-currency column is headed by its code, e.g. "EGP".
      final codeColumn = r.columns.keys
          .where((k) => RegExp(r'^[a-z]{3}$').hasMatch(k))
          .where((k) => !const {'amt', 'sum'}.contains(k))
          .firstOrNull;
      final rawAmount =
          r.get(['amount']) ??
          (codeColumn == null ? null : r.get([codeColumn]));
      final currency = ctx.currency(
        r.get(['currency']) ?? codeColumn?.toUpperCase(),
      );
      final amount = ctx.amount(rawAmount).abs;
      if (amount == Amount.zero) {
        ctx.warn('Skipped a zero-amount entry');
        return null;
      }
      final date = ctx.date(r.get(['period', 'date']));
      final kind = headerKey(r.get(['incomeexpense']) ?? '');
      final note = _joinNotes(r.get(['note']), r.get(['description']));
      if (kind.startsWith('transfer')) {
        final other = r.get(['category']);
        if (other == null) {
          throw const FormatException('Transfer has no other account');
        }
        final incoming = kind.endsWith('in');
        return _plain(
          RawImportRow(
            date: date,
            amount: amount,
            type: 'transfer',
            account: incoming ? other : account,
            destinationAccount: incoming ? account : other,
            note: note,
            currency: currency,
            sourceLine: ctx.line,
          ),
          account,
        );
      }
      final type = kind.startsWith('inc')
          ? 'income'
          : kind.startsWith('exp')
          ? 'expense'
          : throw FormatException('Unknown type "${r.get(['incomeexpense'])}"');
      return _plain(
        RawImportRow(
          date: date,
          amount: amount,
          type: type,
          account: account,
          category: r.get(['category']),
          subcategory: r.get(['subcategory']),
          note: note,
          currency: currency,
          sourceLine: ctx.line,
        ),
        account,
      );
    },
  );

  /// Wallet by BudgetBakers, web app "Export to CSV" (`;`-separated).
  /// Amounts are signed; `transfer` is `true` on both legs of a transfer,
  /// which name no destination and are paired by amount and day.
  ///
  /// UNVERIFIED: no first-party sample. Header per the converter cited in
  /// github.com/micode-ai/ai-budget-assistant/issues/606 (account, category,
  /// currency, amount, ref_currency_amount, type, payment_type, note, date,
  /// transfer, payee, labels); export described at
  /// support.budgetbakers.com/hc/en-us/articles/7151606064018.
  static final wallet = CsvPreset(
    id: 'csv.wallet',
    name: 'Wallet by BudgetBakers',
    verified: false,
    reference:
        'github.com/micode-ai/ai-budget-assistant/issues/606; '
        'support.budgetbakers.com/hc/en-us/articles/7151606064018',
    signature: const [
      ['account'],
      ['category'],
      ['currency'],
      ['amount'],
      ['type'],
      ['date'],
      ['refcurrencyamount', 'refamount', 'paymenttype'],
    ],
    priority: 70,
    dateColumns: const ['date'],
    amountColumns: const ['amount'],
    read: (r, ctx) {
      var signed = ctx.amount(r.get(['amount']));
      final type = r.get(['type'])?.toLowerCase() ?? '';
      if (signed > Amount.zero && type.startsWith('exp')) signed = -signed;
      final leg = r.get(['transfer'])?.toLowerCase() == 'true';
      final account = ctx.account(r.get(['account']));
      final row = _signed(
        ctx,
        signed,
        date: ctx.date(r.get(['date'])),
        account: account,
        category: leg ? null : r.get(['category']),
        payee: r.get(['payee']),
        note: r.get(['note']),
        currency: ctx.currency(r.get(['currency'])),
      );
      return row == null
          ? null
          : (row: row, recordedIn: account, unpairedLeg: leg);
    },
  );

  /// Monefy, Settings → Export to file. Columns: date, account, category,
  /// amount, currency, converted amount, currency, description. Expenses
  /// are negative; transfers are recorded as category `To 'X'` on the
  /// sending account and `From 'X'` on the receiving one.
  ///
  /// UNVERIFIED: no first-party sample. Layout and `%d/%m/%Y` dates from
  /// github.com/btittelbach/pyhledger/blob/master/convert-monefy-records.py.
  static final monefy = CsvPreset(
    id: 'csv.monefy',
    name: 'Monefy',
    verified: false,
    reference:
        'github.com/btittelbach/pyhledger/blob/master/convert-monefy-records.py',
    signature: const [
      ['date'],
      ['account'],
      ['category'],
      ['amount'],
      ['currency'],
      ['description'],
    ],
    priority: 60,
    dateColumns: const ['date'],
    amountColumns: const ['amount'],
    read: (r, ctx) {
      final account = ctx.account(r.get(['account']));
      final signed = ctx.amount(r.get(['amount']));
      final date = ctx.date(r.get(['date']));
      final currency = ctx.currency(r.get(['currency']));
      final category = r.get(['category']) ?? '';
      final transfer = RegExp(r"^(To|From) '(.+)'$").firstMatch(category);
      if (transfer != null) {
        if (signed == Amount.zero) return null;
        final other = transfer[2]!, incoming = transfer[1] == 'From';
        return _plain(
          RawImportRow(
            date: date,
            amount: signed.abs,
            type: 'transfer',
            account: incoming ? other : account,
            destinationAccount: incoming ? account : other,
            note: r.get(['description']),
            currency: currency,
            sourceLine: ctx.line,
          ),
          account,
        );
      }
      final row = _signed(
        ctx,
        signed,
        date: date,
        account: account,
        category: ImportValues.text(category),
        note: r.get(['description']),
        currency: currency,
      );
      return row == null ? null : _plain(row, account);
    },
  );

  /// Spendee, web app wallet → Export → CSV. Columns: Date, Wallet, Type,
  /// Category name, Amount, Currency, Note, Labels, Author. Amounts are
  /// signed; `Transfer` rows are legs without the other wallet's name.
  ///
  /// UNVERIFIED: no first-party sample. Header per the Spendee-to-Beancount
  /// importer gist.github.com/sliceofcode/0bdcea77a8d8b4f0a89da537fbfd5800
  /// and help.spendee.com/article/209-data-import.
  static final spendee = CsvPreset(
    id: 'csv.spendee',
    name: 'Spendee',
    verified: false,
    reference:
        'gist.github.com/sliceofcode/0bdcea77a8d8b4f0a89da537fbfd5800; '
        'help.spendee.com/article/209-data-import',
    signature: const [
      ['date'],
      ['wallet'],
      ['type'],
      ['categoryname'],
      ['amount'],
      ['currency'],
    ],
    priority: 70,
    dateColumns: const ['date'],
    amountColumns: const ['amount'],
    read: (r, ctx) {
      var signed = ctx.amount(r.get(['amount']));
      final type = r.get(['type'])?.toLowerCase() ?? '';
      if (signed > Amount.zero && type.startsWith('exp')) signed = -signed;
      final leg = type.startsWith('transfer');
      final account = ctx.account(r.get(['wallet']));
      final row = _signed(
        ctx,
        signed,
        date: ctx.date(r.get(['date'])),
        account: account,
        category: leg ? null : r.get(['categoryname']),
        note: r.get(['note']),
        currency: ctx.currency(r.get(['currency'])),
      );
      return row == null
          ? null
          : (row: row, recordedIn: account, unpairedLeg: leg);
    },
  );

  /// YNAB register export ("Export" from an account or All Accounts).
  /// Columns: Account, Flag, Date, Payee, Category Group/Category, Category
  /// Group, Category, Memo, Outflow, Inflow, Cleared. Outflow/Inflow carry a
  /// currency symbol and the unused side is `0.00`; a payee of
  /// `Transfer : X` is a transfer with account X.
  ///
  /// UNVERIFIED sample: columns from the YNAB register converter
  /// gist.github.com/StephenBrown2/1d1cdf5710a917d7ef1c09314d097fe3;
  /// support.ynab.com/en_us/how-to-export-plan-data-Sy_CouWA9 (TSV for comma
  /// decimal currencies).
  static final ynab = CsvPreset(
    id: 'csv.ynab',
    name: 'YNAB',
    verified: false,
    reference:
        'gist.github.com/StephenBrown2/1d1cdf5710a917d7ef1c09314d097fe3; '
        'support.ynab.com/en_us/how-to-export-plan-data-Sy_CouWA9',
    signature: const [
      ['account'],
      ['date'],
      ['payee'],
      ['outflow'],
      ['inflow'],
    ],
    priority: 80,
    dateColumns: const ['date'],
    amountColumns: const ['outflow', 'inflow'],
    defaultDateOrder: DateOrder.mdy,
    read: (r, ctx) {
      final account = ctx.account(r.get(['account']));
      final outflow = ctx.amount(r.get(['outflow']) ?? '0').abs;
      final inflow = ctx.amount(r.get(['inflow']) ?? '0').abs;
      final net = inflow - outflow;
      final date = ctx.date(r.get(['date']));
      final payee = r.get(['payee']);
      final memo = r.get(['memo']);
      final currency = ctx.options.defaultCurrency;
      if (net == Amount.zero) {
        ctx.warn('Skipped a zero-amount entry');
        return null;
      }
      final transfer = RegExp(
        r'^Transfer\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(payee ?? '');
      if (transfer != null) {
        final other = transfer[1]!.trim(), outgoing = net < Amount.zero;
        return _plain(
          RawImportRow(
            date: date,
            amount: net.abs,
            type: 'transfer',
            account: outgoing ? account : other,
            destinationAccount: outgoing ? other : account,
            note: memo,
            currency: currency,
            sourceLine: ctx.line,
          ),
          account,
        );
      }
      if (payee?.toLowerCase() == 'starting balance') {
        ctx.warn('Skipped the starting balance of $account');
        return null;
      }
      var group = r.get(['categorygroup']), category = r.get(['category']);
      if (group == null && category == null) {
        (group, category) = ImportValues.categoryPath(
          r.get(['categorygroupcategory']),
        );
      }
      final row = _signed(
        ctx,
        net,
        date: date,
        account: account,
        category: group ?? category,
        subcategory: group == null ? null : category,
        payee: payee,
        note: memo,
        currency: currency,
      );
      return row == null ? null : _plain(row, account);
    },
  );

  static const _dateKeys = [
    'date', 'transactiondate', 'postingdate', 'posteddate', 'postdate', //
    'valuedate', 'bookingdate', 'transdate', 'datum', 'buchungstag',
    'fecha', 'data', 'التاريخ', 'تاريخالعملية',
  ];
  static const _descriptionKeys = [
    'description', 'details', 'transactiondetails', 'narrative', //
    'narration', 'particulars', 'payee', 'merchant', 'name', 'memo',
    'reference', 'transaction', 'beschreibung', 'verwendungszweck',
    'buchungstext', 'concepto', 'descripcion', 'البيان', 'الوصف',
  ];
  static const _amountKeys = [
    'amount', 'transactionamount', 'value', 'betrag', 'importe', //
    'montant', 'المبلغ',
  ];
  static const _debitKeys = [
    'debit', 'debitamount', 'withdrawal', 'withdrawals', 'withdrawalamt', //
    'moneyout', 'paidout', 'out', 'soll', 'cargo', 'مدين', 'سحب',
  ];
  static const _creditKeys = [
    'credit', 'creditamount', 'deposit', 'deposits', 'depositamt', //
    'moneyin', 'paidin', 'in', 'haben', 'abono', 'دائن', 'إيداع',
  ];

  /// Any bank statement CSV: a date, a description and either one signed
  /// amount or separate debit/credit columns (with an optional DR/CR
  /// indicator column for unsigned amounts).
  static final bank = CsvPreset(
    id: 'csv.bank',
    name: 'Bank statement CSV',
    verified: true,
    reference: 'Generic layout; no single source',
    signature: const [
      _dateKeys,
      _descriptionKeys,
      [..._amountKeys, ..._debitKeys, ..._creditKeys],
    ],
    priority: 0,
    dateColumns: _dateKeys,
    amountColumns: const [..._amountKeys, ..._debitKeys, ..._creditKeys],
    read: (r, ctx) {
      final debit = r.get(_debitKeys), credit = r.get(_creditKeys);
      Amount signed;
      if (r.has(_amountKeys) && r.get(_amountKeys) != null) {
        signed = ctx.amount(r.get(_amountKeys));
        final indicator = headerKey(
          r.get(['drcr', 'debitcredit', 'creditdebitindicator', 'type']) ?? '',
        );
        if (const {'dr', 'd', 'debit', 'dbit'}.contains(indicator)) {
          signed = -signed.abs;
        } else if (const {'cr', 'c', 'credit', 'crdt'}.contains(indicator)) {
          signed = signed.abs;
        }
      } else if (debit != null || credit != null) {
        final out = debit == null ? Amount.zero : ctx.amount(debit).abs;
        final inn = credit == null ? Amount.zero : ctx.amount(credit).abs;
        signed = inn - out;
      } else {
        throw const FormatException('Missing amount');
      }
      final description = r.get(_descriptionKeys);
      final detail = r.get(['memo', 'reference', 'notes', 'note']);
      final account = ctx.account(
        r.get(['account', 'accountname', 'accountnumber', 'iban']),
      );
      final (category, subcategory) = ImportValues.categoryPath(
        r.get(['category']),
      );
      final row = _signed(
        ctx,
        signed,
        date: ctx.date(r.get(_dateKeys)),
        account: account,
        category: category,
        subcategory: subcategory,
        payee: description,
        note: detail == description ? null : detail,
        currency: ctx.currency(r.get(['currency', 'ccy', 'currencycode'])),
        externalId: r.get(['transactionid', 'id', 'referencenumber', 'fitid']),
      );
      return row == null ? null : _plain(row, account);
    },
  );

  static final List<CsvPreset> all = [
    flourish,
    moneyManager,
    ynab,
    wallet,
    spendee,
    monefy,
    bank,
  ];

  /// The most specific preset whose header appears in [content].
  static CsvPreset? detect(String content) {
    final table = CsvTable.decode(content);
    final matches = all.where((p) => p.headerIndex(table) != null).toList()
      ..sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        return byPriority != 0
            ? byPriority
            : b.signature.length.compareTo(a.signature.length);
      });
    return matches.firstOrNull;
  }
}
