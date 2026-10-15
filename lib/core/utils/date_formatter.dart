import 'package:intl/intl.dart';

class DateFormatter {
  static String format(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(date);
    if (date.year == now.year) return DateFormat('MMM d').format(date);
    return DateFormat('MMM d, y').format(date);
  }

  static String formatMonth(DateTime date) {
    return DateFormat('MMMM y').format(date);
  }

  static String formatDay(DateTime date) {
    return DateFormat('d').format(date);
  }

  static String formatFull(DateTime date) {
    return DateFormat('MMM d, y – HH:mm').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMM y').format(date);
  }

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }
}
