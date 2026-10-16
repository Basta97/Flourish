import '../../domain/finance/models.dart';

/// A message as it reached Flourish, before parsing.
class RawMessage {
  final String text;

  /// SMS sender id or notification title, e.g. "CIB" or "Vodafone Cash".
  final String? sender;

  /// Android package that posted the notification.
  final String? packageName;
  final DateTime receivedAt;

  /// android_notification, android_share, ios_shortcut, ios_wallet,
  /// ios_share, paste, ocr.
  final String source;
  const RawMessage({
    required this.text,
    required this.receivedAt,
    required this.source,
    this.sender,
    this.packageName,
  });
}

/// What a bank or wallet message says happened.
class ParsedPayment {
  static const version = 1;

  /// purchase, withdrawal, transfer_out, transfer_in, deposit, refund,
  /// bill_payment, card_payment, fee; null when unknown.
  final String? kind;

  /// expense or income.
  final String direction;
  final Amount? amount;
  final String? currency;

  /// What the account was charged when the purchase was in another currency.
  final Amount? bookedAmount;
  final String? bookedCurrency;
  final Amount? fee;
  final String? last4, merchant, counterparty, reference, issuerId;
  final DateTime? occurredAt;
  final Amount? balanceAfter, availableCredit;
  final double confidence;

  /// otp, declined, promo, no_amount — the message is not a payment.
  final String? ignoreReason;
  const ParsedPayment({
    required this.kind,
    required this.direction,
    required this.amount,
    required this.currency,
    this.bookedAmount,
    this.bookedCurrency,
    this.fee,
    this.last4,
    this.merchant,
    this.counterparty,
    this.reference,
    this.issuerId,
    this.occurredAt,
    this.balanceAfter,
    this.availableCredit,
    required this.confidence,
    this.ignoreReason,
  });

  const ParsedPayment.ignored(this.ignoreReason)
    : kind = null,
      direction = 'expense',
      amount = null,
      currency = null,
      bookedAmount = null,
      bookedCurrency = null,
      fee = null,
      last4 = null,
      merchant = null,
      counterparty = null,
      reference = null,
      issuerId = null,
      occurredAt = null,
      balanceAfter = null,
      availableCredit = null,
      confidence = 0;

  bool get ignored => ignoreReason != null;

  Json toJson() => {
    'version': version,
    'kind': kind,
    'direction': direction,
    'amount': amount?.toString(),
    'currency': currency,
    'bookedAmount': bookedAmount?.toString(),
    'bookedCurrency': bookedCurrency,
    'fee': fee?.toString(),
    'last4': last4,
    'merchant': merchant,
    'counterparty': counterparty,
    'reference': reference,
    'issuerId': issuerId,
    'occurredAt': occurredAt?.toIso8601String(),
    'balanceAfter': balanceAfter?.toString(),
    'availableCredit': availableCredit?.toString(),
    'confidence': confidence,
    'ignoreReason': ignoreReason,
  };

  factory ParsedPayment.fromJson(Json j) {
    Amount? a(String key) => j[key] == null ? null : amountOf(j[key]);
    return ParsedPayment(
      kind: j['kind'],
      direction: j['direction'] ?? 'expense',
      amount: a('amount'),
      currency: j['currency'],
      bookedAmount: a('bookedAmount'),
      bookedCurrency: j['bookedCurrency'],
      fee: a('fee'),
      last4: j['last4'],
      merchant: j['merchant'],
      counterparty: j['counterparty'],
      reference: j['reference'],
      issuerId: j['issuerId'],
      occurredAt: j['occurredAt'] == null
          ? null
          : DateTime.parse(j['occurredAt']),
      balanceAfter: a('balanceAfter'),
      availableCredit: a('availableCredit'),
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      ignoreReason: j['ignoreReason'],
    );
  }
}
