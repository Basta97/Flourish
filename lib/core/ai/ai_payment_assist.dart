import 'dart:convert';

import '../../data/database/database.dart' show Category;
import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';
import '../detection/category_resolver.dart';
import '../detection/normalizer.dart';
import '../detection/parsed_payment.dart';
import '../detection/redact.dart';
import '../finance/system_categories.dart';
import '../utils/amount_parser.dart';
import '../utils/fingerprint.dart';
import '../utils/icon_utils.dart';
import 'ai_client.dart';
import 'prompts.dart';
import 'redactor.dart';

/// Where validated AI answers are remembered, so a message is never paid
/// for twice.
abstract interface class AiCache {
  Future<Json?> get(String key);
  Future<void> put(String key, Json value);
}

class FinanceStoreAiCache implements AiCache {
  FinanceStoreAiCache(this.store);
  final FinanceStore store;
  static const collection = 'aiCache';

  @override
  Future<Json?> get(String key) async =>
      (await store.get(collection, key))?['result'] as Json?;

  @override
  Future<void> put(String key, Json value) => store.put(collection, key, {
    'result': value,
    'at': DateTime.now().toIso8601String(),
  }, notify: false);
}

class MemoryAiCache implements AiCache {
  final _data = <String, Json>{};
  @override
  Future<Json?> get(String key) async => _data[key];
  @override
  Future<void> put(String key, Json value) async => _data[key] = value;
}

/// Monthly request and token counters, shown in Settings.
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

  Future<Json> thisMonth() async =>
      await store.get(collection, monthKey()) ?? const {};
}

/// One message for the AI: its cleaned text and what the local parser read.
class AiPaymentRequest {
  const AiPaymentRequest(this.text, this.local);
  final String text;
  final ParsedPayment local;
}

/// The AI's validated reading, merged over the local one.
class AiPaymentResult {
  const AiPaymentResult(this.payment, {this.categoryId, this.proposed});
  final ParsedPayment payment;
  final int? categoryId;
  final ProposedCategory? proposed;
}

/// Second stage of detection: sends messages the local parser is unsure
/// about to an OpenAI-compatible model and keeps only answers that pass
/// validation against the original text.
class AiPaymentAssist {
  AiPaymentAssist(
    this.client, {
    this.cache,
    this.usage,
    this.redactText = true,
    this.allowNewCategories = true,
    this.threshold = 0.75,
    this.batchSize = 15,
  });

  final AiClient client;
  final AiCache? cache;
  final AiUsageTracker? usage;
  final bool redactText;
  final bool allowNewCategories;

  /// Local readings below this confidence are worth an AI request.
  final double threshold;
  final int batchSize;

  static const _kinds = {
    'purchase',
    'withdrawal',
    'transfer_out',
    'transfer_in',
    'deposit',
    'refund',
    'bill_payment',
    'card_payment',
    'fee',
  };
  static const _ignores = {'otp', 'declined', 'promo', 'notice'};

  /// Whether [local] should be sent to the AI at all.
  bool wants(ParsedPayment local, String text) {
    if (local.aiAssisted) return false;
    if (local.ignored) {
      // Codes, declines and promos are recognised reliably on the device;
      // only "no amount" may hide a payment the parser could not read.
      return local.ignoreReason == 'no_amount' &&
          RegExp(r'\d').hasMatch(text) &&
          text.length >= 12;
    }
    return local.confidence < threshold || local.kind == null;
  }

  /// Returns one result per request (null where the AI added nothing
  /// usable). Network and key errors are rethrown for the caller to show.
  /// [forceRedact] masks personal data whatever [redactText] says; requests
  /// nobody tapped for always use it.
  Future<List<AiPaymentResult?>> improve(
    List<AiPaymentRequest> requests,
    List<Category> categories, {
    DateTime? now,
    bool forceRedact = false,
  }) async {
    final today = now ?? DateTime.now();
    final pickable = SystemCategories.pickable(categories);
    final out = List<AiPaymentResult?>.filled(requests.length, null);
    final pending = <int>[];
    for (var i = 0; i < requests.length; i++) {
      final cached = await cache?.get(await _key(requests[i].text));
      if (cached != null) {
        out[i] = merge(requests[i], cached, pickable, now: today);
      } else {
        pending.add(i);
      }
    }
    for (var start = 0; start < pending.length; start += batchSize) {
      final chunk = pending.skip(start).take(batchSize).toList();
      final reply = await client.completeJson(
        system: AiPrompts.paymentSystem(IconUtils.categoryIcons.keys),
        user: jsonEncode({
          'today': today.toIso8601String().substring(0, 10),
          'categories': [
            for (final c in pickable)
              {'id': c.id, 'name': c.name, 'type': c.type},
          ],
          'messages': [
            for (var k = 0; k < chunk.length; k++)
              {
                'i': k,
                'text': outgoing(requests[chunk[k]], force: forceRedact),
              },
          ],
        }),
      );
      await usage?.record(reply.usage);
      final results = reply.json['results'];
      if (results is! List) continue;
      for (final r in results) {
        if (r is! Json || r['i'] is! int) continue;
        final k = r['i'] as int;
        if (k < 0 || k >= chunk.length) continue;
        final merged = merge(requests[chunk[k]], r, pickable, now: today);
        if (merged != null) {
          out[chunk[k]] = merged;
          await cache?.put(await _key(requests[chunk[k]].text), r);
        }
      }
    }
    return out;
  }

