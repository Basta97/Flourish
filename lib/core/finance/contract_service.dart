import '../../domain/finance/models.dart';
import '../../data/finance/finance_store.dart';
import 'financial_ledger_service.dart';

DateTime monthFrom(DateTime anchor, int months) {
  final first = DateTime(anchor.year, anchor.month + months, 1);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(
    first.year,
    first.month,
    anchor.day > last ? last : anchor.day,
  );
}

class ContractService {
  final FinancialLedgerService ledger;
  FinanceStore get store => ledger.store;
  ContractService(this.ledger);
  List<ScheduledPayment> schedule(FinanceContract c) {
    if ((c.kind == ContractKind.creditCard
            ? c.principal < Amount.zero
            : c.principal <= Amount.zero) ||
        c.annualRate < Amount.zero ||
        !c.maturity.isAfter(c.start) ||
        ![1, 2, 4, 12].contains(c.paymentsPerYear)) {
      throw ArgumentError('Check principal, dates, rate, and frequency');
    }
    if (c.interestMethod == 'manual' || c.kind == ContractKind.creditCard) {
      return [];
    }
    final dates = <DateTime>[];
    for (var i = 1; i < 1201; i++) {
      final next = monthFrom(c.start, i * (12 ~/ c.paymentsPerYear));
      if (!next.isBefore(c.maturity)) {
        dates.add(c.maturity);
        break;
      }
      dates.add(next);
    }
    if (dates.isEmpty || dates.last != c.maturity) {
      throw ArgumentError('Contract term exceeds 100 years');
    }
    final rate = c.annualRate / Amount('100') / Amount('${c.paymentsPerYear}');
    var factor = Amount.one;
    for (var i = 0; i < dates.length; i++) {
      factor *= Amount.one + rate;
    }
    final rawInstallment = rate == Amount.zero
        ? c.principal / Amount('${dates.length}')
        : c.principal * rate * factor / (factor - Amount.one);
    final digits = ['JPY', 'KRW'].contains(c.currency)
        ? 0
        : ['KWD', 'BHD', 'OMR'].contains(c.currency)
        ? 3
        : 2;
    final installment = rawInstallment.rounded(digits);
    var remaining = c.principal;
    final payments = <ScheduledPayment>[];
    var previous = c.start;
    for (var i = 0; i < dates.length; i++) {
      final last = i == dates.length - 1;
      final normalEnd = monthFrom(c.start, (i + 1) * (12 ~/ c.paymentsPerYear));
      final normalStart = i == 0
          ? c.start
          : monthFrom(c.start, i * (12 ~/ c.paymentsPerYear));
      final proportion =
          Amount('${dates[i].difference(previous).inDays}') /
          Amount('${normalEnd.difference(normalStart).inDays}');
      final debt =
          c.kind == ContractKind.loan || c.kind == ContractKind.receivable;
      final interest =
          ((debt && c.interestMethod == 'reducing' ? remaining : c.principal) *
                  rate *
                  proportion)
              .rounded(digits);
      Amount principal;
      if (debt) {
        principal = last
            ? remaining
            : c.interestMethod == 'reducing'
            ? installment - interest
            : (c.principal / Amount('${dates.length}')).rounded(digits);
        if (principal > remaining) principal = remaining;
      } else {
        principal = last ? c.principal : Amount.zero;
      }
      remaining -= principal;
      payments.add(
        ScheduledPayment(
          id: '${c.id}:$i',
          contractId: c.id,
          date: dates[i],
          principal: principal,
          interest: interest,
        ),
      );
      previous = dates[i];
    }
    return payments;
  }

