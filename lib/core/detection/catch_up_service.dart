import 'package:drift/drift.dart' show Variable;

import '../../data/database/database.dart';
import 'detection_service.dart';
import 'message_splitter.dart';
import 'parsed_payment.dart';
import 'payment_parser.dart';

/// A detected payment from the catch-up window that seems to be in the
/// ledger already, and the entry it matches.
typedef AlreadyRecorded = ({DetectedPayment payment, int? transactionId});

/// What a catch-up found in a batch of alerts.
class CatchUpResult {
  const CatchUpResult({
    required this.missing,
    required this.already,
    required this.older,
    required this.ignored,
    this.repeated = 0,
  });

  /// Payments that are not in Flourish yet, waiting in the inbox.
  final List<DetectedPayment> missing;

  /// Payments that match an entry already in Flourish.
  final List<AlreadyRecorded> already;

  /// Alerts dated before the window, left out.
  final int older;

  /// Codes, offers, declines and notices.
  final int ignored;

  /// Alerts Flourish had already received (same text pasted again).
  final int repeated;

  int get total => missing.length + already.length + older + ignored + repeated;
}

/// "Catch up on the last 7 days": runs pasted alerts through detection and
/// keeps only payments that are not in the ledger yet.
class CatchUpService {
  CatchUpService(this.detection);
  final DetectionService detection;
  AppDatabase get db => detection.db;

  static const window = Duration(days: 7);

  static DateTime since(DateTime now) =>
      DateTime(now.year, now.month, now.day).subtract(window);

  Future<CatchUpResult> fromText(
    String text, {
    DateTime? now,
    String source = 'catch_up',
  }) async {
    final clock = now ?? DateTime.now();
    final from = since(clock);
    final missing = <DetectedPayment>[];
    final already = <AlreadyRecorded>[];
    var older = 0, ignored = 0, repeated = 0;
    // Each ledger entry accounts for one alert at most: two 45 EGP coffees
    // and one entered by hand leave one missing.
    final used = <int>{};

    for (final message in MessageSplitter.split(text)) {
      final raw = RawMessage(text: message, receivedAt: clock, source: source);
      final parsed = PaymentMessageParser.parse(raw);
      if (parsed.ignored) {
        ignored++;
        continue;
      }
      final at = parsed.occurredAt ?? clock;
      // The parser falls back to the paste time when the alert has no date,
      // so an undated alert could be from any day in the window.
      final dated = parsed.occurredAt != null && parsed.occurredAt != clock;
      if (at.isBefore(from)) {
        older++;
        continue;
      }
      final row = await detection.ingest(raw);
      if (row == null) {
        repeated++;
        continue;
      }
      if (row.duplicateOfId != null) {
        already.add((payment: row, transactionId: null));
        continue;
      }
      final match = await _ledgerMatch(
        row,
        parsed,
        from: dated ? at.subtract(const Duration(days: 1)) : from,
        to: dated ? at.add(const Duration(days: 1)) : clock,
        used: used,
      );
      if (match != null) {
        used.add(match);
        already.add((payment: row, transactionId: match));
      } else {
        missing.add(row);
      }
    }
    return CatchUpResult(
      missing: missing,
      already: already,
      older: older,
      ignored: ignored,
      repeated: repeated,
    );
  }

  /// An entry already in the ledger for this payment: same type and amount,
  /// in its account (or, when the account is unknown, any account of its
  /// currency), between [from] and [to], and not matched to another alert.
  Future<int?> _ledgerMatch(
    DetectedPayment row,
    ParsedPayment p, {
    required DateTime from,
    required DateTime to,
    required Set<int> used,
  }) async {
    if (p.amount == null) return null;
    final type = p.kind == 'refund' ? 'income' : p.direction;
    final rows = await db
        .customSelect(
          'SELECT t.id FROM transactions t JOIN accounts a ON a.id = t.account_id '
          'WHERE t.type = ? AND ABS(t.amount - ?) < 0.005 '
          'AND (? IS NULL OR t.account_id = ?) '
          'AND (? IS NOT NULL OR ? IS NULL OR a.currency = ?) '
          'AND t.transaction_date BETWEEN ? AND ? '
          'ORDER BY t.transaction_date DESC',
          variables: [
            Variable(type),
            Variable(p.amount!.toDouble()),
            Variable(row.accountId),
            Variable(row.accountId),
            Variable(row.accountId),
            Variable(p.currency),
            Variable(p.currency),
            Variable(from),
            Variable(to),
          ],
        )
        .get();
    for (final r in rows) {
      final id = r.read<int>('id');
      if (!used.contains(id)) return id;
    }
    return null;
  }

  /// Marks payments the person agrees are already recorded, so they leave
  /// the inbox without adding anything.
  Future<void> markRecorded(Iterable<AlreadyRecorded> rows) async {
    for (final r in rows) {
      if (r.transactionId != null) {
        await detection.link(r.payment.id, r.transactionId!);
      } else {
        await detection.dismiss(r.payment.id);
      }
    }
  }
}
