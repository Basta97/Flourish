import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/search/search_models.dart';
import '../../core/utils/amount_parser.dart';
import '../../l10n/l10n.dart';
import '../providers/database_provider.dart';
import '../providers/theme_providers.dart';
import '../currencies/currency_picker.dart';

Future<SearchFilters?> showSearchFilters(
  BuildContext context,
  WidgetRef ref,
  SearchFilters initial,
) async {
  final accounts = await ref.read(databaseProvider).getAllAccounts();
  if (!context.mounted) return null;
  int? account = initial.accountId;
  String? type = initial.transactionType;
  String currency = initial.currency ?? ref.read(defaultCurrencyProvider);
  DateTime? from = initial.from, to = initial.to;
  final minimum = TextEditingController(
        text: initial.minimum?.toString() ?? '',
      ),
      maximum = TextEditingController(text: initial.maximum?.toString() ?? '');
  String? error;
  try {
    return await showDialog<SearchFilters>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.searchFilters),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.searchAmountCurrency),
                  DropdownButtonFormField<int>(
                    initialValue: account,
                    decoration: InputDecoration(
                      labelText: context.l10n.navAccounts,
                    ),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(context.l10n.all),
                      ),
                      for (final a in accounts)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setState(() {
                      account = v;
                      currency =
                          accounts
                              .where((a) => a.id == v)
                              .firstOrNull
                              ?.currency ??
                          currency;
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: InputDecoration(labelText: context.l10n.type),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(context.l10n.all),
                      ),
                      for (final e in {
                        'income': context.l10n.income,
                        'expense': context.l10n.expense,
                        'transfer': context.l10n.transfer,
                      }.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => type = v),
                  ),
                  CurrencyField(
                    value: currency,
                    label: context.l10n.currency,
                    onChanged: (v) => setState(() => currency = v),
                  ),
                  TextField(
                    controller: minimum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.minimumAmount,
                    ),
                  ),
                  TextField(
                    controller: maximum,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.maximumAmount,
                    ),
                  ),
                  for (final start in [true, false])
                    ListTile(
                      title: Text(start ? context.l10n.from : context.l10n.to),
                      subtitle: Text(
                        (start ? from : to)?.toIso8601String().substring(
                              0,
                              10,
                            ) ??
                            '—',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          if (start) {
                            from = null;
                          } else {
                            to = null;
                          }
                        }),
                      ),
                      onTap: () async {
                        final value = await showDatePicker(
                          context: context,
                          initialDate: (start ? from : to) ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2200),
                        );
                        if (value != null) {
                          setState(() {
                            if (start) {
                              from = value;
                            } else {
                              to = value;
                            }
                          });
                        }
                      },
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, const SearchFilters()),
              child: Text(context.l10n.clearFilters),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final min = minimum.text.trim().isEmpty
                        ? null
                        : AmountParser.parse(
                            minimum.text,
                            currency: currency,
                            allowZero: true,
                          ),
                    max = maximum.text.trim().isEmpty
                        ? null
                        : AmountParser.parse(
                            maximum.text,
                            currency: currency,
                            allowZero: true,
                          );
                if (min?.error != null || max?.error != null) {
                  setState(() => error = min?.error ?? max?.error);
                  return;
                }
                if ((min?.value != null &&
                        max?.value != null &&
                        min!.value! > max!.value!) ||
                    (from != null && to != null && from!.isAfter(to!))) {
                  setState(() => error = context.l10n.searchFailed);
                  return;
                }
                Navigator.pop(
                  dialog,
                  SearchFilters(
                    kind: 'transaction',
                    accountId: account,
                    transactionType: type,
                    currency: currency,
                    from: from,
                    to: to,
                    minimum: min?.value,
                    maximum: max?.value,
                    newest: initial.newest,
                  ),
                );
              },
              child: Text(context.l10n.searchApply),
            ),
          ],
        ),
      ),
    );
  } finally {
    minimum.dispose();
    maximum.dispose();
  }
}
