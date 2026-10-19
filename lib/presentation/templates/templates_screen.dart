import '../../shared/category_label.dart';
import '../providers/database_provider.dart';
import '../../core/finance/system_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/finance/transaction_templates.dart';
import '../../core/utils/amount_parser.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/spring_bottom_sheet.dart';
import '../providers/finance_providers.dart';
import '../transactions/widgets/add_transaction_sheet.dart';
import '../wealth/finance_form.dart';
import 'template_picker.dart';

final templatesProvider = FutureProvider<List<TransactionTemplate>>((ref) {
  ref.watch(financeRevisionProvider);
  return TransactionTemplateRepository(ref.watch(financeStoreProvider)).list();
});

class TemplatesScreen extends ConsumerWidget {
  final String? recordId;
  const TemplatesScreen({super.key, this.recordId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.transactionTemplates)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.newTemplate),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (allTemplates) {
          final templates = allTemplates
              .where((t) => recordId == null || t.id == recordId)
              .toList();
          return templates.isEmpty
              ? Center(child: Text(context.l10n.noTemplates))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    for (final t in templates)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(t.amounts.join(' · ')),
                              Wrap(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.play_arrow),
                                    label: Text(context.l10n.useTemplate),
                                    onPressed: () async {
                                      final selection =
                                          await selectTemplateAmount(
                                            context,
                                            t,
                                          );
                                      if (selection != null &&
                                          context.mounted) {
                                        await showSpringBottomSheet(
                                          context: context,
                                          builder: (_) => AddTransactionSheet(
                                            templateSelection: selection,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: context.l10n.edit,
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _edit(context, ref, t),
                                  ),
                                  IconButton(
                                    tooltip: context.l10n.delete,
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await TransactionTemplateRepository(
                                        ref.read(financeStoreProvider),
                                      ).delete(t.id);
                                      ref.invalidate(templatesProvider);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    TransactionTemplate? t,
  ]) async {
    final db = ref.read(databaseProvider);
    final accounts = await db.getAllAccounts();
    final categories = SystemCategories.pickable(await db.getAllCategories());
    final store = ref.read(financeStoreProvider);
    final archived = <int>{};
    for (final a in accounts) {
      if ((await store.get('accountDetails', '${a.id}'))?['archived'] == true) {
        archived.add(a.id);
      }
    }
    if (!context.mounted) return;
    final l = context.l10n;
    await financeForm(
      context,
      title: t == null ? l.newTemplate : l.edit,
      fields: [
        FinanceField('name', l.templateName, initial: t?.name ?? ''),
        FinanceField(
          'type',
          l.type,
          initial: t?.type ?? 'expense',
          options: {'expense': l.expense, 'income': l.income},
        ),
        FinanceField(
          'account',
          l.account,
          initial: '${t?.accountId ?? ''}',
          options: {
            for (final a in accounts.where((a) => !archived.contains(a.id)))
              '${a.id}': '${a.name} (${a.currency})',
          },
        ),
        FinanceField(
          'category',
          l.category,
          initial: '${t?.categoryId ?? ''}',
          options: {
            for (final c in categories)
              '${c.id}': '${c.displayName} (${c.type})',
          },
        ),
        for (var i = 0; i < 3; i++)
          FinanceField(
            'amount$i',
            '${l.amountInAccountCurrency} ${i + 1}',
            numeric: true,
            required: i == 0,
            initial: t != null && t.amounts.length > i ? '${t.amounts[i]}' : '',
          ),
        FinanceField('note', l.note, initial: t?.note ?? '', required: false),
      ],
      save: (data) async {
        final account = accounts.firstWhere(
          (a) => '${a.id}' == data['account'],
        );
        final category = categories.firstWhere(
          (c) => '${c.id}' == data['category'],
        );
        if (category.type != data['type']) {
          throw FormatException(l.templateCategoryMismatch);
        }
        final amounts = <Amount>[];
        for (var i = 0; i < 3; i++) {
          final value = data['amount$i']!;
          if (value.isEmpty) continue;
          final parsed = AmountParser.parse(value, currency: account.currency);
          if (!parsed.isValid || parsed.value! <= Amount.zero) {
            throw FormatException(l.templatePositiveAmounts);
          }
          amounts.add(parsed.value!);
        }
        await TransactionTemplateRepository(store).save(
          TransactionTemplate(
            id: t?.id ?? ref.read(financialLedgerProvider).newId(),
            name: data['name']!,
            type: data['type']!,
            accountId: account.id,
            categoryId: category.id,
            amounts: amounts,
            note: data['note'],
          ),
        );
      },
    );
    ref.invalidate(templatesProvider);
  }
}
