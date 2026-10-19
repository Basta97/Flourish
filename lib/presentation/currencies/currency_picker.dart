import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/finance/currency_catalog.dart';
import '../../core/search/search_models.dart';
import '../../l10n/l10n.dart';
import '../providers/finance_providers.dart';

class CurrencyField extends StatelessWidget {
  final String value, label;
  final ValueChanged<String>? onChanged;
  final Set<String> excluded;
  const CurrencyField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.excluded = const {},
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onChanged == null
        ? null
        : () async {
            final selected = await pickCurrency(
              context,
              selected: value,
              excluded: excluded,
            );
            if (selected != null) onChanged?.call(selected);
          },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.search),
      ),
      child: Text(value.isEmpty ? '—' : value),
    ),
  );
}

Future<String?> pickCurrency(
  BuildContext context, {
  String? selected,
  Set<String> excluded = const {},
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  builder: (_) => _Picker(selected: selected, excluded: excluded),
);

class _Picker extends ConsumerStatefulWidget {
  final String? selected;
  final Set<String> excluded;
  const _Picker({this.selected, required this.excluded});
  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  List<CurrencyInfo> rows = CurrencyCatalog.bundled;
  String query = '';
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final data = await ref.read(currencyCatalogProvider).load();
    if (mounted) setState(() => rows = data);
  }

  @override
  Widget build(BuildContext context) {
    final all =
        {
              for (final r in rows) r.code: r,
              if (widget.selected != null &&
                  !rows.any((r) => r.code == widget.selected))
                widget.selected!: CurrencyInfo(
                  widget.selected!,
                  widget.selected!,
                ),
            }.values
            .where(
              (r) =>
                  !widget.excluded.contains(r.code) &&
                  SearchText.normalize(
                    '${r.code} ${r.name} ${r.symbol}',
                  ).contains(SearchText.normalize(query)),
            )
            .toList();
    all.sort((a, b) {
      final ai = CurrencyCatalog.prominent.indexOf(a.code),
          bi = CurrencyCatalog.prominent.indexOf(b.code);
      return (ai < 0 ? 100 : ai).compareTo(bi < 0 ? 100 : bi) != 0
          ? (ai < 0 ? 100 : ai).compareTo(bi < 0 ? 100 : bi)
          : a.code.compareTo(b.code);
    });
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.searchCurrency,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final r = all[i];
                  return ListTile(
                    title: Text(r.code),
                    subtitle: Text(r.name),
                    trailing: r.code == widget.selected
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, r.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
