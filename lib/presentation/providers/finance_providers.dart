import '../../core/finance/currency_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/finance/financial_ledger_service.dart';
import '../../core/finance/contract_service.dart';
import '../../core/finance/recurring_service.dart';
import '../../core/finance/credit_card_service.dart';
import '../../core/detection/detection_bridge.dart';
import '../../core/detection/detection_service.dart';
import '../../core/models/shared_import_draft.dart';
import '../../data/database/database.dart';
import '../../core/finance/market_data_service.dart';
import '../../core/finance/valuation_service.dart';
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import 'ai_providers.dart';
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

final detectionServiceProvider = Provider(
  (ref) => DetectionService(
    ref.watch(financialLedgerProvider),
    assist: () => ref.read(aiAssistProvider.future),
    newCategories: ref.watch(aiSettingsProvider).allowNewCategories,
  ),
);
final detectionBridgeProvider = Provider<DetectionBridge>(
  (ref) => MethodChannelDetectionBridge(),
);

/// Messages captured on the device and not yet acknowledged, oldest first,
/// as drafts for a batch review. Reading does not remove them: acknowledge
/// with `detectionBridgeProvider.ack` using each draft's [id]. The detection
/// runtime moves the queue into the inbox on launch and resume, so this is
/// usually empty while the app runs; invalidate it to read again.
final pendingDetectedImportsProvider =
    FutureProvider.autoDispose<List<SharedImportDraft>>((ref) async {
      final queued = await ref.watch(detectionBridgeProvider).peek();
      return [
        for (final q in queued)
          SharedImportDraft(
            id: q.id,
            source: q.message.source,
            rawText: q.message.text,
            sender: q.message.sender,
            packageName: q.message.packageName,
            createdAt: q.message.receivedAt,
          ),
      ];
    });

/// Every detected payment, newest first.
final detectedPaymentsProvider = StreamProvider<List<DetectedPayment>>(
  (ref) => ref.watch(detectionServiceProvider).watch(),
);

/// What a detected payment costs in its account's currency (converted at
/// the day's exchange rate when the bank did not say).
final detectionChargeProvider = FutureProvider.autoDispose
    .family<ChargeEstimate?, DetectedPayment>((ref, row) {
      ref.watch(financeRevisionProvider);
      return ref.watch(detectionServiceProvider).charge(row);
    });
final pendingDetectionsProvider = StreamProvider<int>(
  (ref) => ref.watch(detectionServiceProvider).watchPendingCount(),
);

final currencyCatalogProvider = Provider((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return CurrencyCatalog(
    ref.watch(financeStoreProvider),
    FrankfurterProvider(client),
  );
});
