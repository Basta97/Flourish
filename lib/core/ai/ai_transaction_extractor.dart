import 'dart:convert';

import '../../data/database/database.dart' show Category;
import '../../data/finance/finance_store.dart';
import '../../domain/finance/amount.dart';
import '../detection/local_parser.dart';
import '../detection/text_normalizer.dart';
import '../detection/transaction_candidate.dart';
import '../utils/icon_utils.dart';
import 'ai_client.dart';
import 'prompts.dart';
import 'redactor.dart';

/// Where validated AI answers are remembered so a message is never paid for
/// twice.
abstract interface class AiCache {
  Future<Map<String, dynamic>?> get(String key);
  Future<void> put(String key, Map<String, dynamic> value);
}

class FinanceStoreAiCache implements AiCache {
  FinanceStoreAiCache(this.store);
  final FinanceStore store;
  static const collection = 'aiCache';

  @override
  Future<Map<String, dynamic>?> get(String key) async =>
      (await store.get(collection, key))?['result'] as Map<String, dynamic>?;

  @override
  Future<void> put(String key, Map<String, dynamic> value) => store.put(
    collection,
    key,
    {'result': value, 'at': DateTime.now().toIso8601String()},
    notify: false,
  );
}

class MemoryAiCache implements AiCache {
  final _data = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> get(String key) async => _data[key];
  @override
  Future<void> put(String key, Map<String, dynamic> value) async =>
      _data[key] = value;
}

/// Monthly request/token counters shown in Settings.
class AiUsageTracker {
  AiUsageTracker(this.store);
  final FinanceStore store;
  static const collection = 'aiUsage';

  static String monthKey([DateTime? at]) {
    final d = at ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  Future<void> record(AiUsage usage) async {
    final key = monthKey();
    final prior = await store.get(collection, key) ?? const {};
    await store.put(collection, key, {
      'requests': (prior['requests'] as int? ?? 0) + 1,
      'promptTokens': (prior['promptTokens'] as int? ?? 0) + usage.promptTokens,
      'completionTokens':
          (prior['completionTokens'] as int? ?? 0) + usage.completionTokens,
    }, notify: false);
  }

  Future<Map<String, dynamic>> thisMonth() async =>
      await store.get(collection, monthKey()) ?? const {};
}

/// Second-stage detection: sends the messages the local parser is unsure
/// about to an LLM and merges back only answers that pass validation.
class AiTransactionExtractor {
  AiTransactionExtractor(
    this.client, {
    this.cache,
    this.usage,
    this.redact = true,
    this.allowNewCategories = true,
    this.batchSize = 15,
  });

  final AiClient client;
  final AiCache? cache;
  final AiUsageTracker? usage;
  final bool redact;
  final bool allowNewCategories;
  final int batchSize;

