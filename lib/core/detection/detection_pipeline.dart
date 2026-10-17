import 'package:drift/drift.dart' show Variable;

import '../../data/database/database.dart';
import '../../data/finance/finance_store.dart';
import '../ai/ai_config.dart';
import '../ai/ai_transaction_extractor.dart';
import 'bank_profiles.dart';
import 'category_resolver.dart';
import 'category_store.dart';
import 'local_parser.dart';
import 'message_splitter.dart';
import 'transaction_candidate.dart';

/// Why a candidate may already be in the ledger.
enum DuplicateKind { sameMessage, similarTransaction }

class DuplicateMatch {
  const DuplicateMatch(this.kind, {this.transactionId});
  final DuplicateKind kind;
  final int? transactionId;
}

/// A candidate with everything the review screen needs pre-filled.
class DetectedItem {
  DetectedItem({
    required this.candidate,
    required this.category,
    this.accountId,
    this.duplicate,
  });

  TransactionCandidate candidate;
  CategoryResolution category;
  int? accountId;
  DuplicateMatch? duplicate;

  /// Skip non-transactions and exact re-imports unless the user opts in.
  bool get selectedByDefault =>
      candidate.isTransaction && duplicate?.kind != DuplicateKind.sameMessage;
}

class DetectionResult {
  const DetectionResult(this.items, {this.aiError, this.aiUsed = false});
  final List<DetectedItem> items;

  /// Set when the AI stage was attempted and failed; local results are kept.
  final String? aiError;
  final bool aiUsed;
}

/// Picks the account a detected transaction belongs to.
class AccountResolver {
  AccountResolver(this.accounts, {this.cards = const {}, this.details = const {}, this.lastUsed});

  final List<Account> accounts;

  /// Card last-4 → account id, learned from earlier saves.
  final Map<String, int> cards;

  /// Account id → institution name from account details.
  final Map<int, String> details;
  final int? lastUsed;

  int? resolve(TransactionCandidate c) {
    if (accounts.isEmpty) return null;
    bool exists(int? id) => id != null && accounts.any((a) => a.id == id);

    final byCard = c.cardLast4 == null ? null : cards[c.cardLast4];
    if (exists(byCard)) return byCard;

    final bank = BankProfiles.all.where((b) => b.id == c.bankHint).firstOrNull;
    if (bank != null) {
      final matches = accounts.where((a) {
        final label = '${a.name} ${details[a.id] ?? ''}'.toLowerCase();
        return bank.markers.any(label.contains) ||
            label.contains(bank.name.toLowerCase());
      }).toList();
      final sameCurrency = matches.where((a) => a.currency == c.currency);
      if (sameCurrency.isNotEmpty) return sameCurrency.first.id;
      if (matches.isNotEmpty) return matches.first.id;
    }

    if (c.currency != null) {
      final sameCurrency = accounts.where((a) => a.currency == c.currency).toList();
      if (sameCurrency.length == 1) return sameCurrency.single.id;
      if (sameCurrency.any((a) => a.id == lastUsed)) return lastUsed;
      if (sameCurrency.isNotEmpty) return sameCurrency.first.id;
    }
    return exists(lastUsed) ? lastUsed : accounts.first.id;
  }
}

/// Orchestrates local parsing → optional AI → category → account → duplicates.
class DetectionPipeline {
  DetectionPipeline({
    required this.db,
    required this.store,
    required this.settings,
    this.extractor,
    this.lastUsedAccount,
  }) : learning = CategoryLearningStore(db, store);

  final AppDatabase db;
  final FinanceStore store;
  final AiSettings settings;

  /// Null when AI is off or has no key.
  final AiTransactionExtractor? extractor;
  final int? lastUsedAccount;
  final CategoryLearningStore learning;

  static const cardCollection = 'cardAccounts';
  static const importsCollection = 'imports';

  static String messageImportKey(String fingerprint) => 'msg:$fingerprint';

  /// Detects every message in [text] (several pasted alerts are split).
  Future<DetectionResult> detectText(
    String text, {
    bool forceAi = false,
    DateTime? now,
  }) => detectMessages(MessageSplitter.split(text), forceAi: forceAi, now: now);

