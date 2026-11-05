import 'package:flutter/material.dart';

class IconUtils {
  IconUtils._();

  static IconData accountIcon(String name) {
    switch (name) {
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'wallet':
        return Icons.wallet_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'currency_exchange':
        return Icons.currency_exchange_rounded;
      case 'monetization_on':
        return Icons.monetization_on_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  /// Every icon name a category may use. Pickers and the AI category
  /// proposals are restricted to these keys, so nothing renders as a blank
  /// circle.
  static const Map<String, IconData> categoryIcons = {
    'payments': Icons.payments_rounded,
    'laptop': Icons.laptop_rounded,
    'trending_up': Icons.trending_up_rounded,
    'restaurant': Icons.restaurant_rounded,
    'directions_car': Icons.directions_car_rounded,
    'flight': Icons.flight_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'movie': Icons.movie_rounded,
    'favorite': Icons.favorite_rounded,
    'school': Icons.school_rounded,
    'home': Icons.home_rounded,
    'more_horiz': Icons.more_horiz_rounded,
    'account_balance': Icons.account_balance_rounded,
    'account_balance_wallet': Icons.account_balance_wallet_rounded,
    'credit_card': Icons.credit_card_rounded,
    'savings': Icons.savings_rounded,
    'wallet': Icons.wallet_rounded,
    'currency_exchange': Icons.currency_exchange_rounded,
    'monetization_on': Icons.monetization_on_rounded,
    'category': Icons.category_rounded,
    'swap_horiz': Icons.swap_horiz_rounded,
    'south_west': Icons.south_west_rounded,
    'north_east': Icons.north_east_rounded,
    'pets': Icons.pets_rounded,
    'child_care': Icons.child_care_rounded,
    'sports_soccer': Icons.sports_soccer_rounded,
    'music_note': Icons.music_note_rounded,
    'coffee': Icons.coffee_rounded,
    'work': Icons.work_rounded,
    'local_hospital': Icons.local_hospital_rounded,
    'local_grocery_store': Icons.local_grocery_store_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'fastfood': Icons.fastfood_rounded,
    'local_bar': Icons.local_bar_rounded,
    'local_gas_station': Icons.local_gas_station_rounded,
    'local_taxi': Icons.local_taxi_rounded,
    'train': Icons.train_rounded,
    'directions_bus': Icons.directions_bus_rounded,
    'local_parking': Icons.local_parking_rounded,
    'electric_bolt': Icons.electric_bolt_rounded,
    'water_drop': Icons.water_drop_rounded,
    'wifi': Icons.wifi_rounded,
    'phone_iphone': Icons.phone_iphone_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'medical_services': Icons.medical_services_rounded,
    'local_pharmacy': Icons.local_pharmacy_rounded,
    'spa': Icons.spa_rounded,
    'content_cut': Icons.content_cut_rounded,
    'checkroom': Icons.checkroom_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'volunteer_activism': Icons.volunteer_activism_rounded,
    'celebration': Icons.celebration_rounded,
    'hotel': Icons.hotel_rounded,
    'luggage': Icons.luggage_rounded,
    'build': Icons.build_rounded,
    'cleaning_services': Icons.cleaning_services_rounded,
    'chair': Icons.chair_rounded,
    'menu_book': Icons.menu_book_rounded,
    'redeem': Icons.redeem_rounded,
    'attach_money': Icons.attach_money_rounded,
    'request_quote': Icons.request_quote_rounded,
    'percent': Icons.percent_rounded,
    'security': Icons.security_rounded,
    'family_restroom': Icons.family_restroom_rounded,
    'baby_changing_station': Icons.baby_changing_station_rounded,
    'directions_bike': Icons.directions_bike_rounded,
    'two_wheeler': Icons.two_wheeler_rounded,
    'car_repair': Icons.car_repair_rounded,
    'local_laundry_service': Icons.local_laundry_service_rounded,
    'theaters': Icons.theaters_rounded,
    'sell': Icons.sell_rounded,
    'storefront': Icons.storefront_rounded,
    'computer': Icons.computer_rounded,
    'smartphone': Icons.smartphone_rounded,
    'toys': Icons.toys_rounded,
    'park': Icons.park_rounded,
    'local_florist': Icons.local_florist_rounded,
    'beach_access': Icons.beach_access_rounded,
    'church': Icons.church_rounded,
    'mosque': Icons.mosque_rounded,
    'gavel': Icons.gavel_rounded,
    'handshake': Icons.handshake_rounded,
    'business_center': Icons.business_center_rounded,
    'apartment': Icons.apartment_rounded,
    'real_estate_agent': Icons.real_estate_agent_rounded,
    'local_shipping': Icons.local_shipping_rounded,
    'receipt': Icons.receipt_rounded,
    'cake': Icons.cake_rounded,
    'undo': Icons.undo_rounded,
  };

  static IconData categoryIcon(String name) =>
      categoryIcons[name] ?? Icons.category_rounded;
}
