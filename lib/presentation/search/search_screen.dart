import '../providers/locale_providers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/search/search_models.dart';
import '../../domain/finance/amount.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/search/search_repository.dart';
import '../../l10n/l10n.dart';
import '../providers/database_provider.dart';
import '../providers/theme_providers.dart';
import 'search_filters.dart';
import 'search_navigation.dart';

final searchRepositoryProvider = Provider(
  (ref) => SearchRepository(ref.watch(databaseProvider)),
);

class SearchScreen extends ConsumerStatefulWidget {
  final ValueChanged<Duration>? onResultsVisible;
  const SearchScreen({super.key, this.onResultsVisible});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  SearchFilters filters = const SearchFilters();
  SearchPage? page;
  List<SearchHit> hits = [];
  bool loading = false, indexing = true;
  String? error;
  int generation = 0;
  Timer? timer;
  Stopwatch? _latency;
  @override
  void initState() {
    super.initState();
    unawaited(prepare());
  }

  Future<void> prepare() async {
    try {
      await ref.read(searchRepositoryProvider).prepare();
      if (mounted) {
        setState(() => indexing = false);
        schedule();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          indexing = false;
          error = context.l10n.searchFailed;
        });
      }
    }
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void schedule() {
    _latency = widget.onResultsVisible == null ? null : (Stopwatch()..start());
    timer?.cancel();
    generation++;
    if (_controller.text.trim().isEmpty) {
      setState(() {
        hits = [];
        page = null;
        loading = false;
        error = null;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    timer = Timer(const Duration(milliseconds: 150), () => search());
  }

  Future<void> search({bool more = false}) async {
    if (indexing) return;
    final request = ++generation;
    setState(() => loading = true);
    try {
      final result = await ref
          .read(searchRepositoryProvider)
          .search(
            SearchQuery(_controller.text, filters: filters),
            after: more ? page?.next : null,
          );
      if (!mounted || request != generation) return;
      setState(() {
        hits = more ? [...hits, ...result.hits] : result.hits;
        page = result;
        loading = false;
        error = null;
      });
      final latency = _latency;
      _latency = null;
      if (latency != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && request == generation) {
            latency.stop();
            widget.onResultsVisible?.call(latency.elapsed);
          }
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          error = context.l10n.searchFailed;
        });
      }
    }
  }

  Map<String, String> labels(BuildContext context) => {
    'transaction': context.l10n.transactions,
    'account': context.l10n.navAccounts,
    'category': context.l10n.manageCategories,
    'template': context.l10n.transactionTemplates,
    'goal': context.l10n.savingsGoals,
    'budget': context.l10n.budgets,
    'holding': context.l10n.holdings,
    'obligation': context.l10n.searchObligations,
    'feature': context.l10n.searchFeatures,
  };
  @override
  Widget build(BuildContext context) {
    final names = labels(context), hidden = ref.watch(hideAmountsProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.searchEverythingHint,
            border: InputBorder.none,
          ),
          onChanged: (_) => schedule(),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: context.l10n.searchClear,
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                schedule();
              },
            ),
          IconButton(
            tooltip: context.l10n.searchFilters,
            icon: const Icon(Icons.tune),
            onPressed: () async {
              final selected = await showSearchFilters(context, ref, filters);
              if (selected != null && mounted) {
                setState(() => filters = selected);
                schedule();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(context.l10n.all),
                    selected: filters.kind == null,
                    onSelected: (_) {
                      setState(() => filters = const SearchFilters());
                      schedule();
                    },
                  ),
                  for (final e in names.entries)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: filters.kind == e.key,
                        onSelected: (_) {
                          setState(() => filters = SearchFilters(kind: e.key));
                          schedule();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (filters.kind == 'transaction')
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DropdownButton<bool>(
                value: filters.newest,
                items: [
                  DropdownMenuItem(
                    value: false,
                    child: Text(context.l10n.searchRelevance),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: Text(context.l10n.searchNewest),
                  ),
                ],
                onChanged: (v) {
                  setState(
                    () => filters = SearchFilters(
                      kind: filters.kind,
                      accountId: filters.accountId,
                      transactionType: filters.transactionType,
                      currency: filters.currency,
                      from: filters.from,
                      to: filters.to,
                      minimum: filters.minimum,
                      maximum: filters.maximum,
                      newest: v ?? false,
                    ),
                  );
                  schedule();
                },
              ),
            ),
          if (indexing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.searchIndexing),
            ),
          if (loading || indexing) const LinearProgressIndicator(),
          if (error != null)
            ListTile(
              title: Text(error!),
              trailing: TextButton(
                onPressed: () async {
                  if (!await ref.read(searchRepositoryProvider).ready) {
                    if (!mounted) return;
                    setState(() {
                      indexing = true;
                      error = null;
                    });
                    await prepare();
                  } else {
                    await search();
                  }
                },
                child: Text(context.l10n.searchRetry),
              ),
            ),
          Expanded(
            child: hits.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _controller.text.trim().isEmpty
                            ? context.l10n.searchStart
                            : loading || indexing
                            ? ''
                            : context.l10n.noResults,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: hits.length + (page?.next != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == hits.length) {
                        return TextButton(
                          onPressed: loading ? null : () => search(more: true),
                          child: Text(context.l10n.loadMoreResults),
                        );
                      }
                      final hit = hits[i];
                      final amount = hit.amount.isEmpty
                          ? ''
                          : hidden
                          ? '••••'
                          : CurrencyFormatter.formatAmount(
                              Amount(hit.amount),
                              currency: hit.currency.isEmpty
                                  ? ref.read(defaultCurrencyProvider)
                                  : hit.currency,
                            );
                      return ListTile(
                        key: ValueKey('${hit.kind}:${hit.id}'),
                        leading: Icon(
                          hit.kind == 'transaction'
                              ? Icons.receipt_long
                              : hit.kind == 'feature'
                              ? Icons.apps
                              : Icons.search,
                        ),
                        title: _highlight(hit.title),
                        subtitle: Text(
                          '${names[hit.kind]} · ${hit.subtitle}${hit.date > 0 ? ' · ${DateTime.fromMillisecondsSinceEpoch(hit.date * 1000).toIso8601String().substring(0, 10)}' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: amount.isEmpty ? null : Text(amount),
                        onTap: () async {
                          await openSearchHit(context, ref, hit);
                          if (mounted) await search();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _highlight(String title) {
    final words = SearchText.normalize(
      _controller.text,
    ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return Text.rich(
      TextSpan(
        children: [
          for (final part in title.split(RegExp(r'(?<=\s)|(?=\s)')))
            TextSpan(
              text: part,
              style: words.any((w) => SearchText.normalize(part).contains(w))
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
