import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/segmented_pill.dart';
import '../dashboard/widgets/net_worth_hero.dart';
import '../providers/finance_providers.dart';
import '../providers/theme_providers.dart';
import 'holdings_view.dart';
import 'contracts_view.dart';
import 'reports_view.dart';
import 'finance_tools_view.dart';

/// Wealth: the compact net-worth card (shared with Home) above a sliding
/// segmented control that drives four swipeable pages.
class WealthScreen extends ConsumerStatefulWidget {
  const WealthScreen({super.key});

  @override
  ConsumerState<WealthScreen> createState() => _WealthScreenState();
}

class _WealthScreenState extends ConsumerState<WealthScreen>
    with SingleTickerProviderStateMixin {
  static const _tabCount = 4;

  late final TabController _controller = TabController(
    length: _tabCount,
    vsync: this,
  );
  bool _refreshing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navWealth),
        actions: [
          IconButton(
            tooltip: context.l10n.refreshPrices,
            onPressed: _refreshPrices,
            icon: AnimatedRotation(
              turns: _refreshing ? 1 : 0,
              duration: Motion.of(context, const Duration(milliseconds: 900)),
              curve: Motion.morph,
              child: const Icon(Icons.refresh_rounded),
            ),
          ),
          IconButton(
            tooltip: context.l10n.settings,
            onPressed: () {
              Haptics.tap();
              context.push('/settings');
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: Sp.xs),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(Sp.screenH, Sp.xs, Sp.screenH, 0),
            child: NetWorthHero(compact: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Sp.screenH,
              Sp.lg,
              Sp.screenH,
              Sp.xs,
            ),
            // Rebuilds as the pages are swiped so the thumb follows along.
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => SegmentedPill(
                labels: [
                  context.l10n.holdings,
                  context.l10n.obligations,
                  context.l10n.reports,
                  context.l10n.tools,
                ],
                selectedIndex: _controller.index,
                onChanged: (i) => _controller.animateTo(
                  i,
                  duration: Motion.of(context, Motion.slow),
                  curve: Motion.morph,
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: const [
                HoldingsView(),
                ContractsView(),
                ReportsView(),
                FinanceToolsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
