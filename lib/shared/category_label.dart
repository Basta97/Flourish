import '../data/database/database.dart';
import '../l10n/l10n.dart';

/// Built-in categories are stored with English names; show them in the
/// app's language. Categories the person named are shown as typed.
extension CategoryDisplayName on Category {
  String get displayName {
    final l = currentL10n;
    return switch (name) {
      'Salary' => l.catSalary,
      'Freelance' => l.catFreelance,
      'Investment' => l.catInvestment,
      'Food & Drinks' => l.catFood,
      'Transport' => l.catTransport,
      'Shopping' => l.catShopping,
      'Bills & Utilities' => l.catBills,
      'Entertainment' => l.catEntertainment,
      'Health' => l.catHealth,
      'Education' => l.catEducation,
      'Housing' => l.catHousing,
      'Other' => l.other,
      'Other income' => l.otherIncome,
      'Transfer Out' => l.catTransferOut,
      'Transfer In' => l.catTransferIn,
      'Investment purchases' => l.catInvestmentPurchases,
      'Investment sales' => l.catInvestmentSales,
      'Principal paid' => l.catPrincipalPaid,
      'Principal received' => l.catPrincipalReceived,
      'Bank fees' => l.catBankFees,
      'Investment fees' => l.feesInvestment,
      'Interest & charges' => l.catInterestCharges,
      'Interest earned' => l.catInterestEarned,
      _ => name,
    };
  }
}
