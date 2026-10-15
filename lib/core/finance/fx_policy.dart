/// Rules for which exchange rate may price an entry dated in the past.
class FxPolicy {
  FxPolicy._();

  /// A rate older than this before the entry date is too far away to stand
  /// in for that day's rate (weekends and holidays fit comfortably inside).
  /// Without this limit a pre-devaluation EGP rate could be frozen into
  /// entries months later.
  static const historicalWindow = Duration(days: 7);

  /// Whether a rate effective at [effective] may price an entry on [date].
  static bool usableFor(DateTime effective, DateTime date) {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final end = DateTime.utc(date.year, date.month, date.day + 1);
    return effective.isBefore(end) &&
        !effective.isBefore(dayStart.subtract(historicalWindow));
  }
}
