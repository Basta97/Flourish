import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import '../finance/financial_ledger_service.dart';
import '../finance/system_categories.dart';
import '../services/category_suggester.dart';
import '../utils/fingerprint.dart';
import 'issuers.dart';
import 'normalizer.dart';
import 'parsed_payment.dart';
import 'payment_parser.dart';
import 'redact.dart';

/// What the person may change before confirming a detected payment.
class DetectionDraft {
  final int? accountId, categoryId, toAccountId, fromAccountId, instrumentId;
  final Amount? amount;
  final String? merchant;
  final DateTime? date;
  const DetectionDraft({
    this.accountId,
    this.categoryId,
    this.toAccountId,
    this.fromAccountId,
    this.instrumentId,
    this.amount,
    this.merchant,
    this.date,
  });
}

class ConfirmResult {
  final int transactionId;

  /// Message balance minus the account's balance after booking, when the
  /// message stated one and they differ.
  final Amount? balanceDifference;
  const ConfirmResult(this.transactionId, this.balanceDifference);
}

/// Turns bank and wallet messages into pending payments, matches them to
/// accounts, cards and categories, and books them through the ledger once
/// confirmed. Everything stays on the device.
class DetectionService {
  final FinancialLedgerService ledger;
  DetectionService(this.ledger);
  AppDatabase get db => ledger.db;
  FinanceStore get store => ledger.store;

  static const _window = Duration(minutes: 15);

  /// Parses and stores [message]. Returns null when it is not a payment or
  /// was already received.
  Future<DetectedPayment?> ingest(
    RawMessage message, {
    bool autoConfirm = false,
  }) async {
    final cleaned = MessageNormalizer.clean(message.text);
    final parsed = PaymentMessageParser.parse(message);
    if (parsed.ignored) {
      final key = parsed.ignoreReason!;
      final stats = await store.get('detectionStats', key);
      await store.put('detectionStats', key, {
        'reason': key,
        'count': ((stats?['count'] as int?) ?? 0) + 1,
      }, notify: false);
      return null;
    }
    final minute = message.receivedAt.toUtc();
    final print = await fingerprint(
      '${message.source}|${message.sender ?? ''}|$cleaned|'
      '${DateTime.utc(minute.year, minute.month, minute.day, minute.hour, minute.minute)}',
    );
    final known = await (db.select(
      db.detectedPayments,
    )..where((d) => d.fingerprint.equals(print))).getSingleOrNull();
    if (known != null) return null;

    final occurred = parsed.occurredAt ?? message.receivedAt;
    final match = await _matchAccount(parsed);
    final duplicateOf = await _crossChannelDuplicate(parsed, occurred);
    final account = match.accountId == null
        ? null
        : await db.getAccountById(match.accountId!);
    final category = await _category(parsed, account);
    final existing = account == null
        ? null
        : await _existingEntry(parsed, account, occurred);

    final id = await db
        .into(db.detectedPayments)
        .insert(
          DetectedPaymentsCompanion.insert(
            fingerprint: print,
            source: message.source,
            sender: Value(message.sender),
            packageName: Value(message.packageName),
            rawText: Value(redact(cleaned)),
            receivedAt: message.receivedAt,
            parsed: jsonEncode(parsed.toJson()),
            parserVersion: ParsedPayment.version,
            amount: Value(parsed.amount?.toString()),
            currency: Value(parsed.currency),
            direction: parsed.direction,
            kind: Value(parsed.kind),
            merchant: Value(parsed.merchant ?? parsed.counterparty),
            last4: Value(parsed.last4),
            occurredAt: Value(occurred),
            balanceAfter: Value(parsed.balanceAfter?.toString()),
            accountId: Value(match.accountId),
            instrumentId: Value(match.instrumentId),
            categoryId: Value(category),
            confidence: parsed.confidence,
            status: Value(duplicateOf == null ? 'pending' : 'duplicate'),
            duplicateOfId: Value(duplicateOf),
            matchTransactionId: Value(existing),
          ),
        );
    db.notifyFinanceChanged();
    var row = (await get(id))!;
    if (autoConfirm && await _autoConfirmable(row, parsed, match)) {
      try {
        await confirm(row.id, auto: true);
        row = (await get(id))!;
      } catch (_) {
        // Anything unexpected waits for review instead.
      }
    }
    return row;
  }

