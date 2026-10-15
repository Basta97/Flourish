import '../../data/database/database.dart' show TransactionLogicException;

/// A short, user-facing description of a ledger or validation failure,
/// without Dart's "Bad state:" / "Invalid argument(s):" prefixes.
String describeError(Object e) => switch (e) {
  TransactionLogicException(:final message) => message,
  StateError(:final message) => message,
  ArgumentError(:final message) => '$message',
  FormatException(:final message) => message,
  _ => '$e',
};
