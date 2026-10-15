import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';

/// Proxy provider that MUST be overridden at the root [ProviderScope].
/// This prevents accidental database recreation and ensures lifecycle
/// is managed in one place ([main.dart]).
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnsupportedError(
    'databaseProvider must be overridden with a live AppDatabase instance.',
  );
});

/// Convenience providers that simply forward to [databaseProvider].
/// They are useful when you want to inject a repository later and keep
/// the call-site readable.
final accountDaoProvider = Provider<AppDatabase>(
  (ref) => ref.watch(databaseProvider),
);
final transactionDaoProvider = Provider<AppDatabase>(
  (ref) => ref.watch(databaseProvider),
);
final categoryDaoProvider = Provider<AppDatabase>(
  (ref) => ref.watch(databaseProvider),
);
final budgetDaoProvider = Provider<AppDatabase>(
  (ref) => ref.watch(databaseProvider),
);
