import 'fx_policy.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'system_categories.dart';
import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';

class FinancialLedgerService {
  final AppDatabase db;
  late final FinanceStore store = FinanceStore(db);
  late final PortfolioRepository portfolio = PortfolioRepository(store);
  FinancialLedgerService(this.db);
  String newId() => const Uuid().v4();
  void positive(Amount value) {
    if (value <= Amount.zero) throw ArgumentError('Enter a positive amount');
  }

  Future<int> recordCash({
    required int accountId,
    required Amount amount,
    required String type,
    int? categoryId,
    String? note,
    DateTime? date,
    String kind = 'cash',
    Json? extra,
    String? expectCurrency,
  }) => db.transaction(() async {
    positive(amount);
    if (!['income', 'expense'].contains(type)) {
      throw ArgumentError('Choose income or expense');
    }
    final account = await db.getAccountById(accountId);
    if (account == null) throw StateError('Account no longer exists');
    _checkCurrency(account, expectCurrency);
    final details = await store.get('accountDetails', '$accountId');
    if (details?['archived'] == true) {
      throw StateError('Unarchive this account first');
    }
    final category =
        categoryId ??
        await SystemCategories.idFor(
          db,
          SystemCategories.keyFor(kind, type, feeType: extra?['feeType']),
        );
    final c = await db.getCategoryById(category);
    if (c == null || c.type != type) {
      throw ArgumentError('Category must match transaction type');
    }
    final occurred = date ?? DateTime.now();
    final id = await db.insertTransaction(
      TransactionsCompanion.insert(
        accountId: accountId,
        categoryId: category,
        amount: amount.toDouble(),
        type: type,
        note: Value(note),
        transactionDate: occurred,
      ),
    );
    final sign = (type == 'income') != (account.type == 'credit')
        ? Amount.one
        : -Amount.one;
    await store.changeBalance(accountId, amount * sign);
    await _snapshot(id, amount, account.currency, occurred, kind);
    if (extra != null && extra.isNotEmpty) {
      await store.setTransactionDetails(id, {
        ...(await store.transactionDetails(id))!,
        ...extra,
      });
    }
    return id;
  });

  /// The amount was entered in [expected]; refuse to book it in another
  /// currency, which would silently relabel e.g. USD 100 as EGP 100.
  void _checkCurrency(Account account, String? expected) {
    if (expected != null && expected != account.currency) {
      throw TransactionLogicException(
        '${account.name} is in ${account.currency}, but the amount was '
        'entered in $expected. Convert it before saving.',
      );
    }
  }

  Future<void> _snapshot(
    int id,
    Amount amount,
    String currency,
    DateTime date,
    String kind, {
    Json? keep,
  }) async {
    final rates = (await store.list('fx'))
        .map(MarketObservation.fromJson)
        .where(
          (r) =>
              r.key.startsWith('$currency/') &&
              FxPolicy.usableFor(r.effectiveAt, date),
        )
        .toList();
    rates.sort((a, b) {
      if (a.manual != b.manual) return a.manual ? -1 : 1;
      return b.effectiveAt.compareTo(a.effectiveAt);
    });
    final snapshots = <String, String>{currency: '1'};
    final ratedAt = <String, String>{};
    for (final r in rates) {
      if (snapshots.containsKey(r.currency)) continue;
      snapshots[r.currency] = '${r.value}';
      ratedAt[r.currency] = r.effectiveAt.toIso8601String();
    }
    await store.setTransactionDetails(id, {
      ...?keep,
      'amount': '$amount',
      'currency': currency,
      'date': date.toIso8601String(),
      'kind': kind,
      'rates': snapshots,
      'ratesAt': ratedAt,
    });
  }

  Future<void> insertTransactionAndUpdateBalance(
    TransactionsCompanion entry,
  ) async {
    await recordCash(
      accountId: entry.accountId.value,
      amount: Amount.fromNum(entry.amount.value),
      type: entry.type.value,
      categoryId: entry.categoryId.value,
      note: entry.note.present ? entry.note.value : null,
      date: entry.transactionDate.value,
    );
  }