  Future<DetectedPayment?> get(int id) => (db.select(
    db.detectedPayments,
  )..where((d) => d.id.equals(id))).getSingleOrNull();

  Stream<List<DetectedPayment>> watch() =>
      (db.select(db.detectedPayments)..orderBy([
            (d) =>
                OrderingTerm(expression: d.receivedAt, mode: OrderingMode.desc),
          ]))
          .watch();

  Stream<int> watchPendingCount() {
    final count = db.detectedPayments.id.count();
    return (db.selectOnly(db.detectedPayments)
          ..addColumns([count])
          ..where(db.detectedPayments.status.equals('pending')))
        .map((r) => r.read(count) ?? 0)
        .watchSingle();
  }

  ParsedPayment parsedOf(DetectedPayment row) =>
      ParsedPayment.fromJson(jsonDecode(row.parsed) as Json);

  /// Card by last 4 (and issuer), else the issuer's only account, else the
  /// only account that could have sent this kind of message.
  Future<({int? accountId, int? instrumentId, bool byCard})> _matchAccount(
    ParsedPayment p,
  ) async {
    final instruments = (await db.getPaymentInstruments())
        .where((i) => !i.archived)
        .toList();
    if (p.last4 != null) {
      var cards = instruments.where((i) => i.last4 == p.last4).toList();
      if (cards.length > 1 && p.issuerId != null) {
        cards = cards.where((i) => i.issuer == p.issuerId).toList();
      }
      if (cards.length == 1) {
        return (
          accountId: cards.single.accountId,
          instrumentId: cards.single.id,
          byCard: true,
        );
      }
    }
    final accounts = await db.getAllAccounts();
    final active = <Account>[];
    for (final a in accounts) {
      final details = await store.get('accountDetails', '${a.id}');
      if (details?['archived'] != true) active.add(a);
    }
    if (p.issuerId != null) {
      final issuer = Issuers.byId(p.issuerId);
      final byInstrument = instruments
          .where((i) => i.issuer == p.issuerId)
          .map((i) => i.accountId)
          .toSet();
      final byInstitution = <int>{};
      for (final a in active) {
        final institution =
            (await store.get('accountDetails', '${a.id}'))?['institution']
                as String?;
        if (issuer != null &&
            institution != null &&
            institution.isNotEmpty &&
            (issuer.matchesSender(institution) ||
                institution.toLowerCase() == issuer.name.toLowerCase())) {
          byInstitution.add(a.id);
        }
      }
      final candidates = {...byInstrument, ...byInstitution};
      if (candidates.length == 1) {
        final accountId = candidates.single;
        final cards = instruments
            .where((i) => i.accountId == accountId && i.issuer == p.issuerId)
            .toList();
        return (
          accountId: accountId,
          instrumentId: cards.length == 1 ? cards.single.id : null,
          byCard: false,
        );
      }
      if (issuer?.kind == 'wallet') {
        final wallets = active.where((a) => a.type == 'ewallet').toList();
        if (wallets.length == 1) {
          return (
            accountId: wallets.single.id,
            instrumentId: null,
            byCard: false,
          );
        }
      }
    }
    final eligible = active.where((a) => a.type != 'cash').toList();
    if (eligible.length == 1) {
      return (accountId: eligible.single.id, instrumentId: null, byCard: false);
    }
    return (accountId: null, instrumentId: null, byCard: false);
  }

  /// The same payment often arrives twice: as an SMS and as a bank-app
  /// notification. Two identical purchases further apart stay separate.
  Future<int?> _crossChannelDuplicate(ParsedPayment p, DateTime when) async {
    if (p.amount == null) return null;
    final near =
        await (db.select(db.detectedPayments)..where(
              (d) =>
                  d.amount.equals(p.amount.toString()) &
                  d.currency.equalsNullable(p.currency) &
                  d.status.isIn(['pending', 'confirmed']) &
                  d.occurredAt.isBetweenValues(
                    when.subtract(_window),
                    when.add(_window),
                  ),
            ))
            .get();
    for (final other in near) {
      final o = parsedOf(other);
      final sameCard = p.last4 != null && o.last4 == p.last4;
      final sameIssuer = p.issuerId != null && o.issuerId == p.issuerId;
      final unknown =
          (p.last4 == null || o.last4 == null) &&
          (p.issuerId == null || o.issuerId == null);
      if (o.direction == p.direction && (sameCard || sameIssuer || unknown)) {
        return other.id;
      }
    }
    return null;
  }

