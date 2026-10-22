import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import '../finance/credit_card_service.dart';
import '../finance/financial_ledger_service.dart';
import '../finance/valuation_service.dart';
import '../services/category_suggester.dart';
import '../utils/currency_formatter.dart';
import '../utils/fingerprint.dart';
import '../ai/ai_payment_assist.dart';
import 'category_resolver.dart';
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

/// What a payment costs in its account's currency.
class ChargeEstimate {
  /// The amount booked to the account, before any card fee.
  final Amount amount;

  /// The card's foreign-currency fee, added on top when [fromRate].
  final Amount feePercent;

  /// True when [amount] comes from an exchange rate, not from the bank.
  final bool fromRate;
  const ChargeEstimate(this.amount, this.feePercent, {this.fromRate = false});

  Amount get fee =>
      fromRate ? amount * feePercent / Amount('100') : Amount.zero;
}

class ConfirmResult {
  final int transactionId;

  /// Message balance minus the account's balance after booking, when the
  /// message stated one and they differ.
  final Amount? balanceDifference;

  /// On a credit card: the available limit the message stated minus what
  /// Flourish shows after booking, when they differ.
  final Amount? limitDifference;
  const ConfirmResult(
    this.transactionId,
    this.balanceDifference, [
    this.limitDifference,
  ]);
}

/// Turns bank and wallet messages into pending payments, matches them to
/// accounts, cards and categories, and books them through the ledger once
/// confirmed. Parsing happens on the device; message text reaches the
/// optional AI stage only after a tap or with the person's consent to
/// automatic reading ([automaticAi]).
class DetectionService {
  final FinancialLedgerService ledger;

  /// The optional AI stage; resolves to null when AI is off or has no key.
  final Future<AiPaymentAssist?> Function()? assist;

  /// Whether messages nobody tapped for may be sent to [assist]. Off unless
  /// the person agreed to automatic AI reading for the current provider.
  final bool Function() automaticAi;

  /// Whether unmatched merchants may get a proposed new category.
  final bool newCategories;
  DetectionService(
    this.ledger, {
    this.assist,
    bool Function()? automaticAi,
    this.newCategories = true,
  }) : automaticAi = automaticAi ?? _never;

  static bool _never() => false;
  AppDatabase get db => ledger.db;
  FinanceStore get store => ledger.store;

  static const _window = Duration(minutes: 15);

  /// Receipt images waiting for their detected payment to be confirmed,
  /// keyed by detected payment id.
  static const receiptCollection = 'detectionReceipts';

  /// Keeps [path] as the receipt of detected payment [id] once confirmed.
  Future<void> attachReceipt(int id, String path) =>
      store.put(receiptCollection, '$id', {'path': path}, notify: false);

  /// Parses and stores [message]. Returns null when it is not a payment or
  /// was already received. [userInitiated] marks text the person submitted
  /// themselves (Smart Import), which may go to the AI without automatic
  /// consent.
  Future<DetectedPayment?> ingest(
    RawMessage message, {
    bool autoConfirm = false,
    bool userInitiated = false,
  }) async {
    final cleaned = MessageNormalizer.clean(message.text);
    var parsed = PaymentMessageParser.parse(message);
    AiPaymentResult? ai;
    if (parsed.ignored) {
      // The AI may read a payment the parser found no amount in.
      ai = await _tryAi(cleaned, parsed, userInitiated: userInitiated);
      if (ai != null && !ai.payment.ignored) parsed = ai.payment;
    }
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
    final category = await _category(
      parsed,
      account,
      text: cleaned,
      aiCategoryId: ai?.categoryId,
      aiProposed: ai?.proposed,
    );
    if (category.proposed != null) {
      parsed = parsed.copyWith(proposedCategory: category.proposed!.toJson());
    }
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
            categoryId: Value(category.categoryId),
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

  /// What [row] costs in the currency of [accountId] (default: its matched
  /// account). A foreign-currency payment without the bank's own figure is
  /// converted at that day's exchange rate (through USD when there is no
  /// direct rate); null when no rate is known.
  Future<ChargeEstimate?> charge(DetectedPayment row, {int? accountId}) async {
    final id = accountId ?? row.accountId;
    if (id == null) return null;
    final account = await db.getAccountById(id);
    final p = parsedOf(row);
    if (account == null || p.amount == null) return null;
    if (p.currency == null || p.currency == account.currency) {
      return ChargeEstimate(p.amount!, Amount.zero);
    }
    if (p.bookedCurrency == account.currency && p.bookedAmount != null) {
      return ChargeEstimate(p.bookedAmount!, Amount.zero);
    }
    final date = row.occurredAt ?? row.receivedAt;
    final valuation = ValuationService(store);
    var value = await valuation.convert(
      p.amount!,
      p.currency!,
      account.currency,
      at: date,
    );
    if (value == null && p.currency != 'USD' && account.currency != 'USD') {
      final usd = await valuation.convert(
        p.amount!,
        p.currency!,
        'USD',
        at: date,
      );
      if (usd != null) {
        value = await valuation.convert(usd, 'USD', account.currency, at: date);
      }
    }
    if (value == null) return null;
    final instrumentId = id == row.accountId ? row.instrumentId : null;
    return ChargeEstimate(
      value.rounded(CurrencyFormatter.decimalsFor(account.currency)),
      await ledger.fxFeePercentFor(account, instrumentId),
      fromRate: true,
    );
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
      // Two shops are two payments, even for the same amount.
      final a = p.merchant ?? p.counterparty, b = o.merchant ?? o.counterparty;
      final otherShop = a != null && b != null && _ruleKey(a) != _ruleKey(b);
      if (o.direction == p.direction &&
          !otherShop &&
          (sameCard || sameIssuer || unknown)) {
        return other.id;
      }
    }
    return null;
  }

