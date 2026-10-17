import '../../../domain/finance/amount.dart';
import 'import_source.dart';
import 'import_values.dart';
import 'transfer_legs.dart';

/// Quicken Interchange Format: `!Type:Bank|Cash|CCard|Oth A|Oth L`
/// registers, optionally preceded by `!Account` blocks naming the account.
/// `L[Other account]` is a transfer, `LParent:Child` a subcategory and
/// `S`/`E`/`$` lines are splits.
final class QifSource implements ImportSource {
  const QifSource();

  @override
  String get id => 'qif';
  @override
  String get name => 'QIF (Quicken)';

  static const _registers = {'bank', 'cash', 'ccard', 'oth a', 'oth l'};

  @override
  bool canRead(String fileName, String headOfFile) {
    if (fileName.toLowerCase().endsWith('.qif')) return true;
    final head = headOfFile.replaceFirst('﻿', '').trimLeft();
    return RegExp(
      r'^!(Type:|Account|Option:)',
      caseSensitive: false,
    ).hasMatch(head);
  }

  @override
  ImportParseResult parse(
    String content, {
    ImportOptions options = const ImportOptions(),
  }) {
    final lines = content.replaceFirst('﻿', '').split(RegExp(r'\r\n?|\n'));
    final errors = <ImportIssue>[], warnings = <ImportIssue>[];
    final order =
        options.dateOrder ??
        ImportValues.detectDateOrder(
          lines.where((l) => l.startsWith('D')).map((l) => l.substring(1)),
        ) ??
        DateOrder.mdy;
    final decimal =
        options.decimalSeparator ??
        ImportValues.detectDecimalSeparator(
          lines
              .where((l) => l.startsWith(RegExp(r'[TU$]')))
              .map((l) => l.substring(1)),
        );

    final legs = <RecordedRow>[];
    var mode = _Mode.transactions;
    String? account = options.defaultAccount;
    String? pendingAccount;
    var record = _Record(1);
    var warnedInvestments = false;

    void finish() {
      if (record.isEmpty) return;
      if (mode == _Mode.account) {
        if (pendingAccount != null) account = pendingAccount;
      } else if (mode == _Mode.transactions) {
        try {
          for (final row in record.toRows(
            account: account,
            order: order,
            options: options,
            decimal: decimal,
            warnings: warnings,
          )) {
            legs.add((row: row, recordedIn: account));
          }
        } on FormatException catch (e) {
          errors.add(ImportIssue(record.line, e.message));
        }
      }
      pendingAccount = null;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      final number = i + 1;
      if (line.trim().isEmpty) continue;
      if (record.isEmpty) record = _Record(number);
      if (line.startsWith('!')) {
        finish();
        record = _Record(number + 1);
        final header = line.substring(1).trim().toLowerCase();
        if (header == 'account') {
          mode = _Mode.account;
        } else if (header.startsWith('type:')) {
          final type = header.substring(5).trim();
          if (_registers.contains(type)) {
            mode = _Mode.transactions;
          } else {
            mode = _Mode.skip;
            if (type.startsWith('invst') && !warnedInvestments) {
              warnedInvestments = true;
              warnings.add(
                ImportIssue(number, 'Investment registers are not imported'),
              );
            }
          }
        }
        // !Option:AutoSwitch / !Clear:AutoSwitch only bracket account lists.
        continue;
      }
      if (line.trim() == '^') {
        finish();
        record = _Record(number + 1);
        continue;
      }
      final code = line[0], value = line.substring(1).trim();
      if (mode == _Mode.account) {
        if (code == 'N') pendingAccount = ImportValues.text(value);
        record.touched = true;
      } else if (mode == _Mode.transactions) {
        record.add(code, value);
      }
    }
    finish();
    final rows = mergeMirroredTransfers(legs, warnings);
    return ImportParseResult(id, rows, errors: errors, warnings: warnings);
  }
}

enum _Mode { transactions, account, skip }

final class _Split {
  String? category, memo, amount;
}

final class _Record {
  final int line;
  bool touched = false;
  String? date, amount, payee, memo, category;
  final splits = <_Split>[];
  _Record(this.line);

