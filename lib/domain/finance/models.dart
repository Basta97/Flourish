import 'amount.dart';
export 'amount.dart';

typedef Json = Map<String, dynamic>;
Amount amountOf(dynamic value) => Amount((value ?? '0').toString());
DateTime dateOf(dynamic value) => DateTime.parse(value as String);

enum AssetKind { gold, stock, fund, crypto, property, custom }

enum ActivityKind {
  opening,
  buy,
  sell,
  fee,
  dividend,
  interest,
  rent,
  split,
  adjustment,
  payment,
  coupon,
  maturity,
}

enum ContractKind { deposit, certificate, loan, receivable, creditCard }

class Holding {
  final String id, name, symbol, exchange, currency, unit, custody, valuation;
  final AssetKind kind;
  final Amount quantity, ownership;
  final Amount? costBasis;
  final int karat;
  final String? linkedContractId;
  final DateTime openedAt;
  const Holding({
    required this.id,
    required this.name,
    required this.kind,
    required this.quantity,
    required this.currency,
    required this.openedAt,
    this.costBasis,
    this.symbol = '',
    this.exchange = '',
    this.unit = 'units',
    this.custody = '',
    this.valuation = 'manual',
    required this.ownership,
    this.karat = 24,
    this.linkedContractId,
  });
  Holding copy({
    Amount? quantity,
    Amount? costBasis,
    bool clearCost = false,
    String? custody,
    String? valuation,
    String? linkedContractId,
    bool clearContract = false,
  }) => Holding(
    id: id,
    name: name,
    kind: kind,
    quantity: quantity ?? this.quantity,
    currency: currency,
    openedAt: openedAt,
    costBasis: clearCost ? null : costBasis ?? this.costBasis,
    symbol: symbol,
    exchange: exchange,
    unit: unit,
    custody: custody ?? this.custody,
    valuation: valuation ?? this.valuation,
    ownership: ownership,
    karat: karat,
    linkedContractId: clearContract
        ? null
        : linkedContractId ?? this.linkedContractId,
  );
  Json toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'quantity': '$quantity',
    'currency': currency,
    'openedAt': openedAt.toIso8601String(),
    'costBasis': costBasis?.toString(),
    'symbol': symbol,
    'exchange': exchange,
    'unit': unit,
    'custody': custody,
    'valuation': valuation,
    'ownership': '$ownership',
    'karat': karat,
    'linkedContractId': linkedContractId,
  };
  factory Holding.fromJson(Json j) => Holding(
    id: j['id'],
    name: j['name'],
    kind: AssetKind.values.byName(j['kind']),
    quantity: amountOf(j['quantity']),
    currency: j['currency'],
    openedAt: dateOf(j['openedAt']),
    costBasis: j['costBasis'] == null ? null : amountOf(j['costBasis']),
    symbol: j['symbol'] ?? '',
    exchange: j['exchange'] ?? '',
    unit: j['unit'] ?? 'units',
    custody: j['custody'] ?? '',
    valuation: j['valuation'] ?? 'manual',
    ownership: amountOf(j['ownership'] ?? '1'),
    karat: j['karat'] ?? 24,
    linkedContractId: j['linkedContractId'],
  );
}

class MarketObservation {
  final String key, currency, source;
  final Amount value;
  final DateTime effectiveAt, retrievedAt;
  final bool manual;
  const MarketObservation({
    required this.key,
    required this.currency,
    required this.source,
    required this.value,
    required this.effectiveAt,
    required this.retrievedAt,
    this.manual = false,
  });
  bool stale(DateTime now) => now.difference(effectiveAt).inHours > 72;
  Json toJson() => {
    'key': key,
    'currency': currency,
    'source': source,
    'value': '$value',
    'effectiveAt': effectiveAt.toIso8601String(),
    'retrievedAt': retrievedAt.toIso8601String(),
    'manual': manual,
  };
  factory MarketObservation.fromJson(Json j) => MarketObservation(
    key: j['key'],
    currency: j['currency'],
    source: j['source'],
    value: amountOf(j['value']),
    effectiveAt: dateOf(j['effectiveAt']),
    retrievedAt: dateOf(j['retrievedAt']),
    manual: j['manual'] == true,
  );
}

/// A credit card's terms. Percentages and amounts are exact decimals in the
/// card's currency; [FinanceContract.annualRate] stays the purchase APR.
class CardTerms {
  final Amount creditLimit, minPaymentPercent, minPaymentFloor;
  final Amount fxFeePercent, cashAdvanceFeePercent, cashAdvanceFeeMin;
  final Amount cashAdvanceApr, lateFee;
  CardTerms({
    required this.creditLimit,
    Amount? minPaymentPercent,
    Amount? minPaymentFloor,
    Amount? fxFeePercent,
    Amount? cashAdvanceFeePercent,
    Amount? cashAdvanceFeeMin,
    Amount? cashAdvanceApr,
    Amount? lateFee,
  }) : minPaymentPercent = minPaymentPercent ?? Amount('5'),
       minPaymentFloor = minPaymentFloor ?? Amount.zero,
       fxFeePercent = fxFeePercent ?? Amount.zero,
       cashAdvanceFeePercent = cashAdvanceFeePercent ?? Amount.zero,
       cashAdvanceFeeMin = cashAdvanceFeeMin ?? Amount.zero,
       cashAdvanceApr = cashAdvanceApr ?? Amount.zero,
       lateFee = lateFee ?? Amount.zero;

