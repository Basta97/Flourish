import 'package:flutter/material.dart';

class IconUtils {
  IconUtils._();

  static IconData accountIcon(String name) {
    switch (name) {
      case 'account_balance':
        return Icons.account_balance;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'credit_card':
        return Icons.credit_card;
      case 'savings':
        return Icons.savings;
      case 'wallet':
        return Icons.wallet;
      case 'payments':
        return Icons.payments;
      case 'currency_exchange':
        return Icons.currency_exchange;
      case 'monetization_on':
        return Icons.monetization_on;
      default:
        return Icons.account_balance_wallet;
    }
  }

  /// Every icon name a category may use. Pickers and the AI category
  /// proposals are restricted to these keys, so nothing renders as a blank
  /// circle.
  static const Map<String, IconData> categoryIcons = {
    'payments': Icons.payments,
    'laptop': Icons.laptop,
    'trending_up': Icons.trending_up,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'flight': Icons.flight,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'movie': Icons.movie,
    'favorite': Icons.favorite,
    'school': Icons.school,
    'home': Icons.home,
    'more_horiz': Icons.more_horiz,
    'account_balance': Icons.account_balance,
    'account_balance_wallet': Icons.account_balance_wallet,
    'credit_card': Icons.credit_card,
    'savings': Icons.savings,
    'wallet': Icons.wallet,
    'currency_exchange': Icons.currency_exchange,
    'monetization_on': Icons.monetization_on,
    'category': Icons.category,
    'swap_horiz': Icons.swap_horiz,
    'south_west': Icons.south_west,
    'north_east': Icons.north_east,
    'pets': Icons.pets,
    'child_care': Icons.child_care,
    'sports_soccer': Icons.sports_soccer,
    'music_note': Icons.music_note,
    'coffee': Icons.coffee,
    'work': Icons.work,
    'local_hospital': Icons.local_hospital,
    'local_grocery_store': Icons.local_grocery_store,
    'shopping_cart': Icons.shopping_cart,
    'local_cafe': Icons.local_cafe,
    'fastfood': Icons.fastfood,
    'local_bar': Icons.local_bar,
    'local_gas_station': Icons.local_gas_station,
    'local_taxi': Icons.local_taxi,
    'train': Icons.train,
    'directions_bus': Icons.directions_bus,
    'local_parking': Icons.local_parking,
    'electric_bolt': Icons.electric_bolt,
    'water_drop': Icons.water_drop,
    'wifi': Icons.wifi,
    'phone_iphone': Icons.phone_iphone,
    'subscriptions': Icons.subscriptions,
    'sports_esports': Icons.sports_esports,
    'fitness_center': Icons.fitness_center,
    'medical_services': Icons.medical_services,
    'local_pharmacy': Icons.local_pharmacy,
    'spa': Icons.spa,
    'content_cut': Icons.content_cut,
    'checkroom': Icons.checkroom,
    'card_giftcard': Icons.card_giftcard,
    'volunteer_activism': Icons.volunteer_activism,
    'celebration': Icons.celebration,
    'hotel': Icons.hotel,
    'luggage': Icons.luggage,
    'build': Icons.build,
    'cleaning_services': Icons.cleaning_services,
    'chair': Icons.chair,
    'menu_book': Icons.menu_book,
    'redeem': Icons.redeem,
    'attach_money': Icons.attach_money,
    'request_quote': Icons.request_quote,
    'percent': Icons.percent,
    'security': Icons.security,
    'family_restroom': Icons.family_restroom,
    'baby_changing_station': Icons.baby_changing_station,
    'directions_bike': Icons.directions_bike,
    'two_wheeler': Icons.two_wheeler,
    'car_repair': Icons.car_repair,
    'local_laundry_service': Icons.local_laundry_service,
    'theaters': Icons.theaters,
    'sell': Icons.sell,
    'storefront': Icons.storefront,
    'computer': Icons.computer,
    'smartphone': Icons.smartphone,
    'toys': Icons.toys,
    'park': Icons.park,
    'local_florist': Icons.local_florist,
    'beach_access': Icons.beach_access,
    'church': Icons.church,
    'mosque': Icons.mosque,
    'gavel': Icons.gavel,
    'handshake': Icons.handshake,
    'business_center': Icons.business_center,
    'apartment': Icons.apartment,
    'real_estate_agent': Icons.real_estate_agent,
    'local_shipping': Icons.local_shipping,
    'receipt': Icons.receipt,
    'cake': Icons.cake,
    'undo': Icons.undo,
  };

  static IconData categoryIcon(String name) =>
      categoryIcons[name] ?? Icons.category_outlined;
}