  static String _ruleKey(String merchant) => MessageNormalizer.fold(
    MessageNormalizer.clean(merchant),
  ).replaceAll(RegExp(r'[^a-z0-9؀-ۿ]+'), ' ').trim();

  /// Merchant rule (the person's last choice) → AI pick → history and
  /// keywords → local concept table → "Other". A miss in an existing
  /// category may come back as a proposal to create one on confirm.
  Future<CategoryResolution> _category(
    ParsedPayment p,
    Account? account, {
    String text = '',
    int? aiCategoryId,
    ProposedCategory? aiProposed,
  }) async {
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
      return const CategoryResolution();
    }
    final merchant = p.merchant ?? p.counterparty;
    if (merchant != null) {
      final rule = await store.get('merchantRules', _ruleKey(merchant));
      final id = rule?['categoryId'] as int?;
      if (id != null) {
        final c = await db.getCategoryById(id);
        if (c != null && c.type == type) {
          return CategoryResolution(categoryId: id);
        }
      }
    }
    final all = await db.getAllCategories();
    final resolver = CategoryResolver(all, allowNew: newCategories);
    final query = CategoryQuery(
      type: type,
      merchant: merchant ?? '',
      text: text,
      aiCategoryId: aiCategoryId,
      aiProposed: aiProposed,
    );
    final fromAi = resolver.fromAi(query);
    if (fromAi.found) return fromAi;
    final recent = (await db.getAllTransactions()).take(500).toList();
    final suggested = CategorySuggester.suggest(
      '${merchant ?? ''} ${p.kind ?? ''}',
      recent,
      categories: resolver.categories,
      type: type,
    );
    if (suggested != null) return CategoryResolution(categoryId: suggested);
    final concept = resolver.fromConcept(query);
    if (concept.found) return concept;
    return CategoryResolution(
      categoryId: (await db.fallbackCategoryFor(type)).id,
    );
  }

  Future<AiPaymentResult?> _tryAi(
    String text,
    ParsedPayment local, {
    required bool userInitiated,
  }) async {
    if (!userInitiated && !automaticAi()) return null;
    final ai = await assist?.call();
    if (ai == null || !ai.wants(local, text)) return null;
    try {
      final results = await ai.improve(
        [AiPaymentRequest(text, local)],
        await db.getAllCategories(),
        forceRedact: !userInitiated,
      );
      return results.single;
    } catch (_) {
      return null; // Offline or misconfigured: keep the on-device reading.
    }
  }

  /// Sends pending payments the parser was unsure about (or [ids], even when
  /// sure, unless [unclearOnly]) to the AI and applies what passes
  /// validation. Returns how many changed; throws when the AI could not be
  /// reached so the UI can say so.
  ///
  /// Without [userInitiated] this is the background pass: it does nothing
  /// unless the person agreed to automatic AI reading, and always masks
  /// personal data.
  Future<int> assistPending({
    List<int>? ids,
    bool userInitiated = false,
    bool unclearOnly = false,
  }) async {
    if (!userInitiated && !automaticAi()) return 0;
    final ai = await assist?.call();
    if (ai == null) return 0;
    final rows = ids == null
        ? await (db.select(
            db.detectedPayments,
          )..where((d) => d.status.equals('pending'))).get()
        : await (db.select(
            db.detectedPayments,
          )..where((d) => d.id.isIn(ids))).get();
    final todo = [
      for (final r in rows)
        if (r.rawText != null &&
            r.status == 'pending' &&
            ((ids != null && !unclearOnly) ||
                ai.wants(parsedOf(r), r.rawText!)))
          r,
    ];
    if (todo.isEmpty) return 0;
    final results = await ai.improve(
      [for (final r in todo) AiPaymentRequest(r.rawText!, parsedOf(r))],
      await db.getAllCategories(),
      forceRedact: !userInitiated,
    );
    var changed = 0;
    for (var i = 0; i < todo.length; i++) {
      final result = results[i];
      if (result == null) continue;
      await _applyAi(todo[i], result);
      changed++;
    }
    if (changed > 0) db.notifyFinanceChanged();
    return changed;
  }

  Future<void> _applyAi(DetectedPayment row, AiPaymentResult result) async {
    var p = result.payment;
    if (p.ignored) {
      await (db.update(
        db.detectedPayments,
      )..where((d) => d.id.equals(row.id))).write(
        DetectedPaymentsCompanion(
          parsed: Value(jsonEncode(p.toJson())),
          status: const Value('dismissed'),
          resolvedAt: Value(DateTime.now()),
        ),
      );
      return;
    }
    final account = row.accountId == null
        ? null
        : await db.getAccountById(row.accountId!);
    final category = await _category(
      p,
      account,
      text: row.rawText ?? '',
      aiCategoryId: result.categoryId,
      aiProposed: result.proposed,
    );
    p = category.proposed == null
        ? p.copyWith(clearProposal: true)
        : p.copyWith(proposedCategory: category.proposed!.toJson());
    await (db.update(
      db.detectedPayments,
    )..where((d) => d.id.equals(row.id))).write(
      DetectedPaymentsCompanion(
        parsed: Value(jsonEncode(p.toJson())),
        amount: Value(p.amount?.toString()),
        currency: Value(p.currency),
        direction: Value(p.direction),
        kind: Value(p.kind),
        merchant: Value(p.merchant ?? p.counterparty),
        occurredAt: Value(p.occurredAt ?? row.occurredAt),
        categoryId: Value(category.categoryId),
        confidence: Value(p.confidence),
      ),
    );
  }

  /// The new category this payment would create on confirm, if any.
  ProposedCategory? proposalOf(DetectedPayment row) => row.categoryId != null
      ? null
      : ProposedCategory.fromJson(parsedOf(row).proposedCategory);

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
    var fromRate = false;
    if (amount == null) {
      final estimate = await charge(row, accountId: account.id);
      amount = estimate?.amount;
      fromRate = estimate?.fromRate ?? false;
    }
    if (amount == null) {
      throw ArgumentError(
        foreign
            ? 'No ${p.currency} exchange rate yet. Enter what ${account.name} '
                  'was charged in ${account.currency}'
            : 'Enter the amount',
      );
    }
    var categoryId = draft.categoryId ?? row.categoryId;
    final proposal = draft.categoryId == null ? proposalOf(row) : null;
    if (categoryId == null &&
        proposal != null &&
        proposal.type == (p.kind == 'refund' ? 'expense' : p.direction)) {
      categoryId = await CategoryResolver.ensure(db, store, proposal);
    }
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
            // The bank's own figure already is the charge; a converted one
            // gets the card's foreign-currency fee on top.
            fxFeePercent: fromRate ? null : Amount.zero,
            instrumentId: instrumentId,
            merchant: merchant,
            note: fromRate ? '$note (exchange rate estimate)' : note,
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
    final receipt = await store.get(receiptCollection, '$id');
    if (receipt != null) {
      final attachmentId = ledger.newId();
      await store.put('attachments', attachmentId, {
        'id': attachmentId,
        'path': receipt['path'],
        'transactionId': transactionId,
        'date': DateTime.now().toIso8601String(),
      });
      await store.remove(receiptCollection, '$id');
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
    Amount? limitDifference;
    if (account.type == 'credit' &&
        (p.availableCredit != null || p.availableIntlCredit != null)) {
      // Bank limits are in the card's currency even on foreign purchases.
      final cards = CreditCardService(ledger);
      await cards.recordBankLimits(
        account.id,
        available: p.availableCredit,
        intlAvailable: p.availableIntlCredit,
        at: row.occurredAt ?? row.receivedAt,
      );
      final status = await cards.status(account.id);
      if (p.availableCredit != null &&
          status.limit != null &&
          p.availableCredit != status.available) {
        limitDifference = p.availableCredit! - status.available;
      }
    }
    return ConfirmResult(transactionId, difference, limitDifference);
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
