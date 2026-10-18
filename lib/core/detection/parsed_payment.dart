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

  /// What is left of the card's international limit, when stated.
  final Amount? availableIntlCredit;
  final double confidence;

  /// otp, declined, promo, no_amount — the message is not a payment.
  final String? ignoreReason;

  /// True once the AI stage reviewed this message.
  final bool aiAssisted;

  /// A category to create on confirm because none of the existing ones fits
  /// (see `ProposedCategory`); stored as its JSON.
  final Json? proposedCategory;
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
    this.availableIntlCredit,
    required this.confidence,
    this.ignoreReason,
    this.aiAssisted = false,
    this.proposedCategory,
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
      availableIntlCredit = null,
      confidence = 0,
      aiAssisted = false,
      proposedCategory = null;

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
    if (availableIntlCredit != null)
      'availableIntlCredit': availableIntlCredit.toString(),
    'confidence': confidence,
    'ignoreReason': ignoreReason,
    if (aiAssisted) 'aiAssisted': true,
    if (proposedCategory != null) 'proposedCategory': proposedCategory,
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
      availableIntlCredit: a('availableIntlCredit'),
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      ignoreReason: j['ignoreReason'],
      aiAssisted: j['aiAssisted'] == true,
      proposedCategory: j['proposedCategory'] as Json?,
    );
  }

  ParsedPayment copyWith({
    String? kind,
    String? direction,
    Amount? amount,
    String? currency,
    String? merchant,
    String? counterparty,
    DateTime? occurredAt,
    double? confidence,
    String? ignoreReason,
    bool clearIgnore = false,
    bool? aiAssisted,
    Json? proposedCategory,
    bool clearProposal = false,
  }) => ParsedPayment(
    kind: kind ?? this.kind,
    direction: direction ?? this.direction,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    bookedAmount: bookedAmount,
    bookedCurrency: bookedCurrency,
    fee: fee,
    last4: last4,
    merchant: merchant ?? this.merchant,
    counterparty: counterparty ?? this.counterparty,
    reference: reference,
    issuerId: issuerId,
    occurredAt: occurredAt ?? this.occurredAt,
    balanceAfter: balanceAfter,
    availableCredit: availableCredit,
    availableIntlCredit: availableIntlCredit,
    confidence: confidence ?? this.confidence,
    ignoreReason: clearIgnore ? null : ignoreReason ?? this.ignoreReason,
    aiAssisted: aiAssisted ?? this.aiAssisted,
    proposedCategory: clearProposal
        ? null
        : proposedCategory ?? this.proposedCategory,
  );
}
