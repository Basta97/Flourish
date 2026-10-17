import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/ai/ai_client.dart';
import '../../core/ai/ai_config.dart';
import '../../core/ai/ai_payment_assist.dart';
import 'finance_providers.dart';

final aiSettingsProvider = StateProvider<AiSettings>((ref) => AiSettings.load());

final aiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final aiApiKeyProvider = FutureProvider<String?>((ref) async {
  ref.watch(aiSettingsProvider);
  final key = await ref
      .watch(secureStorageProvider)
      .read(key: AiSettings.apiKeyStorageKey);
  return key == null || key.trim().isEmpty ? null : key.trim();
});

/// A client for the configured provider, or null when AI is not set up.
final aiClientProvider = FutureProvider<AiClient?>((ref) async {
  final settings = ref.watch(aiSettingsProvider);
  final key = await ref.watch(aiApiKeyProvider.future);
  if (!settings.configured || key == null) return null;
  return AiClient(
    httpClient: ref.watch(aiHttpClientProvider),
    baseUrl: settings.baseUrl,
    apiKey: key,
    model: settings.model,
    jsonMode: settings.preset.supportsJsonMode,
  );
});

final aiUsageTrackerProvider = Provider(
  (ref) => AiUsageTracker(ref.watch(financeStoreProvider)),
);

/// The AI stage of payment detection, or null when switched off.
final aiAssistProvider = FutureProvider<AiPaymentAssist?>((ref) async {
  final settings = ref.watch(aiSettingsProvider);
  if (!settings.enabled) return null;
  final client = await ref.watch(aiClientProvider.future);
  if (client == null) return null;
  return AiPaymentAssist(
    client,
    cache: FinanceStoreAiCache(ref.watch(financeStoreProvider)),
    usage: ref.watch(aiUsageTrackerProvider),
    redactText: settings.effectiveRedact,
    allowNewCategories: settings.allowNewCategories,
    threshold: settings.threshold,
  );
});
