import 'package:flourish/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/finance/finance_store.dart';
import '../../shared/widgets/report_section.dart';
import '../../shared/widgets/share_row.dart';
import '../../shared/widgets/sparkline.dart';
import '../providers/finance_providers.dart';
import '../providers/theme_providers.dart';

/// Contract payments due in the next 30 days and realized gains.
final _wealthReportProvider =
    FutureProvider<({Amount forecast, int missing, List<Json> gains})>((
      ref,
    ) async {
      ref.watch(financeRevisionProvider);
      final store = ref.watch(financeStoreProvider),
          valuation = ref.watch(valuationProvider),
          currency = ref.watch(defaultCurrencyProvider);
      var forecast = Amount.zero, missing = 0;
      final repository = ContractRepository(store), now = DateTime.now();
      for (final c in await repository.getAll()) {
        for (final p in await repository.payments(c.id)) {
          if (p.paid ||
              p.date.isBefore(DateTime(now.year, now.month, now.day)) ||
              p.date.isAfter(now.add(const Duration(days: 30)))) {
            continue;
          }
          final value = await valuation.convert(p.total, c.currency, currency);
          if (value == null) {
            missing++;
          } else {
            forecast += c.isDebt ? -value : value;
          }
        }
      }
      return (
        forecast: forecast,
        missing: missing,
        gains: (await store.list(
          'activity',
        )).where((a) => a['realizedGain'] != null).toList(),
      );
    });

/// The investment side of reporting, shown under the holdings list:
/// allocation, currency exposure, gains, net-worth history and upcoming
/// contract payments. Monthly cash flow lives on the Spending page.
class WealthReport extends ConsumerWidget {
  const WealthReport({super.key});

  static Map<String, Amount> _sum(Iterable<(String, Amount)> values) {
    final out = <String, Amount>{};
    for (final (key, value) in values) {
      out[key] = (out[key] ?? Amount.zero) + value;
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = FlourishPalette.of(context);
    final currency = ref.watch(defaultCurrencyProvider);
    final wealth = ref.watch(wealthProvider).valueOrNull;
    final history = ref.watch(netWorthHistoryProvider).valueOrNull ?? [];
    final report = ref.watch(_wealthReportProvider).valueOrNull;
    final dates = MaterialLocalizations.of(context);
    String money(Amount a) =>
        CurrencyFormatter.format(a.toDouble(), currency: currency);
    Color tone(int i) => Color(
      AppColors.categoryPalette[(i * 3 + 3) % AppColors.categoryPalette.length],
    );

    final sections = <Widget>[
      if (wealth != null) ...[
        () {
          final allocation = _sum(
            wealth.items
                .where((i) => !i.liability && i.converted != null)
                .map((i) => (i.group, i.converted!)),
          ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final sum = allocation.fold(0.0, (s, e) => s + e.value.toDouble());
          return ReportSection(
            title: context.l10n.assetAllocation,
            child: allocation.isEmpty || sum <= 0
                ? MutedText(context.l10n.noValuedAssets)
                : Column(
                    children: [
                      _StackedBar(
                        shares: [
                          for (final e in allocation) e.value.toDouble() / sum,
                        ],
                        colors: [
                          for (var i = 0; i < allocation.length; i++) tone(i),
                        ],
                      ),
                      const SizedBox(height: Sp.md),
                      for (var i = 0; i < allocation.length; i++)
                        ShareRow(
                          label: allocation[i].key,
                          value: money(allocation[i].value),
                          share: allocation[i].value.toDouble() / sum,
                          color: tone(i),
                          showBar: false,
                        ),
                    ],
                  ),
          );
        }(),
        ReportSection(
          title: context.l10n.currencyExposure,
          subtitle: context.l10n.originalAmounts,
          child: Column(
            children: [
              for (final e in _sum(
                wealth.items.map(
                  (i) => (i.currency, i.liability ? -i.original : i.original),
                ),
              ).entries)
                ValueRow(
                  e.key,
                  CurrencyFormatter.format(e.value.toDouble(), currency: e.key),
                ),
            ],
          ),
        ),
        ReportSection(
          title: context.l10n.holdingGains,
          subtitle: context.l10n.holdingGainsNote,
          child: Column(
            children: [
              for (final item in wealth.items.where(
                (i) => i.gain != null || i.fxGain != null,
              ))
                ValueRow(
                  item.name,
                  context.l10n.priceFxGain(
                    item.gain?.fixed() ?? context.l10n.unknown,
                    item.fxGain?.fixed() ?? context.l10n.unknown,
                  ),
                  tone: (item.gain ?? Amount.zero) >= Amount.zero
                      ? palette.income
                      : palette.expense,
                ),
              if (!wealth.items.any((i) => i.gain != null || i.fxGain != null))
                MutedText(context.l10n.noGainsYet),
            ],
          ),
        ),
      ],
      ReportSection(
        title: context.l10n.netWorthHistory,
        subtitle: context.l10n.netWorthHistoryNote,
        child: Column(
          children: [
            if (history.length > 1)
              Sparkline(
                values: [
                  for (final p in history) amountOf(p['netWorth']).toDouble(),
                ],
                height: 140,
                strokeWidth: 2.6,
              )
            else
              MutedText(context.l10n.chartAppearsLater),
            const SizedBox(height: Sp.sm),
            for (final point in history.reversed.take(8))
              ValueRow(
                dates.formatMediumDate(DateTime.parse(point['date'])),
                money(amountOf(point['netWorth'])),
              ),
          ],
        ),
      ),
      if (report != null) ...[
        ReportSection(
          title: context.l10n.expectedCashFlow,
          subtitle: context.l10n.expectedCashFlowNote,
          child: ValueRow(
            context.l10n.unconvertedPayments(report.missing),
            money(report.forecast),
            tone: report.forecast >= Amount.zero
                ? palette.income
                : palette.expense,
          ),
        ),
        ReportSection(
          title: context.l10n.realizedGains,
          child: report.gains.isEmpty
              ? MutedText(context.l10n.noRealizedGains)
              : Column(
                  children: [
                    for (final gain in report.gains)
                      ValueRow(
                        dates.formatMediumDate(DateTime.parse(gain['date'])),
                        '${gain['realizedGain']} ${gain['currency']}',
                      ),
                  ],
                ),
        ),
      ],
    ];
    return Column(
      children: [
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(top: Sp.lg),
            child: s,
          ),
      ],
    );
  }
}

/// One rounded bar split into colored shares that grow in from the left.
class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.shares, required this.colors});

  final List<double> shares;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.chart),
      curve: Motion.enter,
      builder: (context, t, _) => ClipRRect(
        borderRadius: BorderRadius.circular(Rad.full),
        child: SizedBox(
          height: 12,
          child: Row(
            children: [
              for (var i = 0; i < shares.length; i++)
                Expanded(
                  flex: (shares[i] * 1000 * t).round().clamp(1, 1000),
                  child: Container(
                    margin: EdgeInsetsDirectional.only(
                      end: i == shares.length - 1 ? 0 : 2,
                    ),
                    color: colors[i],
                  ),
                ),
              Expanded(
                flex: ((1 - t) * 1000).round().clamp(0, 1000),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
