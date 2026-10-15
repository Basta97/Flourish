import 'package:drift/drift.dart';
import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import '../utils/error_text.dart';
import 'financial_ledger_service.dart';

/// Posts recurring rules and the monthly auto-income through the ledger, so
/// generated entries get the same validation, FX snapshot and balance handling
/// as manual ones.
class RecurringService {
  final FinancialLedgerService ledger;
  RecurringService(this.ledger);

  AppDatabase get db => ledger.db;
  FinanceStore get store => ledger.store;

  static const frequencies = ['daily', 'weekly', 'monthly', 'yearly'];

  /// The occurrence after [current], keeping month-end rules on their
  /// original day (31st → Feb 28 → Mar 31).
  static DateTime following(
    DateTime current,
    String frequency,
    DateTime anchor,
  ) {
    var next = AppDatabase.nextRecurringDate(
      current: current,
      frequency: frequency,
    );
    if (frequency == 'monthly' || frequency == 'yearly') {
      final last = DateTime(next.year, next.month + 1, 0).day;
      next = DateTime(
        next.year,
        next.month,
        anchor.day > last ? last : anchor.day,
        anchor.hour,
        anchor.minute,
      );
    }
    if (!next.isAfter(current)) {
      throw StateError('Recurring date did not advance');
    }
    return next;
  }

  /// Occurrences from [start] up to and including [until].
  static List<DateTime> occurrences(
    DateTime start,
    String frequency,
    DateTime until, {
    int limit = 1000,
  }) {
    final dates = <DateTime>[];
    var current = start;
    while (!current.isAfter(until) && dates.length < limit) {
      dates.add(current);
      current = following(current, frequency, start);
    }
    return dates;
  }

  /// The first occurrence strictly after [now], used when a rule resumes or
  /// starts without catching up past periods.
  static DateTime nextAfter(
    DateTime start,
    String frequency,
    DateTime now,
    DateTime anchor,
  ) {
    var current = start;
    while (!current.isAfter(now)) {
      current = following(current, frequency, anchor);
    }
    return current;
  }

  Future<DateTime> _anchor(RecurringTransaction r) async {
    final stored = await store.get('recurringAnchors', '${r.id}');
    if (stored != null) return DateTime.parse(stored['date'] as String);
    await store.put('recurringAnchors', '${r.id}', {
      'date': r.nextDate.toIso8601String(),
    }, notify: false);
    return r.nextDate;
  }

  /// Posts every due occurrence. Each rule is processed in its own
  /// transaction; a rule that cannot post (archived account, removed
  /// category, unsupported frequency) is skipped and reported through
  /// [warnings] instead of blocking every other rule.
  Future<void> processDue({DateTime? now}) async {
    final until = now ?? DateTime.now();
    for (final due in await db.getDueRecurringTransactions(until)) {
      try {
        await db.transaction(() async {
          // Re-read inside the transaction so concurrent runs never post twice.
          var r = await (db.select(
            db.recurringTransactions,
          )..where((t) => t.id.equals(due.id))).getSingleOrNull();
          if (r == null) return;
          if (!frequencies.contains(r.frequency)) {
            throw StateError('Unsupported recurring frequency');
          }
          final anchor = await _anchor(r);
          while (r!.isActive && !r.nextDate.isAfter(until)) {
            if (r.endDate != null && r.nextDate.isAfter(r.endDate!)) {
              r = r.copyWith(isActive: false);
              await db.updateRecurringTransaction(r);
              break;
            }
            await _post(r);
            r = r.copyWith(
              nextDate: following(r.nextDate, r.frequency, anchor),
            );
            if (r.endDate != null && r.nextDate.isAfter(r.endDate!)) {
              r = r.copyWith(isActive: false);
            }
            await db.updateRecurringTransaction(r);
          }
        });
        await store.remove('recurringWarnings', '${due.id}');
      } catch (e) {
        await store.put('recurringWarnings', '${due.id}', {
          'recurringId': due.id,
          'message': describeError(e),
          'date': until.toIso8601String(),
        });
      }
    }
  }

  Future<void> _post(RecurringTransaction r) async {
    final note = r.note ?? 'Recurring: ${r.frequency}';
    if (r.type == 'transfer') {
      await ledger.transfer(
        fromAccountId: r.accountId,
        toAccountId: r.toAccountId!,
        amount: Amount.fromNum(r.amount),
        received: r.toAmount == null ? null : Amount.fromNum(r.toAmount!),
        note: note,
        date: r.nextDate,
      );
      return;
    }
    await ledger.recordCash(
      accountId: r.accountId,
      amount: Amount.fromNum(r.amount),
      type: r.type,
      categoryId: r.categoryId,
      note: note,
      date: r.nextDate,
      instrumentId: r.paymentInstrumentId,
      source: 'recurring',
      extra: {'recurringId': r.id},
    );
  }

  /// Rule id → reason it could not post last time.
  Future<Map<int, String>> warnings() async => {
    for (final w in await store.list('recurringWarnings'))
      w['recurringId'] as int: w['message'] as String,
  };