  Future<void> create(
    FinanceContract c, {
    bool fundNow = false,
  }) => ledger.db.transaction(() async {
    if (c.name.trim().isEmpty) throw ArgumentError('Enter contract name');
    if ([ContractKind.deposit, ContractKind.certificate].contains(c.kind) &&
        c.interestMethod == 'reducing') {
      throw ArgumentError(
        'Deposits use periodic coupons or an agreed manual schedule',
      );
    }
    if (c.accountId != null) {
      final account = await ledger.db.getAccountById(c.accountId!);
      if (account == null ||
          account.currency != c.currency ||
          account.type == 'credit') {
        throw ArgumentError('Choose a cash account in the contract currency');
      }
    }
    if (c.kind == ContractKind.creditCard) {
      final card = c.cardAccountId == null
          ? null
          : await ledger.db.getAccountById(c.cardAccountId!);
      if (card?.type != 'credit' || card?.currency != c.currency) {
        throw ArgumentError('Choose a credit card in the contract currency');
      }
      if ((await ContractRepository(
        store,
      ).getAll()).any((other) => other.cardAccountId == c.cardAccountId)) {
        throw ArgumentError('This card already has a billing contract');
      }
    }
    if (c.kind == ContractKind.creditCard && c.cardAccountId == null) {
      throw ArgumentError('Select the linked credit card');
    }
    final payments = schedule(c);
    if (fundNow) {
      if (c.accountId == null || c.kind == ContractKind.creditCard) {
        throw ArgumentError('Select a funding account');
      }
      final account = await ledger.db.getAccountById(c.accountId!);
      if (account?.currency != c.currency) {
        throw ArgumentError('Funding account must use the contract currency');
      }
      await ledger.recordCash(
        accountId: c.accountId!,
        amount: c.principal,
        type: c.kind == ContractKind.loan ? 'income' : 'expense',
        kind: 'principal',
        note: 'Principal: ${c.name}',
        date: c.start,
      );
    }
    await ContractRepository(store).save(c);
    for (final p in payments) {
      await store.put('payments', p.id, p.toJson());
    }
  });
  Future<void> addPayment(ScheduledPayment p) async {
    if (p.principal < Amount.zero ||
        p.interest < Amount.zero ||
        p.total <= Amount.zero) {
      throw ArgumentError('Enter positive payment components');
    }
    final data = await store.get('contracts', p.contractId);
    if (data == null || data['interestMethod'] != 'manual') {
      throw StateError('Only manual schedules can be changed');
    }
    await store.put('payments', p.id, p.toJson());
  }

  Future<void> confirm(String paymentId, {int? accountId}) =>
      ledger.db.transaction(() async {
        final data = await store.get('payments', paymentId);
        if (data == null) throw StateError('Payment no longer exists');
        final p = ScheduledPayment.fromJson(data);
        if (p.paid) return;
        final c = FinanceContract.fromJson(
          (await store.get('contracts', p.contractId))!,
        );
        final cashId = accountId ?? c.accountId;
        if (cashId == null) throw ArgumentError('Choose a cash account');
        final account = await ledger.db.getAccountById(cashId);
        if (account?.currency != c.currency) {
          throw ArgumentError('Choose an account in ${c.currency}');
        }
        final before = (await ledger.db.getAllTransactions())
            .map((t) => t.id)
            .toSet();
        if (c.kind == ContractKind.creditCard) {
          if (c.cardAccountId == null) throw StateError('Missing card account');
          await ledger.transfer(
            fromAccountId: cashId,
            toAccountId: c.cardAccountId!,
            amount: p.total,
            note: 'Card settlement: ${c.name}',
          );
        } else {
          final type = c.kind == ContractKind.loan ? 'expense' : 'income';
          if (p.principal > Amount.zero) {
            await ledger.recordCash(
              accountId: cashId,
              amount: p.principal,
              type: type,
              kind: 'principal',
              note: 'Principal: ${c.name}',
              date: DateTime.now(),
            );
          }
          if (p.interest > Amount.zero) {
            await ledger.recordCash(
              accountId: cashId,
              amount: p.interest,
              type: type,
              kind: 'contractInterest',
              note: 'Interest: ${c.name}',
              date: DateTime.now(),
            );
          }
        }
        final ids = (await ledger.db.getAllTransactions())
            .where((t) => !before.contains(t.id))
            .map((t) => t.id)
            .toList();
        for (final id in ids) {
          await store.setTransactionDetails(id, {
            ...(await store.transactionDetails(id))!,
            'contractPaymentId': p.id,
          });
        }
        await store.put('payments', p.id, {
          ...data,
          ...p.toJson(),
          'transactionIds': ids,
          'paid': true,
          'paidAt': DateTime.now().toIso8601String(),
        });
      });
  Future<void> reverseConfirmation(String id) =>
      ledger.db.transaction(() async {
        final data = await store.get('payments', id);
        if (data == null || data['paid'] != true) {
          throw StateError('This payment is not confirmed');
        }
        final ids = (data['transactionIds'] as List? ?? []).cast<int>();
        if (ids.isEmpty) {
          throw StateError(
            'This legacy payment has no recorded ledger references',
          );
        }
        for (final tx in ids) {
          if (await ledger.db.getTransactionById(tx) != null) {
            await ledger.db.deleteTransactionAndUpdateBalance(tx);
          }
        }
        if (data['cancelledPayments'] is List) {
          for (final row in data['cancelledPayments'] as List) {
            final j = Map<String, dynamic>.from(row as Map);
            await store.put('payments', j['id'], j);
          }
          await store.remove('payments', id);
        } else {
          await store.put('payments', id, {
            ...data,
            'paid': false,
            'paidAt': null,
            'transactionIds': <int>[],
          });
        }
      });