  static String _ruleKey(String merchant) => MessageNormalizer.fold(
    MessageNormalizer.clean(merchant),
  ).replaceAll(RegExp(r'[^a-z0-9؀-ۿ]+'), ' ').trim();

  Future<int?> _category(ParsedPayment p, Account? account) async {
    final type = switch (p.kind) {
      'refund' => 'expense',
      _ => p.direction,
    };
    if ([
      'transfer_out',
      'transfer_in',
      'withdrawal',
      'card_payment',
    ].contains(p.kind)) {
      return null;
    }
    final merchant = p.merchant ?? p.counterparty;
    if (merchant != null) {
      final rule = await store.get('merchantRules', _ruleKey(merchant));
      final id = rule?['categoryId'] as int?;
      if (id != null) {
        final c = await db.getCategoryById(id);
        if (c != null && c.type == type) return id;
      }
    }
    final categories = SystemCategories.pickable(await db.getAllCategories());
    final recent = (await db.getAllTransactions()).take(500).toList();
    final suggested = CategorySuggester.suggest(
      '${merchant ?? ''} ${p.kind ?? ''}',
      recent,
      categories: categories,
      type: type,
    );
    if (suggested != null) return suggested;
    return (await db.fallbackCategoryFor(type)).id;
  }

  /// A manual entry that probably records the same payment.
  Future<int?> _existingEntry(
    ParsedPayment p,
    Account account,
    DateTime when,
  ) async {
    final amount = p.currency == null || p.currency == account.currency
        ? p.amount
        : p.bookedCurrency == account.currency
        ? p.bookedAmount
        : null;
    if (amount == null) return null;
    final type = p.direction;
    for (final t in await db.getTransactionsByAccount(account.id)) {
      if (t.type != type || (t.source ?? 'manual') == 'detected') continue;
      if (t.transactionDate.difference(when).abs() > const Duration(days: 1)) {
        continue;
      }
      final details = await store.transactionDetails(t.id);
      final exact = details?['amount'] == null
          ? Amount.fromNum(t.amount)
          : amountOf(details!['amount']);
      if (exact == amount) return t.id;
    }
    return null;
  }

  Future<bool> _autoConfirmable(
    DetectedPayment row,
    ParsedPayment p,
    ({int? accountId, int? instrumentId, bool byCard}) match,
  ) async {
    if (row.status != 'pending' ||
        row.matchTransactionId != null ||
        !match.byCard ||
        p.issuerId == null ||
        p.confidence < 0.9 ||
        !['purchase', 'refund'].contains(p.kind) ||
        row.categoryId == null) {
      return false;
    }
    final account = await db.getAccountById(match.accountId!);
    if (account == null) return false;
    return p.currency == null ||
        p.currency == account.currency ||
        p.bookedCurrency == account.currency;
  }

