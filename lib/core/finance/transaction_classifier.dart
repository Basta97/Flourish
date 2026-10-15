import '../../data/database/database.dart';
import '../../domain/finance/models.dart';
import 'system_categories.dart';

/// How an entry counts in cash-flow reporting.
enum FlowClass {
  income,
  spending,

  /// Money back for an earlier purchase: reduces spending rather than adding
  /// income.
  refund,

  /// Moves between the person's own accounts; never income or spending.
  transfer,
  investment,
  principal;

  bool get isCashFlow => this == income || this == spending || this == refund;
}

/// The single rule every screen uses to decide whether an entry is income,
/// spending, a refund, or a movement that must stay out of totals.
class TransactionClassifier {
  TransactionClassifier._();

  static FlowClass classify(Transaction t, Json? details, Category? category) {
    switch (details?['kind']) {
      case 'transfer':
        return FlowClass.transfer;
      case 'asset':
        return FlowClass.investment;
      case 'principal':
        return FlowClass.principal;
      case 'refund':
        return FlowClass.refund;
    }
    if (t.linkedTransactionId != null) return FlowClass.transfer;
    // Entries written before conversion details existed are recognised by
    // their system category.
    switch (SystemCategories.of(category)?.key) {
      case 'transfer_in' || 'transfer_out':
        return FlowClass.transfer;
      case 'investment_buy' || 'investment_sell':
        return FlowClass.investment;
      case 'principal_in' || 'principal_out':
        return FlowClass.principal;
    }
    return t.type == 'income' ? FlowClass.income : FlowClass.spending;
  }
}