  /// Rejects terms no card would have.
  void validate() {
    final percents = [
      minPaymentPercent,
      fxFeePercent,
      cashAdvanceFeePercent,
      cashAdvanceApr,
    ];
    if (creditLimit < Amount.zero ||
        minPaymentFloor < Amount.zero ||
        cashAdvanceFeeMin < Amount.zero ||
        lateFee < Amount.zero ||
        percents.any((p) => p < Amount.zero || p > Amount('100'))) {
      throw ArgumentError('Check the card limit, fees and percentages');
    }
  }

  Json toJson() => {
    'creditLimit': '$creditLimit',
    'minPaymentPercent': '$minPaymentPercent',
    'minPaymentFloor': '$minPaymentFloor',
    'fxFeePercent': '$fxFeePercent',
    'cashAdvanceFeePercent': '$cashAdvanceFeePercent',
    'cashAdvanceFeeMin': '$cashAdvanceFeeMin',
    'cashAdvanceApr': '$cashAdvanceApr',
    'lateFee': '$lateFee',
  };
  factory CardTerms.fromJson(Json j) => CardTerms(
    creditLimit: amountOf(j['creditLimit']),
    minPaymentPercent: amountOf(j['minPaymentPercent'] ?? '5'),
    minPaymentFloor: amountOf(j['minPaymentFloor']),
    fxFeePercent: amountOf(j['fxFeePercent']),
    cashAdvanceFeePercent: amountOf(j['cashAdvanceFeePercent']),
    cashAdvanceFeeMin: amountOf(j['cashAdvanceFeeMin']),
    cashAdvanceApr: amountOf(j['cashAdvanceApr']),
    lateFee: amountOf(j['lateFee']),
  );
}

class FinanceContract {
  final String id, name, currency, counterparty, interestMethod;
  final ContractKind kind;
  final Amount principal, annualRate;
  final DateTime start, maturity;
  final int paymentsPerYear;
  final int? accountId, cardAccountId;
  final int statementDay, paymentDay;

  /// Present on credit card contracts once their terms are set.
  final CardTerms? card;
  const FinanceContract({
    required this.id,
    required this.name,
    required this.kind,
    required this.currency,
    required this.principal,
    required this.annualRate,
    required this.start,
    required this.maturity,
    this.counterparty = '',
    this.interestMethod = 'flat',
    this.paymentsPerYear = 12,
    this.accountId,
    this.cardAccountId,
    this.statementDay = 1,
    this.paymentDay = 15,
    this.card,
  });
  bool get isDebt =>
      kind == ContractKind.loan || kind == ContractKind.creditCard;
  Json toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'currency': currency,
    'principal': '$principal',
    'annualRate': '$annualRate',
    'start': start.toIso8601String(),
    'maturity': maturity.toIso8601String(),
    'counterparty': counterparty,
    'interestMethod': interestMethod,
    'paymentsPerYear': paymentsPerYear,
    'accountId': accountId,
    'cardAccountId': cardAccountId,
    'statementDay': statementDay,
    'paymentDay': paymentDay,
    if (card != null) 'card': card!.toJson(),
  };
  factory FinanceContract.fromJson(Json j) => FinanceContract(
    id: j['id'],
    name: j['name'],
    kind: ContractKind.values.byName(j['kind']),
    currency: j['currency'],
    principal: amountOf(j['principal']),
    annualRate: amountOf(j['annualRate']),
    start: dateOf(j['start']),
    maturity: dateOf(j['maturity']),
    counterparty: j['counterparty'] ?? '',
    interestMethod: j['interestMethod'] ?? 'flat',
    paymentsPerYear: j['paymentsPerYear'] ?? 12,
    accountId: j['accountId'],
    cardAccountId: j['cardAccountId'],
    statementDay: j['statementDay'] ?? 1,
    paymentDay: j['paymentDay'] ?? 15,
    card: j['card'] is Map
        ? CardTerms.fromJson(Map<String, dynamic>.from(j['card'] as Map))
        : null,
  );
}

class ScheduledPayment {
  final String id, contractId;
  final DateTime date;
  final Amount principal, interest;
  final bool paid;
  const ScheduledPayment({
    required this.id,
    required this.contractId,
    required this.date,
    required this.principal,
    required this.interest,
    this.paid = false,
  });
  Amount get total => principal + interest;
  Json toJson() => {
    'id': id,
    'contractId': contractId,
    'date': date.toIso8601String(),
    'principal': '$principal',
    'interest': '$interest',
    'paid': paid,
  };
  factory ScheduledPayment.fromJson(Json j) => ScheduledPayment(
    id: j['id'],
    contractId: j['contractId'],
    date: dateOf(j['date']),
    principal: amountOf(j['principal']),
    interest: amountOf(j['interest']),
    paid: j['paid'] == true,
  );
}

class AccountDetails {
  final int accountId;
  final String institution, group;
  final bool archived, included;
  const AccountDetails(
    this.accountId, {
    this.institution = '',
    this.group = '',
    this.archived = false,
    this.included = true,
  });
  Json toJson() => {
    'accountId': accountId,
    'institution': institution,
    'group': group,
    'archived': archived,
    'included': included,
  };
  factory AccountDetails.fromJson(Json j) => AccountDetails(
    j['accountId'],
    institution: j['institution'] ?? '',
    group: j['group'] ?? '',
    archived: j['archived'] == true,
    included: j['included'] != false,
  );
}
