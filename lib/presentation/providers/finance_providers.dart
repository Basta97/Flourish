import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/finance/financial_ledger_service.dart';
import '../../core/finance/contract_service.dart';
import '../../core/finance/recurring_service.dart';
import '../../core/finance/credit_card_service.dart';
import '../../data/database/database.dart';
import '../../core/finance/market_data_service.dart';
import '../../core/finance/valuation_service.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import 'theme_providers.dart';
import 'transaction_providers.dart';
export '../../domain/finance/models.dart';

final financeStoreProvider = Provider(
  (ref) => FinanceStore(ref.watch(databaseProvider)),
);
final financialLedgerProvider = Provider(
  (ref) => FinancialLedgerService(ref.watch(databaseProvider)),
);
final recurringServiceProvider = Provider(
  (ref) => RecurringService(ref.watch(financialLedgerProvider)),
);
final creditCardServiceProvider = Provider(
  (ref) => CreditCardService(ref.watch(financialLedgerProvider)),
);

/// Every card and wallet, defaults first.
final paymentInstrumentsProvider = StreamProvider<List<PaymentInstrument>>(
  (ref) => ref.watch(databaseProvider).watchPaymentInstruments(),
);

/// Conversion and linkage details of one transaction.
final transactionDetailsProvider = FutureProvider.family<Json?, int>((ref, id) {
  ref.watch(transactionsProvider);
  return ref.watch(financeStoreProvider).transactionDetails(id);
});

/// A credit card's live status, refreshed whenever finances change.
final creditStatusProvider = StreamProvider.family<CreditStatus, int>((
  ref,
  accountId,
) async* {
  final service = ref.watch(creditCardServiceProvider);
  yield await service.status(accountId);
  await for (final _ in ref.watch(databaseProvider).financeChanges.stream) {
    yield await service.status(accountId);
  }
});

final contractServiceProvider = Provider(
  (ref) => ContractService(ref.watch(financialLedgerProvider)),
);
final valuationProvider = Provider(
  (ref) => ValuationService(ref.watch(financeStoreProvider)),
);
final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());
final marketDataProvider = Provider((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  final store = ref.watch(financeStoreProvider);
  return MarketDataService(
    store,
    FrankfurterProvider(client),
    PublicQuoteProvider(
      client,
      store,
      () => ref.read(secureStorageProvider).read(key: 'alpha_vantage_key'),
    ),
  );
});
final financeRevisionProvider = StreamProvider(
  (ref) => ref.watch(databaseProvider).financeChanges.stream,
);
final holdingsProvider = FutureProvider<List<Holding>>((ref) {
  ref.watch(financeRevisionProvider);
  return PortfolioRepository(ref.watch(financeStoreProvider)).getAll();
});
final contractsProvider = FutureProvider<List<FinanceContract>>((ref) {
  ref.watch(financeRevisionProvider);
  return ContractRepository(ref.watch(financeStoreProvider)).getAll();
});
final wealthProvider = FutureProvider<WealthSummary>((ref) {
  ref.watch(financeRevisionProvider);
  return ref
      .watch(valuationProvider)
      .summary(ref.watch(defaultCurrencyProvider));
});

/// Recorded daily net-worth snapshots in the reporting currency, oldest
/// first. Only real observations: nothing is interpolated before tracking.
final netWorthHistoryProvider = FutureProvider<List<Json>>((ref) async {
  ref.watch(financeRevisionProvider);
  final currency = ref.watch(defaultCurrencyProvider);
  final rows = await ref.watch(financeStoreProvider).list('snapshots');
  return rows.where((j) => j['currency'] == currency).toList()
    ..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));
});
final accountDetailsProvider = FutureProvider<Map<int, AccountDetails>>((
  ref,
) async {
  ref.watch(financeRevisionProvider);
  final rows = await ref.watch(financeStoreProvider).list('accountDetails');
  return {
    for (final row in rows)
      row['accountId'] as int: AccountDetails.fromJson(row),
  };
});