  /// Pauses or resumes a rule. Resuming continues from the next future date;
  /// the periods skipped while paused are never back-filled.
  Future<void> setActive(
    RecurringTransaction rule,
    bool active, {
    DateTime? now,
  }) => db.transaction(() async {
    var next = rule.nextDate;
    if (active && !rule.isActive) {
      final anchor = await _anchor(rule);
      next = nextAfter(
        rule.nextDate,
        rule.frequency,
        now ?? DateTime.now(),
        anchor,
      );
    }
    await db.updateRecurringTransaction(
      rule.copyWith(isActive: active, nextDate: next),
    );
    if (!active) await store.remove('recurringWarnings', '${rule.id}');
  });

  /// Creates a rule. When [firstDate] is in the past, [catchUp] decides
  /// whether the missed occurrences are posted or the rule starts at its next
  /// future date.
  Future<int> create(
    RecurringTransactionsCompanion entry, {
    bool catchUp = false,
    DateTime? now,
  }) => db.transaction(() async {
    _validate(entry.amount.value, entry.frequency.value);
    _validateTransfer(
      entry.type.value,
      entry.accountId.value,
      entry.toAccountId.present ? entry.toAccountId.value : null,
    );
    final start = entry.nextDate.value;
    final next = catchUp || !start.isBefore(now ?? DateTime.now())
        ? start
        : nextAfter(start, entry.frequency.value, now ?? DateTime.now(), start);
    final id = await db.insertRecurringTransaction(
      entry.copyWith(nextDate: Value(next)),
    );
    await store.put('recurringAnchors', '$id', {
      'date': start.toIso8601String(),
    }, notify: false);
    return id;
  });

  /// Edits a rule's amount, category, note, account or schedule.
  Future<void> update(RecurringTransaction rule) => db.transaction(() async {
    _validate(rule.amount, rule.frequency);
    _validateTransfer(rule.type, rule.accountId, rule.toAccountId);
    final existing = await (db.select(
      db.recurringTransactions,
    )..where((t) => t.id.equals(rule.id))).getSingleOrNull();
    if (existing == null) throw StateError('Recurring rule no longer exists');
    await db.updateRecurringTransaction(rule);
    if (existing.nextDate != rule.nextDate ||
        existing.frequency != rule.frequency) {
      await store.put('recurringAnchors', '${rule.id}', {
        'date': rule.nextDate.toIso8601String(),
      }, notify: false);
    }
    await store.remove('recurringWarnings', '${rule.id}');
  });

  Future<void> delete(int id) => db.transaction(() async {
    await db.deleteRecurringTransaction(id);
    await store.remove('recurringAnchors', '$id');
    await store.remove('recurringWarnings', '$id');
  });

  void _validateTransfer(String type, int from, int? to) {
    if ((type == 'transfer') != (to != null)) {
      throw const TransactionLogicException(
        'Choose a destination account for a recurring transfer',
      );
    }
    if (to == from) {
      throw const TransactionLogicException(
        'Transfer source and destination must be different',
      );
    }
  }

  void _validate(double amount, String frequency) {
    if (!amount.isFinite || amount <= 0) {
      throw const TransactionLogicException('Enter a positive amount');
    }
    if (!frequencies.contains(frequency)) {
      throw const TransactionLogicException('Choose a supported frequency');
    }
  }

  /// Posts the configured monthly income for every month since the last one
  /// posted (at most 12), once per month even across repeated runs.
  Future<void> processAutoIncome({
    required Amount amount,
    required int accountId,
    required int categoryId,
    required int day,
    String? lastPostedMonth,
    DateTime? now,
  }) async {
    if (amount <= Amount.zero) return;
    final today = now ?? DateTime.now();
    var month = DateTime(today.year, today.month);
    if (lastPostedMonth != null) {
      final parts = lastPostedMonth.split('-').map(int.parse).toList();
      final after = DateTime(parts[0], parts[1] + 1);
      final earliest = DateTime(today.year, today.month - 11);
      month = after.isBefore(earliest) ? earliest : after;
    }
    for (
      ;
      !month.isAfter(today);
      month = DateTime(month.year, month.month + 1)
    ) {
      final last = DateTime(month.year, month.month + 1, 0).day;
      final date = DateTime(month.year, month.month, day.clamp(1, last));
      if (date.isAfter(today)) break;
      final key = '${month.year}-${month.month}';
      await db.transaction(() async {
        if (await store.get('autoIncome', key) != null) return;
        // Entries posted before this record existed are matched by note.
        final legacy = (await db.getTransactionsByAccount(accountId)).any(
          (t) =>
              t.note == 'Auto monthly income' &&
              t.transactionDate.year == month.year &&
              t.transactionDate.month == month.month,
        );
        final id = legacy
            ? null
            : await ledger.recordCash(
                accountId: accountId,
                amount: amount,
                type: 'income',
                categoryId: categoryId,
                note: 'Auto monthly income',
                date: date,
                source: 'auto_income',
              );
        await store.put('autoIncome', key, {'month': key, 'transactionId': id});
      });
    }
  }
}