  /// Returns [items] with AI improvements applied, same length and order.
  /// Never throws for a bad AI answer; network/auth errors are rethrown so
  /// the UI can tell the user.
  Future<List<TransactionCandidate>> improve(
    List<TransactionCandidate> items,
    List<Category> categories, {
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final out = [...items];
    final pending = <int>[];
    for (var i = 0; i < items.length; i++) {
      final cached = await cache?.get(_cacheKey(items[i]));
      if (cached != null) {
        out[i] = merge(items[i], cached, categories, now: today) ?? items[i];
      } else {
        pending.add(i);
      }
    }

    for (var start = 0; start < pending.length; start += batchSize) {
      final chunk = pending.skip(start).take(batchSize).toList();
      final messages = [
        for (var k = 0; k < chunk.length; k++)
          {'i': k, 'text': _outgoingText(items[chunk[k]])},
      ];
      final reply = await client.completeJson(
        system: AiPrompts.extractionSystem(IconUtils.categoryIcons.keys),
        user: jsonEncode({
          'today': today.toIso8601String().substring(0, 10),
          'categories': [
            for (final c in categories)
              {'id': c.id, 'name': c.name, 'type': c.type},
          ],
          'messages': messages,
        }),
      );
      await usage?.record(reply.usage);
      final results = reply.json['results'];
      if (results is! List) continue;
      for (final r in results) {
        if (r is! Map<String, dynamic>) continue;
        final k = r['i'];
        if (k is! int || k < 0 || k >= chunk.length) continue;
        final index = chunk[k];
        final merged = merge(items[index], r, categories, now: today);
        if (merged != null) {
          out[index] = merged;
          await cache?.put(_cacheKey(items[index]), r);
        }
      }
    }
    return out;
  }

  String _cacheKey(TransactionCandidate c) =>
      '${AiPrompts.extractionVersion}:${c.fingerprint}';

  String _outgoingText(TransactionCandidate c) {
    if (!redact) return c.rawText;
    final keep = <String>{
      if (c.amount != null) c.amount!.value.toString().split('.').first,
    };
    return Redactor.redact(c.rawText, keepNumbers: keep);
  }

  /// Validates one AI result against the original message and merges it.
  /// Returns null when the answer must be discarded entirely.
  TransactionCandidate? merge(
    TransactionCandidate local,
    Map<String, dynamic> r,
    List<Category> categories, {
    required DateTime now,
  }) {
    final type = r['type'];
    if (type != 'income' && type != 'expense') return null;
    final kind = TransactionKind.tryParse(r['kind'] as String?);
    if (kind == null) return null;

    Amount? amount;
    final rawAmount = r['amount'];
    if (rawAmount != null) {
      amount = TextNormalizer.parseAmount('$rawAmount');
      if (amount == null || !amountAppearsIn(amount, local.rawText)) {
        amount = null; // Hallucinated or computed — never trust it.
      }
    }
    final isTransaction = r['is_transaction'] == true && kind.movesMoney;
    if (isTransaction && amount == null && local.amount == null) return null;

    final currency = r['currency'] is String &&
            RegExp(r'^[A-Z]{3}$').hasMatch(r['currency'] as String)
        ? r['currency'] as String
        : null;

    DateTime? date;
    if (r['date'] is String) {
      final d = DateTime.tryParse(r['date'] as String);
      if (d != null &&
          !d.isAfter(now.add(const Duration(days: 1))) &&
          now.difference(d).inDays < 366 * 5) {
        date = d;
      }
    }

    var merchant = r['merchant'] is String
        ? (r['merchant'] as String).trim()
        : '';
    if (merchant.length > 40) merchant = merchant.substring(0, 40).trim();

    int? existingId;
    ProposedCategory? proposed;
    final category = r['category'];
    if (category is Map) {
      final id = category['existing_id'];
      if (id is int &&
          categories.any((c) => c.id == id && c.type == type)) {
        existingId = id;
      }
      final fresh = category['new'];
      if (existingId == null && allowNewCategories && fresh is Map) {
        final name = (fresh['name'] as String? ?? '').trim();
        if (name.length >= 2 && name.length <= 30) {
          final icon = fresh['icon'] as String? ?? 'category';
          proposed = ProposedCategory(
            name: name,
            type: type as String,
            icon: IconUtils.categoryIcons.containsKey(icon) ? icon : 'category',
            colorIndex: name.codeUnits.fold<int>(0, (a, b) => a + b) % 12,
            parentName: fresh['parent'] as String?,
          );
        }
      }
    }

    final aiConfidence = (r['confidence'] as num?)?.toDouble().clamp(0.0, 1.0) ??
        0.7;
    // An AI answer that kept the local amount is stronger evidence than one
    // that found an amount on its own.
    final agrees = amount != null && amount == local.amount;
    final confidence = [
      local.confidence,
      (aiConfidence * (agrees ? 0.95 : 0.85)),
    ].reduce((a, b) => a > b ? a : b).clamp(0.0, 0.95);

    final effectiveKind = isTransaction
        ? kind
        : (kind.movesMoney ? TransactionKind.unknown : kind);
    final finalMerchant = merchant.isNotEmpty ? merchant : local.merchant;
    return local.copyWith(
      amount: amount ?? local.amount,
      currency: currency ?? local.currency,
      date: date ?? local.date,
      type: type as String,
      kind: effectiveKind,
      merchant: finalMerchant,
      merchantKey: LocalTransactionParser.normalizeMerchant(finalMerchant),
      aiCategoryId: existingId,
      aiProposedCategory: proposed,
      confidence: double.parse(confidence.toStringAsFixed(3)),
      source: CandidateSource.ai,
    );
  }

  /// True when [amount] is one of the numbers written in [text], in any
  /// common grouping ("1,250.50", "1250.5", "1.5k").
  static bool amountAppearsIn(Amount amount, String text) {
    final normalized = TextNormalizer.normalize(text);
    for (final m in RegExp(r'\d[\d.,\s]*\d|\d').allMatches(normalized)) {
      final raw = m.group(0)!;
      final tail = normalized.substring(m.end);
      final k = RegExp(r'^\s?[kK](?![A-Za-z])').hasMatch(tail);
      // Try the whole run and each space-separated piece of it.
      for (final piece in {raw, ...raw.split(' ')}) {
        for (final currency in const [null, 'KWD', 'EUR']) {
          final canonical = TextNormalizer.canonicalNumber(
            piece.trim(),
            currency: currency,
          );
          if (canonical == null) continue;
          var value = Amount(canonical);
          if (k) value = value * Amount('1000');
          if (value == amount) return true;
        }
      }
    }
    return false;
  }
}