  Future<void> updateTransactionAndUpdateBalance(Transaction updated) =>
      updateCash(
        updated.id,
        accountId: updated.accountId,
        amount: Amount.fromNum(updated.amount),
        type: updated.type,
        categoryId: updated.categoryId,
        note: updated.note,
        date: updated.transactionDate,
      );

  /// Edits a plain income/expense entry, moving its balance effect between
  /// accounts when needed. [expectCurrency] is the currency the amount was
  /// entered in.
  Future<void> updateCash(
    int id, {
    required int accountId,
    required Amount amount,
    required String type,
    required int categoryId,
    String? note,
    required DateTime date,
    String? expectCurrency,
  }) => db.transaction(() async {
    final existing = await db.getTransactionById(id);
    if (existing == null) throw StateError('Transaction no longer exists');
    if (existing.linkedTransactionId != null) {
      throw StateError('Use Edit transfer to update both accounts');
    }
    final details = await store.transactionDetails(existing.id);
    if (details?['contractPaymentId'] != null ||
        details?['transferOwner'] != null ||
        details?['holdingFeeFor'] != null) {
      throw StateError('Manage this entry through its linked operation');
    }
    if (details != null && !['cash', 'fee'].contains(details['kind'])) {
      throw StateError('Manage this entry from its holding or contract');
    }
    positive(amount);
    final a = await db.getAccountById(accountId);
    final old = await db.getAccountById(existing.accountId);
    final category = await db.getCategoryById(categoryId);
    if (a == null || old == null || category?.type != type) {
      throw ArgumentError('Select a valid account and matching category');
    }
    _checkCurrency(a, expectCurrency);
    if ((await store.get('accountDetails', '${a.id}'))?['archived'] == true) {
      throw StateError('Unarchive the account before editing');
    }
    final priorAmount = details == null
        ? Amount.fromNum(existing.amount)
        : amountOf(details['amount']);
    await store.changeBalance(
      old.id,
      -(priorAmount * _sign(existing.type, old.type)),
    );
    await db.updateTransaction(
      existing.copyWith(
        accountId: accountId,
        amount: amount.toDouble(),
        type: type,
        categoryId: categoryId,
        note: Value(note),
        transactionDate: date,
      ),
    );
    await store.changeBalance(a.id, amount * _sign(type, a.type));
    for (final event in await store.list('activity')) {
      if (event['transactionId'] == id &&
          ['dividend', 'interest', 'rent'].contains(event['kind'])) {
        await store.put('activity', event['id'], {
          ...event,
          'amount': '$amount',
          'currency': a.currency,
          'date': date.toIso8601String(),
        });
      }
    }
    if (details != null &&
        existing.accountId == accountId &&
        existing.transactionDate == date) {
      await store.setTransactionDetails(id, {...details, 'amount': '$amount'});
    } else {
      await _snapshot(
        id,
        amount,
        a.currency,
        date,
        details?['kind'] ?? 'cash',
        keep: details,
      );
    }
  });

  Future<void> deleteTransactionAndUpdateBalance(int id) =>
      db.transaction(() async {
        await _guardUserDelete(id);
        await _removeEntry(id);
      });

  /// Deletes [id] (with its linked leg and fee) and returns everything needed
  /// to put it back exactly as it was through [restore].
  Future<DeletedEntry?> deleteWithUndo(int id) => db.transaction(() async {
    if (await db.getTransactionById(id) == null) return null;
    await _guardUserDelete(id);
    final entry = await _capture(id);
    await _removeEntry(id);
    return entry;
  });

  /// Removes a ledger entry owned by a contract or holding operation, skipping
  /// the user-facing guards that point people at that operation.
  Future<void> removeOwnedEntry(int id) =>
      db.transaction(() => _removeEntry(id));

  Future<void> _guardUserDelete(int id) async {
    final details = await store.transactionDetails(id);
    if (details?['holdingFeeFor'] != null) {
      throw StateError('This fee belongs to the holding acquisition cost');
    }
    if (details?['contractPaymentId'] != null) {
      throw StateError('Reverse this payment from its contract');
    }
    if (details?['transferOwner'] != null) {
      throw StateError('Manage transfer fees through the linked transfer');
    }
    if (details != null &&
        !['cash', 'fee', 'transfer'].contains(details['kind'])) {
      throw StateError(
        'This entry belongs to a holding or contract and cannot be deleted independently',
      );
    }
  }