  bool get isEmpty => !touched;

  void add(String code, String value) {
    touched = true;
    switch (code) {
      case 'D':
        date = value;
      case 'T':
        amount = value;
      case 'U':
        amount ??= value;
      case 'P':
        payee = value;
      case 'M':
        memo = value;
      case 'L':
        category = value;
      case 'S':
        splits.add(_Split()..category = value);
      case 'E':
        (splits.isEmpty ? (splits..add(_Split())) : splits).last.memo = value;
      case r'$':
        (splits.isEmpty ? (splits..add(_Split())) : splits).last.amount = value;
      // N (number), C (cleared), A (address), % (split percent) are not kept.
    }
  }

  List<RawImportRow> toRows({
    required String? account,
    required DateOrder order,
    required ImportOptions options,
    required String? decimal,
    required List<ImportIssue> warnings,
  }) {
    if (date == null) throw const FormatException('Entry has no date (D)');
    final when = ImportValues.date(
      date!,
      pattern: options.dateFormat,
      order: order,
    );
    Amount parse(String raw) =>
        ImportValues.amount(raw, decimalSeparator: decimal);
    final total = amount == null ? null : parse(amount!);
    final usable = splits.where((s) => s.amount != null).toList();
    if (options.expandSplits && usable.isNotEmpty) {
      final parts = [for (final s in usable) parse(s.amount!)];
      final sum = parts.fold(Amount.zero, (a, b) => a + b);
      if (total != null && sum != total) {
        warnings.add(
          ImportIssue(line, 'Splits add up to $sum but the total is $total'),
        );
      }
      return [
        for (var i = 0; i < usable.length; i++)
          ?_row(
            when,
            parts[i],
            usable[i].category ?? category,
            usable[i].memo ?? memo,
            account,
            options,
            warnings,
          ),
      ];
    }
    if (total == null) throw const FormatException('Entry has no amount (T)');
    final row = _row(
      when,
      total,
      category ?? splits.firstOrNull?.category,
      memo,
      account,
      options,
      warnings,
    );
    return [?row];
  }

  RawImportRow? _row(
    DateTime when,
    Amount signed,
    String? rawCategory,
    String? note,
    String? account,
    ImportOptions options,
    List<ImportIssue> warnings,
  ) {
    if (signed == Amount.zero) {
      warnings.add(ImportIssue(line, 'Skipped a zero-amount entry'));
      return null;
    }
    // A trailing /Class tags the entry with a Quicken class; it is dropped.
    var cat = ImportValues.text(rawCategory);
    if (cat != null) {
      final slash = cat.startsWith('[')
          ? cat.indexOf('/', cat.indexOf(']'))
          : cat.indexOf('/');
      if (slash >= 0) cat = ImportValues.text(cat.substring(0, slash));
    }
    final transfer = cat == null
        ? null
        : RegExp(r'^\[(.+)\]$').firstMatch(cat)?.group(1)?.trim();
    final common = (
      payee: ImportValues.text(payee),
      note: ImportValues.text(note),
      currency: options.defaultCurrency,
    );
    if (transfer != null) {
      if (transfer == account ||
          payee?.trim().toLowerCase() == 'opening balance') {
        warnings.add(
          ImportIssue(line, 'Skipped the opening balance of $transfer'),
        );
        return null;
      }
      final outgoing = signed < Amount.zero;
      return RawImportRow(
        date: when,
        amount: signed.abs,
        type: 'transfer',
        account: outgoing ? account : transfer,
        destinationAccount: outgoing ? transfer : account,
        payee: common.payee,
        note: common.note,
        currency: common.currency,
        sourceLine: line,
      );
    }
    final (category, subcategory) = ImportValues.categoryPath(cat);
    return RawImportRow(
      date: when,
      amount: signed.abs,
      type: signed < Amount.zero ? 'expense' : 'income',
      account: account,
      category: category,
      subcategory: subcategory,
      payee: common.payee,
      note: common.note,
      currency: common.currency,
      sourceLine: line,
    );
  }
}
