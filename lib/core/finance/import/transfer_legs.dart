import '../../../domain/finance/amount.dart';
import 'import_source.dart';

/// A row plus the account whose register it was read from. Exports that
/// cover several accounts list each transfer once per account; knowing
/// where a leg was recorded is what tells a mirror leg from a second,
/// genuine transfer.
typedef RecordedRow = ({RawImportRow row, String? recordedIn});

/// One transfer per movement: a transfer row that matches an earlier one
/// (same day, amount, currency, source and destination) but was recorded in
/// a different account is the other side of it and is dropped with a
/// warning. Other rows pass through untouched.
List<RawImportRow> mergeMirroredTransfers(
  Iterable<RecordedRow> legs,
  List<ImportIssue> warnings,
) {
  final open = <String, List<RecordedRow>>{};
  final out = <RawImportRow>[];
  for (final leg in legs) {
    final row = leg.row;
    if (row.type != 'transfer') {
      out.add(row);
      continue;
    }
    final key = _key(row, row.account, row.destinationAccount);
    final waiting = open[key] ??= [];
    final mirror = waiting.indexWhere(
      (w) =>
          w.recordedIn != null &&
          leg.recordedIn != null &&
          w.recordedIn != leg.recordedIn,
    );
    if (mirror >= 0) {
      final kept = waiting.removeAt(mirror).row;
      warnings.add(
        ImportIssue(
          row.sourceLine,
          'Skipped the other side of the transfer on line ${kept.sourceLine}',
        ),
      );
      continue;
    }
    waiting.add(leg);
    out.add(row);
  }
  return out;
}

/// For exports that mark transfer legs without naming the other account
/// (Wallet, Spendee): an outgoing leg and an incoming leg on the same day
/// with the same amount and currency in different accounts become one
/// transfer. [legs] are signed: an `expense` row is the outgoing side.
/// Unmatched legs stay as income/expense with a warning.
List<RawImportRow> pairTransferLegs(
  List<RawImportRow> rows,
  Set<RawImportRow> legs,
  List<ImportIssue> warnings,
) {
  final consumed = <RawImportRow>{};
  final merged = <RawImportRow, RawImportRow>{};
  final incoming = rows.where((r) => legs.contains(r) && r.type == 'income');
  for (final out in rows.where(
    (r) => legs.contains(r) && r.type == 'expense',
  )) {
    final match = incoming
        .where(
          (i) =>
              !consumed.contains(i) &&
              _day(i.date) == _day(out.date) &&
              i.amount == out.amount &&
              i.currency == out.currency &&
              i.account != out.account,
        )
        .firstOrNull;
    if (match == null) continue;
    consumed
      ..add(match)
      ..add(out);
    merged[out] = RawImportRow(
      date: out.date,
      amount: out.amount,
      type: 'transfer',
      account: out.account,
      destinationAccount: match.account,
      payee: out.payee ?? match.payee,
      note: out.note ?? match.note,
      currency: out.currency,
      externalId: out.externalId,
      sourceLine: out.sourceLine,
    );
  }
  final result = <RawImportRow>[];
  for (final row in rows) {
    if (merged[row] case final transfer?) {
      result.add(transfer);
    } else if (consumed.contains(row)) {
      continue;
    } else {
      if (legs.contains(row)) {
        warnings.add(
          ImportIssue(
            row.sourceLine,
            'Transfer has no matching leg in another account; '
            'imported as ${row.type}',
          ),
        );
      }
      result.add(row);
    }
  }
  return result;
}

String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _key(RawImportRow row, String? from, String? to) =>
    '${_day(row.date)}|${row.amount}|${row.currency}|$from|$to';

/// Sum of amounts by type, handy for previews and tests.
Map<String, Amount> totalsByType(Iterable<RawImportRow> rows) {
  final totals = <String, Amount>{};
  for (final r in rows) {
    totals[r.type] = (totals[r.type] ?? Amount.zero) + r.amount;
  }
  return totals;
}
