import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/finance/transaction_templates.dart';
import '../../l10n/l10n.dart';
import '../providers/finance_providers.dart';

Future<TemplateSelection?> pickTemplate(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final templates = await TransactionTemplateRepository(
      ref.read(financeStoreProvider),
    ).list();
    if (!context.mounted) return null;
    final template = await showDialog<TransactionTemplate>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.useTemplate),
        content: SizedBox(
          width: 440,
          child: templates.isEmpty
              ? Text(context.l10n.noTemplates)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in templates)
                      ListTile(
                        title: Text(t.name),
                        onTap: () => Navigator.pop(ctx, t),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
    if (template == null || !context.mounted) return null;
    return selectTemplateAmount(context, template);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    return null;
  }
}

Future<TemplateSelection?> selectTemplateAmount(
  BuildContext context,
  TransactionTemplate template,
) async {
  if (template.amounts.length == 1) {
    return TemplateSelection(template, template.amounts.single);
  }
  final amount = await showDialog<Amount>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(context.l10n.chooseTemplateAmount),
      children: [
        for (final a in template.amounts)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, a),
            child: Text('$a'),
          ),
      ],
    ),
  );
  return amount == null ? null : TemplateSelection(template, amount);
}
