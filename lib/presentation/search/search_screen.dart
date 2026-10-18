import 'package:flourish/l10n/l10n.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/presentation/providers/account_providers.dart';
import 'package:flourish/presentation/providers/category_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/shared/widgets/empty_state.dart';
import 'package:flourish/shared/widgets/liquid_page.dart';
import 'package:flourish/shared/widgets/transaction_swipe_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  List<Transaction>? _results;
  bool _isSearching = false;
  String _typeFilter = 'all';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _results = null);
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    final db = ref.read(databaseProvider);
    final results = await db.searchTransactions(query);
    if (mounted) {
      setState(() {
        _results = _typeFilter == 'all'
            ? results
            : results.where((t) => t.type == _typeFilter).toList();
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.searchTransactionsHint,
            border: InputBorder.none,
            hintStyle: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          style: AppTextStyles.body,
          onChanged: (v) => _onSearchChanged(v),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _results = null);
              },
            ),
        ],
      ),
      body: LiquidPageBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
              child: Row(
                children: [
                  _FilterChip(
                    label: context.l10n.all,
                    selected: _typeFilter == 'all',
                    onTap: () {
                      setState(() => _typeFilter = 'all');
                      _search(_controller.text);
                    },
                  ),
                  const SizedBox(width: Sp.sm),
                  _FilterChip(
                    label: context.l10n.income,
                    selected: _typeFilter == 'income',
                    color: AppColors.income,
                    onTap: () {
                      setState(() => _typeFilter = 'income');
                      _search(_controller.text);
                    },
                  ),
                  const SizedBox(width: Sp.sm),
                  _FilterChip(
                    label: context.l10n.expense,
                    selected: _typeFilter == 'expense',
                    color: AppColors.expense,
                    onTap: () {
                      setState(() => _typeFilter = 'expense');
                      _search(_controller.text);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.md),
            Expanded(
              child: _isSearching
                  ? const ShimmerList()
                  : _results == null
                  ? EmptyState(
                      icon: Icons.search,
                      title: context.l10n.searchTransactions,
                      subtitle: context.l10n.searchSubtitle,
                    )
                  : _results!.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: context.l10n.noResults,
                    )
                  : categoriesAsync.when(
                      data: (categories) => accountsAsync.when(
                        data: (accounts) {
                          final catMap = {for (var c in categories) c.id: c};
                          final accountMap = {for (var a in accounts) a.id: a};
                          return ListView.builder(
                            itemCount: _results!.length,
                            itemBuilder: (ctx, i) {
                              final t = _results![i];
                              final cat = catMap[t.categoryId];
                              final account = accountMap[t.accountId];
                              return TransactionSwipeTile(
                                transaction: t,
                                category: cat,
                                accountName: account?.name,
                                currency:
                                    account?.currency ??
                                    ref.watch(defaultCurrencyProvider),
                              );
                            },
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => const SizedBox.shrink(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = selected ? (color ?? AppColors.primary) : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(Sp.xxl),
          border: Border.all(
            color: selected
                ? (color ?? AppColors.primary)
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 13,
            color: selected ? (color ?? AppColors.primary) : null,
          ),
        ),
      ),
    );
  }
}