  Future<String> _key(String text) async =>
      '${AiPrompts.paymentVersion}:${await fingerprint(MessageNormalizer.fold(text))}';

  /// The text that leaves the device: the stored redaction plus emails,
  /// IBANs, phones and long account numbers masked (the amount is kept).
  String outgoing(AiPaymentRequest r, {bool force = false}) {
    final base = redact(r.text);
    if (!redactText && !force) return base;
    final amount = r.local.amount?.value.toString().split('.').first;
    return Redactor.redact(base, keepNumbers: {?amount});
  }

  /// Validates one AI answer and merges it over the local reading. Returns
  /// null when the answer must be discarded.
  AiPaymentResult? merge(
    AiPaymentRequest request,
    Json r,
    List<Category> categories, {
    required DateTime now,
  }) {
    final local = request.local;
    final ignore = r['ignore'];
    if (ignore is String && _ignores.contains(ignore)) {
      return AiPaymentResult(
        local.copyWith(ignoreReason: ignore, aiAssisted: true),
      );
    }
    final direction = r['direction'];
    if (direction != 'income' && direction != 'expense') return null;
    final kind = r['kind'] is String && _kinds.contains(r['kind'])
        ? r['kind'] as String
        : null;
    final currency =
        r['currency'] is String &&
            RegExp(r'^[A-Z]{3}$').hasMatch(r['currency'] as String)
        ? r['currency'] as String
        : null;

    Amount? amount;
    if (r['amount'] != null) {
      final parsed = AmountParser.parse(
        '${r['amount']}',
        currency: currency ?? local.currency ?? 'EGP',
        lenient: true,
      );
      if (parsed.isValid && amountAppearsIn(parsed.value!, request.text)) {
        amount = parsed.value;
      }
    }
    amount ??= local.amount;
    if (amount == null) return null; // Hallucinated or computed amounts.

    DateTime? date;
    if (r['date'] is String) {
      final d = DateTime.tryParse(r['date'] as String);
      if (d != null &&
          !d.isAfter(now.add(const Duration(days: 1))) &&
          now.difference(d).inDays < 366 * 5) {
        final at = local.occurredAt ?? now;
        date = DateTime(d.year, d.month, d.day, at.hour, at.minute);
      }
    }

    String? name(String key) {
      final v = r[key];
      if (v is! String) return null;
      final t = v.trim();
      if (t.length < 2) return null;
      return t.length > 40 ? t.substring(0, 40).trim() : t;
    }

    int? categoryId;
    ProposedCategory? proposed;
    final category = r['category'];
    if (category is Map) {
      final type = kind == 'refund' ? 'expense' : direction as String;
      final id = category['existing_id'];
      if (id is int && categories.any((c) => c.id == id && c.type == type)) {
        categoryId = id;
      }
      final fresh = category['new'];
      if (categoryId == null && allowNewCategories && fresh is Map) {
        final n = (fresh['name'] as String? ?? '').trim();
        if (n.length >= 2 && n.length <= 30) {
          proposed = CategoryResolver.sanitize(
            ProposedCategory(
              name: n,
              type: type,
              icon: fresh['icon'] as String? ?? 'category',
              colorIndex: n.codeUnits.fold<int>(0, (a, b) => a + b) % 12,
              parentName: fresh['parent'] as String?,
            ),
          );
        }
      }
    }

    final aiConfidence =
        (r['confidence'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.7;
    final agrees = local.amount != null && amount == local.amount;
    final merged = (aiConfidence * (agrees ? 0.95 : 0.85));
    final confidence = merged > local.confidence ? merged : local.confidence;

    return AiPaymentResult(
      local.copyWith(
        kind: kind ?? local.kind,
        direction: direction as String,
        amount: amount,
        currency: currency ?? local.currency,
        merchant: name('merchant') ?? local.merchant,
        counterparty: name('counterparty') == null
            ? local.counterparty
            : redact(name('counterparty')!),
        occurredAt: date ?? local.occurredAt,
        confidence: double.parse(
          confidence.clamp(0.0, 0.95).toStringAsFixed(3),
        ),
        clearIgnore: true,
        aiAssisted: true,
        proposedCategory: proposed?.toJson(),
      ),
      categoryId: categoryId,
      proposed: proposed,
    );
  }

  /// True when [amount] is one of the numbers written in [text], in any
  /// usual grouping ("1,250.50", "1250.5", "12 000", "1.5k").
  static bool amountAppearsIn(Amount amount, String text) {
    final cleaned = MessageNormalizer.clean(text);
    for (final m in RegExp(r'\d[\d.,\s]*\d|\d').allMatches(cleaned)) {
      final raw = m.group(0)!;
      final k = RegExp(
        r'^\s?[kK](?![A-Za-z])',
      ).hasMatch(cleaned.substring(m.end));
      for (final piece in {raw.trim(), ...raw.split(' ')}) {
        for (final currency in const ['EGP', 'KWD', 'EUR']) {
          final parsed = AmountParser.parse(
            piece.trim(),
            currency: currency,
            lenient: true,
          );
          if (!parsed.isValid) continue;
          var value = parsed.value!;
          if (k) value = value * Amount('1000');
          if (value == amount) return true;
        }
      }
    }
    return false;
  }
}