  /// Books the payment and returns the new entry. [draft] holds anything
  /// the person changed.
  Future<ConfirmResult> confirm(
    int id, {
    DetectionDraft draft = const DetectionDraft(),
    bool auto = false,
  }) => db.transaction(() async {
    final row = await get(id);
    if (row == null) throw StateError('This payment is no longer in the inbox');
    if (row.status == 'confirmed') {
      throw StateError('This payment was already added');
    }
    final p = parsedOf(row);
    final accountId = draft.accountId ?? row.accountId;
    if (accountId == null) throw ArgumentError('Choose the account it used');
    final account = await db.getAccountById(accountId);
    if (account == null) throw StateError('Account no longer exists');
    final instrumentId =
        draft.instrumentId ??
        (accountId == row.accountId ? row.instrumentId : null);
    final date = draft.date ?? row.occurredAt ?? row.receivedAt;
    final merchant = draft.merchant ?? row.merchant;
    final note = _note(p);
    final foreign = p.currency != null && p.currency != account.currency;
    var amount = draft.amount;
    if (amount == null) {
      if (!foreign) {
        amount = p.amount;
      } else if (p.bookedCurrency == account.currency) {
        amount = p.bookedAmount;
      }
    }
    if (amount == null) {
      throw ArgumentError(
        'Enter what ${account.name} was charged in ${account.currency}',
      );
    }
    final categoryId = draft.categoryId ?? row.categoryId;
    int transactionId;
    switch (p.kind) {
      case 'withdrawal' || 'transfer_out' || 'card_payment'
          when draft.toAccountId != null || _impliesOwnAccount(p, account):
        final to = draft.toAccountId ?? await _ownDestination(p, account);
        if (to == null) {
          throw ArgumentError('Choose the account the money went to');
        }
        transactionId = await _transfer(
          from: account.id,
          to: to,
          amount: amount,
          date: date,
          note: note,
        );
      case 'transfer_in' || 'deposit' || 'card_payment'
          when draft.fromAccountId != null ||
              (p.kind == 'card_payment' && account.type == 'credit'):
        final from = draft.fromAccountId ?? await _payingAccount(account);
        if (from == null) {
          throw ArgumentError('Choose the account the payment came from');
        }
        transactionId = await _transfer(
          from: from,
          to: account.id,
          amount: amount,
          date: date,
          note: note,
        );
      case 'refund':
        transactionId = await ledger.recordRefund(
          accountId: account.id,
          amount: amount,
          expenseCategoryId:
              categoryId ?? (await db.fallbackCategoryFor('expense')).id,
          instrumentId: instrumentId,
          merchant: merchant,
          note: note,
          date: date,
          source: 'detected',
          sourceRef: row.fingerprint,
        );
      default:
        final type = p.direction;
        final category = categoryId ?? (await db.fallbackCategoryFor(type)).id;
        if (type == 'expense' && foreign && p.amount != null) {
          transactionId = await ledger.recordPurchase(
            accountId: account.id,
            amount: amount,
            categoryId: category,
            original: Money('${p.amount}', p.currency!),
            fxFeePercent: Amount.zero,
            instrumentId: instrumentId,
            merchant: merchant,
            note: note,
            date: date,
            source: 'detected',
            sourceRef: row.fingerprint,
          );
        } else {
          transactionId = await ledger.recordCash(
            accountId: account.id,
            amount: amount,
            type: type,
            categoryId: category,
            instrumentId: type == 'expense' ? instrumentId : null,
            merchant: merchant,
            note: note,
            date: date,
            source: 'detected',
            sourceRef: row.fingerprint,
          );
        }
    }
    await (db.update(db.detectedPayments)..where((d) => d.id.equals(id))).write(
      DetectedPaymentsCompanion(
        status: const Value('confirmed'),
        transactionId: Value(transactionId),
        accountId: Value(account.id),
        categoryId: Value(categoryId),
        autoConfirmed: Value(auto),
        resolvedAt: Value(DateTime.now()),
      ),
    );
    if (merchant != null && categoryId != null && !auto) {
      await store.put('merchantRules', _ruleKey(merchant), {
        'merchant': merchant,
        'categoryId': categoryId,
      }, notify: false);
    }
    Amount? difference;
    if (p.balanceAfter != null &&
        (p.currency == null || p.currency == account.currency)) {
      final booked = await store.balance(account.id);
      final stated = account.type == 'credit'
          ? -p.balanceAfter!
          : p.balanceAfter!;
      if (account.type != 'credit' && stated != booked) {
        difference = stated - booked;
      }
    }
    return ConfirmResult(transactionId, difference);
  });

  /// Records that the payment is already in the ledger as [transactionId].
  Future<void> link(int id, int transactionId) =>
      (db.update(db.detectedPayments)..where((d) => d.id.equals(id))).write(
        DetectedPaymentsCompanion(
          status: const Value('confirmed'),
          transactionId: Value(transactionId),
          resolvedAt: Value(DateTime.now()),
        ),
      );

