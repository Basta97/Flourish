class AppConstants {
  AppConstants._();

  static const String appName = 'BastaSaving';
  static const String defaultCurrency = 'USD';

  static const List<String> currencies = [
    'USD', 'EGP', 'EUR', 'GBP', 'JPY', 'CNY', 'INR', 'IDR', 'MYR', 'SAR', 'AED'
  ];

  static List<Map<String, dynamic>> defaultCategories() {
    return [
      {'name': 'Salary', 'icon': 'payments', 'color': 0xFF10B981, 'type': 'income', 'isDefault': true, 'sortOrder': 0},
      {'name': 'Freelance', 'icon': 'laptop', 'color': 0xFF3B82F6, 'type': 'income', 'isDefault': true, 'sortOrder': 1},
      {'name': 'Investment', 'icon': 'trending_up', 'color': 0xFF8B5CF6, 'type': 'income', 'isDefault': true, 'sortOrder': 2},
      {'name': 'Food & Drinks', 'icon': 'restaurant', 'color': 0xFFEF4444, 'type': 'expense', 'isDefault': true, 'sortOrder': 3},
      {'name': 'Transport', 'icon': 'directions_car', 'color': 0xFFF59E0B, 'type': 'expense', 'isDefault': true, 'sortOrder': 4},
      {'name': 'Shopping', 'icon': 'shopping_bag', 'color': 0xFFEC4899, 'type': 'expense', 'isDefault': true, 'sortOrder': 5},
      {'name': 'Bills & Utilities', 'icon': 'receipt_long', 'color': 0xFF6366F1, 'type': 'expense', 'isDefault': true, 'sortOrder': 6},
      {'name': 'Entertainment', 'icon': 'movie', 'color': 0xFF14B8A6, 'type': 'expense', 'isDefault': true, 'sortOrder': 7},
      {'name': 'Health', 'icon': 'favorite', 'color': 0xFFE11D48, 'type': 'expense', 'isDefault': true, 'sortOrder': 8},
      {'name': 'Education', 'icon': 'school', 'color': 0xFF0EA5E9, 'type': 'expense', 'isDefault': true, 'sortOrder': 9},
      {'name': 'Housing', 'icon': 'home', 'color': 0xFFD97706, 'type': 'expense', 'isDefault': true, 'sortOrder': 10},
      {'name': 'Other', 'icon': 'more_horiz', 'color': 0xFF6B7280, 'type': 'expense', 'isDefault': true, 'sortOrder': 11},
    ];
  }

  static List<Map<String, dynamic>> defaultAccounts() {
    return [
      {'name': 'Cash', 'type': 'cash', 'balance': 0, 'currency': 'USD', 'color': 0xFF10B981, 'icon': 'account_balance_wallet'},
      {'name': 'Bank Account', 'type': 'bank', 'balance': 0, 'currency': 'USD', 'color': 0xFF3B82F6, 'icon': 'account_balance'},
    ];
  }

  static const List<String> accountIcons = [
    'account_balance',
    'account_balance_wallet',
    'credit_card',
    'savings',
    'payments',
    'wallet',
    'currency_exchange',
    'monetization_on',
  ];

  static const List<Map<String, dynamic>> accountTypeOptions = [
    {'label': 'Bank Account', 'value': 'bank', 'icon': 'account_balance'},
    {'label': 'Cash', 'value': 'cash', 'icon': 'account_balance_wallet'},
    {'label': 'E-Wallet', 'value': 'ewallet', 'icon': 'wallet'},
    {'label': 'Credit Card', 'value': 'credit', 'icon': 'credit_card'},
  ];
}