  Future<DetectionResult> detectMessages(
    List<String> messages, {
    bool forceAi = false,
    DateTime? now,
  }) async {
    var candidates = [
      for (final m in messages) LocalTransactionParser.parse(m, now: now),
    ];
    return enrich(candidates, forceAi: forceAi, now: now);
  }

  /// Runs the AI, category, account and duplicate stages on [candidates]
  /// (also used for rows that came from files).
  Future<DetectionResult> enrich(
    List<TransactionCandidate> candidates, {
    bool forceAi = false,
    DateTime? now,
  }) async {
    final categories = await db.getAllCategories();
    String? aiError;
    var aiUsed = false;

    final ai = extractor;
    if (ai != null) {
      final unsure = [
        for (var i = 0; i < candidates.length; i++)
          if (forceAi || _needsAi(candidates[i])) i,
      ];
      if (unsure.isNotEmpty) {
        try {
          final improved = await ai.improve(
            [for (final i in unsure) candidates[i]],
            categories,
            now: now,
          );
          candidates = [...candidates];
          for (var k = 0; k < unsure.length; k++) {
            candidates[unsure[k]] = improved[k];
          }
          aiUsed = true;
        } on Exception catch (e) {
          aiError = '$e';
        }
      }
    }

    final resolver = await learning.resolver(
      allowNewCategories: settings.allowNewCategories,
    );
    final resolutions = resolver.resolveAll(candidates);
    final accounts = await db.getAllAccounts();
    final accountResolver = AccountResolver(
      accounts,
      cards: {
        for (final row in await store.list(cardCollection))
          row['last4'] as String: row['accountId'] as int,
      },
      details: {
        for (final row in await store.list('accountDetails'))
          row['accountId'] as int: '${row['institution'] ?? ''}',
      },
      lastUsed: lastUsedAccount,
    );

    final items = <DetectedItem>[];
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      final accountId = accountResolver.resolve(c);
      items.add(
        DetectedItem(
          candidate: c,
          category: resolutions[i],
          accountId: accountId,
          duplicate: await findDuplicate(c, accountId),
        ),
      );
    }
    return DetectionResult(items, aiError: aiError, aiUsed: aiUsed);
  }

  bool _needsAi(TransactionCandidate c) {
    if (c.confidence < settings.threshold) return true;
    // Confident about the money but not about where it went.
    return c.isTransaction && c.categoryHint == null && c.merchantKey.isEmpty;
  }

  Future<DuplicateMatch?> findDuplicate(
    TransactionCandidate c,
    int? accountId,
  ) async {
    if (await store.get(importsCollection, messageImportKey(c.fingerprint)) !=
        null) {
      return const DuplicateMatch(DuplicateKind.sameMessage);
    }
    final amount = c.amount;
    if (amount == null || accountId == null) return null;
    final at = c.date ?? DateTime.now();
    final rows = await db
        .customSelect(
          'SELECT id FROM transactions WHERE account_id = ? AND type = ? '
          'AND ABS(amount - ?) < 0.005 AND transaction_date BETWEEN ? AND ? LIMIT 1',
          variables: [
            Variable(accountId),
            Variable(c.type),
            Variable(amount.toDouble()),
            Variable(at.subtract(const Duration(days: 2))),
            Variable(at.add(const Duration(days: 2))),
          ],
        )
        .get();
    if (rows.isEmpty) return null;
    return DuplicateMatch(
      DuplicateKind.similarTransaction,
      transactionId: rows.first.read<int>('id'),
    );
  }

  /// Called after the user saved [c] as a transaction: remembers the message,
  /// the merchant's category and which account the card belongs to.
  Future<void> learnFromSave(
    TransactionCandidate c, {
    required int accountId,
    required int categoryId,
    required String type,
  }) async {
    await store.put(importsCollection, messageImportKey(c.fingerprint), {
      'date': DateTime.now().toIso8601String(),
    }, notify: false);
    await learning.learn(
      merchantKey: c.merchantKey,
      type: type,
      categoryId: categoryId,
    );
    final card = c.cardLast4;
    if (card != null) {
      await store.put(cardCollection, card, {
        'last4': card,
        'accountId': accountId,
      }, notify: false);
    }
  }
}