  Future<void> dismiss(int id) =>
      (db.update(db.detectedPayments)..where((d) => d.id.equals(id))).write(
        DetectedPaymentsCompanion(
          status: const Value('dismissed'),
          resolvedAt: Value(DateTime.now()),
        ),
      );

  /// Puts a dismissed or duplicate item back in the inbox.
  Future<void> restore(int id) =>
      (db.update(db.detectedPayments)..where((d) => d.id.equals(id))).write(
        const DetectedPaymentsCompanion(
          status: Value('pending'),
          duplicateOfId: Value(null),
          resolvedAt: Value(null),
        ),
      );

  /// Removes the ledger entry of a confirmed payment and returns it to the
  /// inbox.
  Future<void> undoConfirm(int id) => db.transaction(() async {
    final row = await get(id);
    if (row?.transactionId != null &&
        await db.getTransactionById(row!.transactionId!) != null) {
      await ledger.deleteTransactionAndUpdateBalance(row.transactionId!);
    }
    await (db.update(db.detectedPayments)..where((d) => d.id.equals(id))).write(
      const DetectedPaymentsCompanion(
        status: Value('pending'),
        transactionId: Value(null),
        autoConfirmed: Value(false),
        resolvedAt: Value(null),
      ),
    );
  });

  /// Clears message text of resolved items older than [days].
  Future<void> purgeText({required int days, DateTime? now}) =>
      (db.update(db.detectedPayments)..where(
            (d) =>
                d.status.isNotValue('pending') &
                d.receivedAt.isSmallerThanValue(
                  (now ?? DateTime.now()).subtract(Duration(days: days)),
                ),
          ))
          .write(const DetectedPaymentsCompanion(rawText: Value(null)));

  Future<void> purgeAllText() => (db.update(
    db.detectedPayments,
  )).write(const DetectedPaymentsCompanion(rawText: Value(null)));

  String _note(ParsedPayment p) => switch (p.kind) {
    'withdrawal' => 'Cash withdrawal',
    'transfer_out' =>
      'Transfer${p.counterparty == null ? '' : ' to ${p.counterparty}'}',
    'transfer_in' =>
      'Received${p.counterparty == null ? '' : ' from ${p.counterparty}'}',
    'card_payment' => 'Card payment',
    'bill_payment' => 'Bill payment',
    _ => 'Detected payment',
  };

  /// An ATM withdrawal moves money into cash the person holds.
  bool _impliesOwnAccount(ParsedPayment p, Account account) =>
      p.kind == 'withdrawal' ||
      (p.kind == 'card_payment' && account.type != 'credit');

  Future<int?> _ownDestination(ParsedPayment p, Account from) async {
    final accounts = await db.getAllAccounts();
    final type = p.kind == 'withdrawal' ? 'cash' : 'credit';
    final matches = accounts
        .where(
          (a) =>
              a.type == type && a.currency == from.currency && a.id != from.id,
        )
        .toList();
    return matches.length == 1 ? matches.single.id : null;
  }

  /// The account a card payment most likely came from.
  Future<int?> _payingAccount(Account card) async {
    final banks = (await db.getAllAccounts())
        .where((a) => a.type == 'bank' && a.currency == card.currency)
        .toList();
    return banks.length == 1 ? banks.single.id : null;
  }

  Future<int> _transfer({
    required int from,
    required int to,
    required Amount amount,
    required DateTime date,
    required String note,
  }) async {
    final source = await db.getAccountById(from);
    final target = await db.getAccountById(to);
    if (source == null || target == null) {
      throw StateError('Account no longer exists');
    }
    if (source.currency != target.currency) {
      throw ArgumentError('Record transfers across currencies by hand');
    }
    final before = (await db.getTransactionsByAccount(from)).map((t) => t.id);
    await ledger.transfer(
      fromAccountId: from,
      toAccountId: to,
      amount: amount,
      date: date,
      note: note,
    );
    final created = (await db.getTransactionsByAccount(from))
        .where((t) => !before.contains(t.id) && t.linkedTransactionId != null)
        .first;
    return created.id;
  }
}