  Future<Json> cardStatement(FinanceContract c, {DateTime? now}) async {
    if (c.cardAccountId == null) throw StateError('No linked card');
    final date = now ?? DateTime.now();
    DateTime cutoff(int month) {
      final start = DateTime(date.year, month, 1),
          last = DateTime(date.year, month + 1, 0).day;
      return DateTime(
        start.year,
        start.month,
        c.statementDay > last ? last : c.statementDay,
      );
    }

    var closing = cutoff(date.month);
    if (closing.isAfter(date)) closing = cutoff(date.month - 1);
    final prior = DateTime(closing.year, closing.month - 1, 1);
    final priorLast = DateTime(prior.year, prior.month + 1, 0).day;
    final previous = DateTime(
      prior.year,
      prior.month,
      c.statementDay > priorLast ? priorLast : c.statementDay,
    );
    var billed = Amount.zero,
        unbilled = Amount.zero,
        older = Amount.zero,
        credit = Amount.zero;
    final openingRows = await ledger.db
        .customSelect(
          'SELECT opening FROM exact_balances WHERE account_id = ${c.cardAccountId!}',
        )
        .get();
    final opening = openingRows.isEmpty
        ? Amount.zero
        : amountOf(openingRows.single.read<String>('opening'));
    if (opening >= Amount.zero) {
      older = opening;
    } else {
      credit = -opening;
    }
    final history = await ledger.db.getTransactionsByAccount(c.cardAccountId!);
    history.sort((a, b) {
      final order = a.transactionDate.compareTo(b.transactionDate);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    for (final t in history) {
      final details = await store.transactionDetails(t.id);
      var amount = details == null
          ? Amount.fromNum(t.amount)
          : amountOf(details['amount']);
      if (t.type == 'expense') {
        final prepaid = credit < amount ? credit : amount;
        credit -= prepaid;
        amount -= prepaid;
        if (!t.transactionDate.isBefore(closing)) {
          unbilled += amount;
        } else if (!t.transactionDate.isBefore(previous)) {
          billed += amount;
        } else {
          older += amount;
        }
      } else {
        final oldPaid = older < amount ? older : amount;
        older -= oldPaid;
        amount -= oldPaid;
        final billPaid = billed < amount ? billed : amount;
        billed -= billPaid;
        amount -= billPaid;
        final newPaid = unbilled < amount ? unbilled : amount;
        unbilled -= newPaid;
        amount -= newPaid;
        credit += amount;
      }
    }
    final balance = await store.balance(c.cardAccountId!);
    final unallocated = balance - (older + billed + unbilled - credit);
    older += unallocated;
    final dueMonth = c.paymentDay <= c.statementDay
        ? closing.month + 1
        : closing.month;
    final dueStart = DateTime(closing.year, dueMonth, 1),
        dueLast = DateTime(closing.year, dueMonth + 1, 0).day;
    final due = DateTime(
      dueStart.year,
      dueStart.month,
      c.paymentDay > dueLast ? dueLast : c.paymentDay,
    );
    return {
      'billed': '$billed',
      'unbilled': '$unbilled',
      'olderOrOpening': '$older',
      'credit': '$credit',
      'outstanding': '$balance',
      'due': due.toIso8601String(),
    };
  }

  Future<void> earlySettle(
    String contractId,
    int accountId,
    Amount principal,
    Amount interest,
  ) => ledger.db.transaction(() async {
    final c = FinanceContract.fromJson(
      (await store.get('contracts', contractId))!,
    );
    final existing = await ContractRepository(store).payments(contractId);
    final outstanding =
        c.principal -
        existing
            .where((p) => p.paid)
            .fold(Amount.zero, (s, p) => s + p.principal);
    if (principal != outstanding || interest < Amount.zero) {
      throw ArgumentError(
        'Settlement principal must equal recorded outstanding principal',
      );
    }
    final p = ScheduledPayment(
      id: ledger.newId(),
      contractId: contractId,
      date: DateTime.now(),
      principal: principal,
      interest: interest,
    );
    await store.put('payments', p.id, {
      ...p.toJson(),
      'cancelledPayments': existing
          .where((p) => !p.paid)
          .map((p) => p.toJson())
          .toList(),
    });
    await confirm(p.id, accountId: accountId);
    for (final pending in existing.where((p) => !p.paid)) {
      await store.remove('payments', pending.id);
    }
  });
}