  /// Every row that belongs to the entry [id]: itself, its transfer leg, and
  /// any fee booked with it.
  Future<List<Transaction>> _entryRows(int id) async {
    final rows = <Transaction>[];
    final seen = <int>{};
    Future<void> visit(int? rowId) async {
      if (rowId == null || !seen.add(rowId)) return;
      final tx = await db.getTransactionById(rowId);
      if (tx == null) return;
      rows.add(tx);
      final details = await store.transactionDetails(rowId);
      await visit(details?['feeId'] as int?);
      await visit(tx.linkedTransactionId);
    }

    await visit(id);
    return rows;
  }

  Future<void> _removeEntry(int id) async {
    final rows = await _entryRows(id);
    final ids = rows.map((t) => t.id).toSet();
    for (final event in await store.list('activity')) {
      if (ids.contains(event['transactionId']) &&
          ['dividend', 'interest', 'rent'].contains(event['kind'])) {
        await store.remove('activity', event['id']);
      }
    }
    for (final attachment in await store.list('attachments')) {
      if (ids.contains(attachment['transactionId'])) {
        await store.remove('attachments', attachment['id']);
      }
    }
    for (final tx in rows) {
      await _revert(tx);
      await db.deleteTransaction(tx.id);
    }
  }

  Amount _sign(String type, String accountType) =>
      (type == 'income') != (accountType == 'credit')
      ? Amount.one
      : -Amount.one;

  Future<Amount> _exactAmount(Transaction tx) async {
    final details = await store.transactionDetails(tx.id);
    return details?['amount'] == null
        ? Amount.fromNum(tx.amount)
        : amountOf(details!['amount']);
  }

  Future<void> _revert(Transaction tx) async {
    final account = await db.getAccountById(tx.accountId);
    if (account == null) return;
    final amount = await _exactAmount(tx);
    await store.changeBalance(
      account.id,
      -(amount * _sign(tx.type, account.type)),
    );
  }

  Future<DeletedEntry> _capture(int id) async {
    final rows = await _entryRows(id);
    final ids = rows.map((t) => t.id).toSet();
    return DeletedEntry(
      rows: rows,
      details: {
        for (final tx in rows) tx.id: await store.transactionDetails(tx.id),
      },
      activity: [
        for (final event in await store.list('activity'))
          if (ids.contains(event['transactionId'])) event,
      ],
      attachments: [
        for (final attachment in await store.list('attachments'))
          if (ids.contains(attachment['transactionId'])) attachment,
      ],
    );
  }

  /// Puts back an entry removed by [deleteWithUndo] with its original ids,
  /// conversion snapshot, links, attachments and balance effect.
  Future<void> restore(DeletedEntry entry) => db.transaction(() async {
    for (final tx in entry.rows) {
      final account = await db.getAccountById(tx.accountId);
      if (account == null) throw StateError('Account no longer exists');
      if ((await store.get('accountDetails', '${account.id}'))?['archived'] ==
          true) {
        throw StateError('Unarchive this account first');
      }
      if (await db.getTransactionById(tx.id) != null) {
        throw StateError('This entry was already restored');
      }
    }
    for (final tx in entry.rows) {
      await db.insertTransaction(
        tx.copyWith(linkedTransactionId: const Value(null)).toCompanion(true),
      );
    }
    for (final tx in entry.rows) {
      if (tx.linkedTransactionId != null) {
        await (db.update(
          db.transactions,
        )..where((t) => t.id.equals(tx.id))).write(
          TransactionsCompanion(
            linkedTransactionId: Value(tx.linkedTransactionId),
          ),
        );
      }
      final details = entry.details[tx.id];
      if (details != null) await store.setTransactionDetails(tx.id, details);
      final account = (await db.getAccountById(tx.accountId))!;
      await store.changeBalance(
        account.id,
        await _exactAmount(tx) * _sign(tx.type, account.type),
      );
    }
    for (final event in entry.activity) {
      await store.put('activity', event['id'], event);
    }
    for (final attachment in entry.attachments) {
      await store.put('attachments', attachment['id'], attachment);
    }
  });

