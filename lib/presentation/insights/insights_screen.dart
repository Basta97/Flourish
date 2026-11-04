import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/global_search_button.dart';
import '../budgets/budgets_screen.dart';
import '../dashboard/widgets/net_worth_hero.dart';
import '../goals/goals_screen.dart';
import '../providers/finance_providers.dart';
import '../providers/theme_providers.dart';
import '../wealth/contracts_view.dart';
import '../wealth/holdings_view.dart';
import 'spending_stats_view.dart';

/// Insights: where the money went this month first, then the plans that
/// shape it (budgets, goals) and what is owned or owed.
class InsightsScreen extends ConsumerStatefulWidget {
  static const tabs = [
    'spending',
    'budgets',
    'goals',
    'holdings',
    'obligations',
  ];

  final String? initialTab;
  const InsightsScreen({super.key, this.initialTab});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: InsightsScreen.tabs.length,
    initialIndex: InsightsScreen.tabs
        .indexOf(widget.initialTab ?? '')
        .clamp(0, InsightsScreen.tabs.length - 1),
    vsync: this,
  );
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _onWealth => _controller.index >= 3;

  Future<void> _refreshPrices() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final market = ref.read(marketDataProvider);
    try {
      await market.refresh(
        reportingCurrency: ref.read(defaultCurrencyProvider),
        force: true,
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    if (!mounted) return;
    market.warnings.isEmpty ? Haptics.success() : Haptics.warning();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          market.warnings.isEmpty
              ? context.l10n.pricesRefreshed
              : market.warnings.join('\n'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [l.spending, l.budgets, l.goals, l.holdings, l.obligations];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.insights),
        actions: [
          const GlobalSearchButton(),
          if (_onWealth)
            IconButton(
              tooltip: l.refreshPrices,
              onPressed: _refreshPrices,
              icon: AnimatedRotation(
                turns: _refreshing ? 1 : 0,
                duration: Motion.of(context, const Duration(milliseconds: 900)),
                curve: Motion.morph,
                child: const Icon(Icons.refresh_rounded),
              ),
            ),
          const SizedBox(width: Sp.xs),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
              itemCount: labels.length,
              separatorBuilder: (_, _) => const SizedBox(width: Sp.sm),
              itemBuilder: (context, i) => _TabChip(
                label: labels[i],
                selected: _controller.index == i,
                onTap: () {
                  Haptics.select();
                  _controller.animateTo(
                    i,
                    duration: Motion.of(context, Motion.slow),
                    curve: Motion.morph,
                  );
                },
              ),
            ),
          ),
          // AnimatedSize asserts with a zero duration.
          AnimatedSize(
            duration: Motion.reduced(context)
                ? const Duration(milliseconds: 1)
                : Motion.base,
            curve: Motion.morph,
            child: _onWealth
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(
                      Sp.screenH,
                      Sp.md,
                      Sp.screenH,
                      0,
                    ),
                    child: NetWorthHero(compact: true),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [
                SpendingStatsView(),
                BudgetsScreen(embedded: true),
                GoalsScreen(embedded: true),
                HoldingsView(),
                ContractsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Center(
      child: Material(
        color: selected ? palette.accent : AppColors.mutedSurface(context),
        shape: StadiumBorder(
          side: BorderSide(color: selected ? palette.accent : palette.stroke),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.lg,
              vertical: Sp.sm,
            ),
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: selected ? AppColors.backgroundDark : palette.textHigh,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
