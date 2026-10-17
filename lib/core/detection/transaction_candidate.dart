import '../../domain/finance/amount.dart';

/// What a detected message describes. Only some kinds are real money
/// movements; the rest (codes, offers, reminders) must never be recorded.
enum TransactionKind {
  purchase,
  refund,
  atm,
  transferIn,
  transferOut,
  salary,
  fee,
  declined,
  otp,
  promo,
  paymentDue,
  balanceOnly,
  unknown;

  bool get movesMoney => switch (this) {
    declined || otp || promo || paymentDue || balanceOnly => false,
    _ => true,
  };

  static TransactionKind? tryParse(String? value) {
    if (value == null) return null;
    final key = value.replaceAll('_', '').toLowerCase();
    for (final kind in values) {
      if (kind.name.toLowerCase() == key) return kind;
    }
    return null;
  }
}

/// Which stage produced (or last improved) a candidate.
enum CandidateSource { local, ai, import }

/// A category the AI wants to create because nothing existing fits.
class ProposedCategory {
  const ProposedCategory({
    required this.name,
    required this.type,
    required this.icon,
    required this.colorIndex,
    this.parentName,
  });

  final String name;
  final String type;
  final String icon;
  final int colorIndex;
  final String? parentName;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'icon': icon,
    'colorIndex': colorIndex,
    'parentName': parentName,
  };

  factory ProposedCategory.fromJson(Map<String, dynamic> json) =>
      ProposedCategory(
        name: json['name'] as String,
        type: json['type'] as String,
        icon: json['icon'] as String,
        colorIndex: json['colorIndex'] as int,
        parentName: json['parentName'] as String?,
      );
}

/// One transaction extracted from a message, statement row or file, before
/// the user confirms it. Every field the parser could not find is null.
class TransactionCandidate {
  const TransactionCandidate({
    required this.rawText,
    required this.type,
    required this.kind,
    required this.fieldConfidence,
    required this.confidence,
    required this.fingerprint,
    this.amount,
    this.currency,
    this.date,
    this.merchant = '',
    this.merchantKey = '',
    this.cardLast4,
    this.reference,
    this.bankHint,
    this.categoryHint,
    this.aiCategoryId,
    this.aiProposedCategory,
    this.source = CandidateSource.local,
  });

  final String rawText;
  final Amount? amount;

  /// ISO 4217 code, when the message names one.
  final String? currency;

  /// When the message says it happened; null means "use now".
  final DateTime? date;

  /// 'expense' or 'income'.
  final String type;
  final TransactionKind kind;
  final String merchant;

  /// [merchant] normalised for memory lookups ("SQ *Blue Bottle #12" →
  /// "blue bottle").
  final String merchantKey;
  final String? cardLast4;
  final String? reference;
  final String? bankHint;

  /// A category concept from the local keyword table, e.g. 'groceries'.
  final String? categoryHint;
  final int? aiCategoryId;
  final ProposedCategory? aiProposedCategory;

  /// Per-field confidence in [0, 1] for amount, type, merchant, date and
  /// currency.
  final Map<String, double> fieldConfidence;
  final double confidence;

  /// Stable hash of the normalised message, for duplicate checks and caching.
  final String fingerprint;
  final CandidateSource source;

  bool get isTransaction => kind.movesMoney && amount != null;
  bool get isExpense => type == 'expense';

  TransactionCandidate copyWith({
    Amount? amount,
    String? currency,
    DateTime? date,
    String? type,
    TransactionKind? kind,
    String? merchant,
    String? merchantKey,
    String? cardLast4,
    String? categoryHint,
    int? aiCategoryId,
    ProposedCategory? aiProposedCategory,
    Map<String, double>? fieldConfidence,
    double? confidence,
    CandidateSource? source,
  }) => TransactionCandidate(
    rawText: rawText,
    fingerprint: fingerprint,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    date: date ?? this.date,
    type: type ?? this.type,
    kind: kind ?? this.kind,
    merchant: merchant ?? this.merchant,
    merchantKey: merchantKey ?? this.merchantKey,
    cardLast4: cardLast4 ?? this.cardLast4,
    reference: reference,
    bankHint: bankHint,
    categoryHint: categoryHint ?? this.categoryHint,
    aiCategoryId: aiCategoryId ?? this.aiCategoryId,
    aiProposedCategory: aiProposedCategory ?? this.aiProposedCategory,
    fieldConfidence: fieldConfidence ?? this.fieldConfidence,
    confidence: confidence ?? this.confidence,
    source: source ?? this.source,
  );
}