  Future<void> transferBetweenAccounts({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    double? destinationAmount,
    double fee = 0,
    String? note,
    DateTime? date,
    int? editId,
  }) => transfer(
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    amount: Amount.fromNum(amount),
    received: destinationAmount == null
        ? null
        : Amount.fromNum(destinationAmount),
    fee: Amount.fromNum(fee),
    note: note,
    date: date,
    editId: editId,
  );

  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required Amount amount,
    Amount? received,
    Amount? fee,
    String? note,
    DateTime? date,
    int? editId,
    String? expectCurrency,
  }) => db.transaction(() async {
    positive(amount);
    final charge = fee ?? Amount.zero;
    if (charge < Amount.zero) throw ArgumentError('Fee cannot be negative');
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Choose different accounts');
    }
    final from = await db.getAccountById(fromAccountId),
        to = await db.getAccountById(toAccountId);
    if (from == null || to == null) {
      throw StateError('Account no longer exists');
    }
    _checkCurrency(from, expectCurrency);
    if (from.currency != to.currency && received == null) {
      throw ArgumentError(
        'Enter the actual destination amount for this currency',
      );
    }
    if (from.currency == to.currency &&
        received != null &&
        received != amount) {
      throw ArgumentError(
        'Same-currency transfers arrive in full; record any difference as a fee',
      );
    }
    final destination = received ?? amount;
    positive(destination);
    if (editId != null) {
      final original = await db.getTransactionById(editId);
      if (original?.linkedTransactionId == null) {
        throw StateError('Transfer no longer exists');
      }
      final metadata = await store.transactionDetails(editId);
      if (metadata?['contractPaymentId'] != null) {
        throw StateError('Reverse this settlement through its contract');
      }
      await _removeEntry(editId);
    }
    final out = await recordCash(
      accountId: fromAccountId,
      amount: amount,
      type: 'expense',
      note: note ?? 'Transfer: ${from.name} → ${to.name}',
      kind: 'transfer',
      date: date,
    );
    final incoming = await recordCash(
      accountId: toAccountId,
      amount: destination,
      type: 'income',
      note: note ?? 'Transfer: ${from.name} → ${to.name}',
      kind: 'transfer',
      date: date,
    );
    await (db.update(db.transactions)..where((t) => t.id.equals(out))).write(
      TransactionsCompanion(linkedTransactionId: Value(incoming)),
    );
    await (db.update(db.transactions)..where((t) => t.id.equals(incoming)))
        .write(TransactionsCompanion(linkedTransactionId: Value(out)));
    final feeId = charge > Amount.zero
        ? await recordCash(
            accountId: fromAccountId,
            amount: charge,
            type: 'expense',
            kind: 'fee',
            note: 'Transfer fee',
            date: date,
            extra: {'feeType': 'transfer'},
          )
        : null;
    if (feeId != null) {
      await store.setTransactionDetails(feeId, {
        ...(await store.transactionDetails(feeId))!,
        'transferOwner': out,
      });
    }
    for (final id in [out, incoming]) {
      await store.setTransactionDetails(id, {
        ...(await store.transactionDetails(id))!,
        'feeId': feeId,
        'sourceAmount': '$amount',
        'destinationAmount': '$destination',
        'rate': '${destination / amount}',
      });
    }
  });

  Future<void> reconcile(int accountId, Amount target, String reason) =>
      db.transaction(() async {
        if (reason.trim().isEmpty) {
          throw ArgumentError('Enter a reconciliation reason');
        }
        final before = await store.balance(accountId);
        await store.changeBalance(accountId, target - before);
        final id = newId();
        await store.put('adjustments', id, {
          'id': id,
          'accountId': accountId,
          'before': '$before',
          'after': '$target',
          'reason': reason.trim(),
          'date': DateTime.now().toIso8601String(),
        });
      });

  Future<void> openHolding(Holding holding) => db.transaction(() async {
    if (holding.name.trim().isEmpty) throw ArgumentError('Enter an asset name');
    if (holding.quantity < Amount.zero ||
        holding.ownership <= Amount.zero ||
        holding.ownership > Amount.one ||
        holding.karat < 1 ||
        holding.karat > 24 ||
        (holding.costBasis != null && holding.costBasis! < Amount.zero)) {
      throw ArgumentError('Check quantity, ownership, purity, and cost');
    }
    if (await portfolio.get(holding.id) != null) {
      throw StateError('Holding already exists');
    }
    await portfolio.save(holding);
    final id = newId();
    await store.put('activity', id, {
      'id': id,
      'holdingId': holding.id,
      'kind': 'opening',
      'quantity': '${holding.quantity}',
      'amount': holding.costBasis?.toString(),
      'currency': holding.currency,
      'date': holding.openedAt.toIso8601String(),
      'opening': true,
    });
  });

  Future<void> trade({
    required String holdingId,
    required ActivityKind kind,
    required Amount quantity,
    required Amount unitPrice,
    required int accountId,
    Amount? fee,
    Amount? cashAmount,
    DateTime? date,
  }) => db.transaction(() async {
    if (kind != ActivityKind.buy && kind != ActivityKind.sell) {
      throw ArgumentError('Choose buy or sell');
    }
    positive(quantity);
    positive(unitPrice);
    final charge = fee ?? Amount.zero;
    if (charge < Amount.zero) throw ArgumentError('Fees cannot be negative');
    final h = await portfolio.get(holdingId);
    final account = await db.getAccountById(accountId);
    if (h == null || account == null) {
      throw StateError('Holding or account no longer exists');
    }
    if (account.currency != h.currency && cashAmount == null) {
      throw ArgumentError('Specify actual account-currency cash amount');
    }
    final actionDate = date ?? DateTime.now();
    final day = DateTime(actionDate.year, actionDate.month, actionDate.day);
    for (final event in await portfolio.activity(h.id)) {
      final prior = dateOf(event['date']);
      if (DateTime(prior.year, prior.month, prior.day).isAfter(day) &&
          !['dividend', 'interest', 'rent'].contains(event['kind'])) {
        throw ArgumentError(
          'Enter holding changes in chronological order so acquisition cost stays correct',
        );
      }
    }
    final buy = kind == ActivityKind.buy;
    if (!buy && quantity > h.quantity) {
      throw ArgumentError('Cannot sell more than you own');
    }
    final gross = quantity * unitPrice * h.ownership;
    final cash = cashAmount ?? gross;
    positive(cash);
    if (!buy && charge >= cash) {
      throw ArgumentError('Fees must be less than proceeds');
    }
    final allocated = h.costBasis == null || h.quantity == Amount.zero
        ? null
        : h.costBasis! * quantity / h.quantity;
    // Fees are in the cash account currency. Cost basis uses quote currency.
    final quoteFee = charge == Amount.zero
        ? Amount.zero
        : charge * gross / cash;
    final cost = buy
        ? (h.costBasis == null && h.quantity > Amount.zero
              ? null
              : (h.costBasis ?? Amount.zero) + gross + quoteFee)
        : h.costBasis == null
        ? null
        : h.costBasis! - (allocated ?? Amount.zero);
    final txId = await recordCash(
      accountId: accountId,
      amount: cash,
      type: buy ? 'expense' : 'income',
      kind: 'asset',
      note: '${kind.name}: ${h.name}',
      date: date,
    );
    final feeId = charge > Amount.zero
        ? await recordCash(
            accountId: accountId,
            amount: charge,
            type: 'expense',
            kind: 'fee',
            note: '${h.name} fee',
            date: date,
            extra: {'feeType': 'investment'},
          )
        : null;
    if (feeId != null) {
      await store.setTransactionDetails(feeId, {
        ...(await store.transactionDetails(feeId))!,
        'holdingFeeFor': h.id,
      });
    }
    await portfolio.save(
      h.copy(
        quantity: buy ? h.quantity + quantity : h.quantity - quantity,
        costBasis: cost,
        clearCost: cost == null,
      ),
    );
    final id = newId();
    await store.put('activity', id, {
      'id': id,
      'holdingId': h.id,
      'kind': kind.name,
      'quantity': '$quantity',
      'amount': '$gross',
      'fee': '$quoteFee',
      'currency': h.currency,
      'accountId': accountId,
      'transactionId': txId,
      'feeId': feeId,
      'realizedGain': !buy && allocated != null
          ? '${gross - quoteFee - allocated}'
          : null,
      'date': (date ?? DateTime.now()).toIso8601String(),
    });
  });

  Future<void> linkPropertyDebt(String holdingId, String? contractId) =>
      db.transaction(() async {
        final h = await portfolio.get(holdingId);
        if (h == null || h.kind != AssetKind.property) {
          throw ArgumentError('Select a property holding');
        }
        if (contractId != null) {
          final c = await store.get('contracts', contractId);
          if (c == null || c['kind'] != 'loan') {
            throw ArgumentError('Select an existing loan contract');
          }
        }
        await portfolio.save(
          h.copy(
            linkedContractId: contractId,
            clearContract: contractId == null,
          ),
        );
        final id = newId();
        await store.put('activity', id, {
          'id': id,
          'holdingId': h.id,
          'kind': 'mortgageLink',
          'contractId': contractId,
          'date': DateTime.now().toIso8601String(),
        });
      });

  Future<void> adjustHolding(
    String holdingId, {
    required Amount quantity,
    Amount? costBasis,
    required String custody,
    required String reason,
  }) => db.transaction(() async {
    if (quantity < Amount.zero ||
        (costBasis != null && costBasis < Amount.zero) ||
        reason.trim().isEmpty) {
      throw ArgumentError('Check quantity, cost, and adjustment reason');
    }
    final h = await portfolio.get(holdingId);
    if (h == null) throw StateError('Holding no longer exists');
    await portfolio.save(
      h.copy(
        quantity: quantity,
        costBasis: costBasis,
        clearCost: costBasis == null,
        custody: custody,
      ),
    );
    final id = newId();
    await store.put('activity', id, {
      'id': id,
      'holdingId': h.id,
      'kind': 'adjustment',
      'quantity': '$quantity',
      'amount': costBasis?.toString(),
      'currency': h.currency,
      'beforeQuantity': '${h.quantity}',
      'beforeCost': h.costBasis?.toString(),
      'custody': custody,
      'reason': reason.trim(),
      'date': DateTime.now().toIso8601String(),
    });
  });

  Future<void> split(String holdingId, Amount ratio, {DateTime? date}) =>
      db.transaction(() async {
        positive(ratio);
        final h = await portfolio.get(holdingId);
        if (h == null) throw StateError('Holding no longer exists');
        await portfolio.save(h.copy(quantity: h.quantity * ratio));
        final id = newId();
        await store.put('activity', id, {
          'id': id,
          'holdingId': h.id,
          'kind': 'split',
          'ratio': '$ratio',
          'date': (date ?? DateTime.now()).toIso8601String(),
        });
      });
  Future<void> distribution(
    String holdingId,
    int accountId,
    Amount amount,
    ActivityKind kind, {
    DateTime? date,
  }) => db.transaction(() async {
    if (![
      ActivityKind.dividend,
      ActivityKind.interest,
      ActivityKind.rent,
    ].contains(kind)) {
      throw ArgumentError('Invalid income type');
    }
    final h = await portfolio.get(holdingId);
    if (h == null) throw StateError('Holding no longer exists');
    final tx = await recordCash(
      accountId: accountId,
      amount: amount,
      type: 'income',
      kind: 'cash',
      note: '${kind.name}: ${h.name}',
      date: date,
    );
    final id = newId();
    await store.put('activity', id, {
      'id': id,
      'holdingId': holdingId,
      'kind': kind.name,
      'amount': '$amount',
      'transactionId': tx,
      'date': (date ?? DateTime.now()).toIso8601String(),
    });
  });
}

/// A ledger entry removed by [FinancialLedgerService.deleteWithUndo].
class DeletedEntry {
  final List<Transaction> rows;
  final Map<int, Json?> details;
  final List<Json> activity, attachments;
  const DeletedEntry({
    required this.rows,
    required this.details,
    required this.activity,
    required this.attachments,
  });
}
