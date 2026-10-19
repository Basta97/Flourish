import '../../data/finance/finance_store.dart';
import '../../domain/finance/models.dart';

/// Amounts are exact decimal strings on disk, including legacy single amounts.
class TransactionTemplate {
  final String id, name, type;
  final int accountId, categoryId;
  final String? note;
  final List<Amount> amounts;
  TransactionTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.accountId,
    required this.categoryId,
    required List<Amount> amounts,
    this.note,
  }) : amounts = List.unmodifiable(amounts) {
    if (id.trim().isEmpty ||
        accountId <= 0 ||
        categoryId <= 0 ||
        name.trim().isEmpty ||
        !['expense', 'income'].contains(type) ||
        amounts.isEmpty ||
        amounts.length > 3 ||
        amounts.any((a) => a <= Amount.zero)) {
      throw const FormatException(
        'A template needs a name and 1–3 positive amounts',
      );
    }
  }
  factory TransactionTemplate.fromJson(Json j) => TransactionTemplate(
    id: j['id'] as String,
    name: j['name'] as String,
    type: j['type'] as String,
    accountId: int.parse('${j['account']}'),
    categoryId: int.parse('${j['category']}'),
    note: j['note'] as String?,
    amounts: [
      for (final a in (j['amounts'] as List? ?? [j['amount']])) Amount('$a'),
    ],
  );
  Json toJson() => {
    'id': id,
    'name': name.trim(),
    'type': type,
    'account': '$accountId',
    'category': '$categoryId',
    'note': note,
    'amounts': [for (final a in amounts) '$a'],
  };
}

class TemplateSelection {
  final TransactionTemplate template;
  final Amount amount;
  const TemplateSelection(this.template, this.amount);
}

class TransactionTemplateRepository {
  final FinanceStore store;
  const TransactionTemplateRepository(this.store);
  Future<List<TransactionTemplate>> list() async => [
    for (final j in await store.list('templates'))
      TransactionTemplate.fromJson(j),
  ];
  Future<void> save(TransactionTemplate template) =>
      store.put('templates', template.id, template.toJson());
  Future<void> delete(String id) => store.remove('templates', id);
}
