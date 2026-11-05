import 'package:flourish/data/database/database.dart';
import 'package:flourish/l10n/l10n.dart';
import 'package:flourish/shared/category_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/finance/payment_methods.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/widgets/animated_donut.dart';
import '../../shared/widgets/animated_list_item.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/report_section.dart';
import '../../shared/widgets/share_row.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/spending_bar_chart.dart';
import '../providers/account_providers.dart';
import '../providers/finance_providers.dart';
import '../providers/insights_providers.dart';

/// Where the money went in one reporting month: the headline number with
/// pace and budget, daily bars, categories, the six-month trend, merchants
/// and how it was paid.
class SpendingStatsView extends ConsumerStatefulWidget {
  const SpendingStatsView({super.key});

  @override
  ConsumerState<SpendingStatsView> createState() => _SpendingStatsViewState();
}

class _SpendingStatsViewState extends ConsumerState<SpendingStatsView> {
  int? _touched;

  void _shift(int delta) {
    Haptics.select();
    final month = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state = DateTime(
      month.year,
      month.month + delta,
    );
    setState(() => _touched = null);
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final current = ref.watch(currentMonthProvider);
    final period = ref.watch(spendingPeriodProvider(month));
    final palette = FlourishPalette.of(context);

    final header = Row(
      children: [
        IconButton.filledTonal(
          tooltip: context.l10n.previousMonth,
          style: IconButton.styleFrom(shape: const CircleBorder()),
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            DateFormat.yMMMM(
              Localizations.localeOf(context).toLanguageTag(),
            ).format(month),
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(color: palette.textHigh),
          ),
        ),
        IconButton.filledTonal(
          tooltip: context.l10n.nextMonth,
          style: IconButton.styleFrom(shape: const CircleBorder()),
          onPressed: month.isBefore(current) ? () => _shift(1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );

    return period.when(
      skipLoadingOnReload: true,
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(
          Sp.screenH,
          Sp.lg,
          Sp.screenH,
          Sp.bottomNavClear,
        ),
        children: [
          header,
          for (final h in [140.0, 200.0, 260.0])
            Padding(
              padding: const EdgeInsets.only(top: Sp.lg),
              child: ShimmerLoading.card(height: h),
            ),
        ],
      ),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(Sp.screenH),
        children: [
          header,
          EmptyState(
            icon: Icons.error_outline_rounded,
            title: context.l10n.couldNotLoadReport,
            action: TextButton(
              onPressed: () => ref.invalidate(spendingPeriodProvider(month)),
              child: Text(context.l10n.retry),
            ),
          ),
        ],
      ),
      data: (p) {
        final sections = _sections(context, p, month, month == current);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            Sp.screenH,
            Sp.lg,
            Sp.screenH,
            Sp.bottomNavClear,
          ),
          itemCount: sections.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: Sp.lg),
          itemBuilder: (context, i) {
            if (i == 0) return header;
            final child = sections[i - 1];
            return i < Motion.maxStaggered
                ? AnimatedListItem(index: i, child: child)
                : child;
          },
        );
      },
    );
  }

  List<Widget> _sections(
    BuildContext context,
    SpendingPeriod p,
    DateTime month,
    bool isCurrent,
  ) {
    final palette = FlourishPalette.of(context);
    final l = context.l10n;
    final now = DateTime.now();
    final c = p.currency;
    String money(Amount a) =>
        CurrencyFormatter.format(a.toDouble(), currency: c);
    String compact(double v) => CurrencyFormatter.formatCompact(v, currency: c);
    final accounts = {
      for (final a
          in ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        a.id: a,
    };
    final instruments = {
      for (final i
          in ref.watch(paymentInstrumentsProvider).valueOrNull ??
              const <PaymentInstrument>[])
        i.id: i,
    };
    Color colorOf(CategorySpend s, int i) => s.category != null
        ? Color(s.category!.color)
        : Color(
            AppColors.categoryPalette[i % AppColors.categoryPalette.length],
          );
    String nameOf(CategorySpend s) => s.category?.displayName ?? l.other;
    final total = p.spending.toDouble();
    final elapsed = p.elapsedDays(now);

    // Same point of last month, for the pace comparison.
    final lastToDate = p.previousToDate(now);

    return [
      _Hero(period: p, isCurrent: isCurrent, now: now),
      if (p.missing > 0) NoticeBanner(l.missingFxNotice(p.missing)),
      ReportSection(
        title: l.dailySpending,
        subtitle: p.previousSpending > Amount.zero
            ? l.lastMonthToDate(money(lastToDate))
            : null,
        child: total <= 0
            ? MutedText(l.noSpendingMonth)
            : SpendingBarChart(
                values: [for (final d in p.daily) d.toDouble()],
                color: palette.expense,
                highlight: isCurrent ? elapsed - 1 : null,
                labelEvery: 7,
                label: (i) => '${p.start.add(Duration(days: i)).day}',
                tooltip: (i, v) =>
                    '${DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(p.start.add(Duration(days: i)))}\n${compact(v)}',
              ),
      ),
      ReportSection(
        title: l.spendingByCategory,
        child: total <= 0
            ? MutedText(l.noSpendingMonth)
            : Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: AnimatedDonut(
                      key: ValueKey(month),
                      values: [
                        for (final s in p.categories) s.amount.toDouble(),
                      ],
                      colors: [
                        for (var i = 0; i < p.categories.length; i++)
                          colorOf(p.categories[i], i),
                      ],
                      touched: _touched,
                      onTouch: (i) => setState(() => _touched = i),
                      center: _touched == null
                          ? money(p.spending)
                          : money(p.categories[_touched!].amount),
                      centerLabel: _touched == null
                          ? l.totalCaps
                          : nameOf(p.categories[_touched!]).toUpperCase(),
                    ),
                  ),
                  const SizedBox(height: Sp.lg),
                  for (var i = 0; i < p.categories.length; i++)
                    ShareRow(
                      label: nameOf(p.categories[i]),
                      value: money(p.categories[i].amount),
                      share: p.categories[i].amount.toDouble() / total,
                      color: colorOf(p.categories[i], i),
                      highlighted: _touched == i,
                      onTap: p.categories[i].category == null
                          ? null
                          : () => context.go(
                              '/transactions?category=${p.categories[i].category!.id}'
                              '&month=${month.year}-${month.month}',
                            ),
                    ),
                ],
              ),
      ),
      _Trend(month: month),
      if (p.merchants.isNotEmpty)
        ReportSection(
          title: l.topMerchants,
          child: Column(
            children: [
              for (final m in p.merchants.take(5))
                _MerchantRow(
                  name: m.name,
                  count: m.count,
                  value: money(m.amount),
                  share: m.amount.toDouble() / total,
                ),
            ],
          ),
        ),
      if (isCurrent && p.upcoming > Amount.zero)
        ReportSection(
          title: l.upcomingCommitted,
          subtitle: l.upcomingCommittedNote,
          child: ValueRow(
            l.recurring,
            money(p.upcoming),
            tone: palette.expense,
          ),
        ),
      for (final (title, rows) in [
        (
          l.byAccount,
          {
            for (final e in p.byAccount.entries)
              accounts[e.key]?.name ?? l.unknown: e.value,
          },
        ),
        (
          l.howYouPaid,
          {
            for (final e in p.byMethod.entries)
              (e.key == null ? l.notRecorded : PaymentMethods.label(e.key!)):
                  e.value,
          },
        ),
        (
          l.byCardOrWallet,
          {
            for (final e in p.byInstrument.entries)
              if (instruments[e.key] case final i?) i.label: e.value,
          },
        ),
        (l.spendingByCurrency, p.byCurrency),
        (
          l.feesInterestPaid,
          {
            for (final e in p.fees.entries)
              switch (e.key) {
                'fx' => l.feesForeign,
                'transfer' => l.feesTransfer,
                'cashAdvance' => l.feesCashAdvance,
                'interest' => l.interest,
                'late' => l.feesLate,
                'annual' => l.feesAnnual,
                'investment' => l.feesInvestment,
                _ => l.feesOther,
              }: e.value,
          },
        ),
      ])
        if (rows.length > 1 || (rows.isNotEmpty && title == l.feesInterestPaid))
          ReportSection(
            title: title,
            child: Column(
              children: [
                for (final e
                    in (rows.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value))))
                  ValueRow(
                    e.key,
                    money(e.value),
                    tone: title == l.feesInterestPaid
                        ? FlourishPalette.of(context).danger
                        : null,
                  ),
              ],
            ),
          ),
      ReportSection(
        title: l.incomeSources,
        child: p.incomeSources.isEmpty
            ? MutedText(l.noIncomeMonth)
            : Column(
                children: [
                  for (final s in p.incomeSources)
                    ValueRow(nameOf(s), money(s.amount), tone: palette.income),
                ],
              ),
      ),
    ];
  }
}

/// Spent this month, its change against last month, the daily average,
/// and — for the running month — the projected total against the budget.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.period,
    required this.isCurrent,
    required this.now,
  });

  final SpendingPeriod period;
  final bool isCurrent;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = period, l = context.l10n;
    final palette = FlourishPalette.of(context);
    String money(Amount a) =>
        CurrencyFormatter.format(a.toDouble(), currency: p.currency);
    final change = p.changeVsPrevious(now);
    final projected = isCurrent ? p.projected(now) : p.spending;
    final budget = p.budget;
    final used = budget == null || budget <= Amount.zero
        ? null
        : (p.budgetSpent.toDouble() / budget.toDouble());
    final overPace =
        budget != null && projected > p.spending + budget - p.budgetSpent;
    return AppCard(
      padding: const EdgeInsets.all(Sp.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.spending.toUpperCase(),
            style: AppTextStyles.eyebrow.copyWith(color: palette.textLow),
          ),
          const SizedBox(height: Sp.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    money(p.spending),
                    style: AppTextStyles.number.copyWith(
                      fontSize: 34,
                      color: palette.textHigh,
                    ),
                  ),
                ),
              ),
              if (change != null)
                _Chip(
                  text:
                      '${change >= 0 ? '▲' : '▼'} ${l.percentVsLast(change.abs().toStringAsFixed(0))}',
                  // Spending more than last month is the bad direction.
                  tone: change > 0 ? palette.expense : palette.income,
                ),
            ],
          ),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.lg,
            runSpacing: Sp.xs,
            children: [
              _Fact(
                label: l.dailyAverage,
                value: money(p.averageDaily(now).rounded()),
              ),
              _Fact(
                label: l.income,
                value: money(p.income),
                tone: palette.income,
              ),
              _Fact(
                label: l.saved,
                value: money(p.net),
                tone: p.net >= Amount.zero ? palette.income : palette.expense,
              ),
            ],
          ),
          if (used != null) ...[
            const SizedBox(height: Sp.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.full),
              child: LinearProgressIndicator(
                value: used.clamp(0, 1),
                minHeight: 8,
                backgroundColor: palette.stroke,
                color: used > 1
                    ? palette.expense
                    : used > 0.85
                    ? palette.warning
                    : palette.accent,
              ),
            ),
            const SizedBox(height: Sp.sm),
            Text(
              p.budgetSpent > budget!
                  ? l.budgetOver(money(p.budgetSpent - budget))
                  : l.budgetLeft(money(budget - p.budgetSpent), money(budget)),
              style: AppTextStyles.caption.copyWith(color: palette.textLow),
            ),
          ],
          if (isCurrent &&
              p.spending > Amount.zero &&
              p.elapsedDays(now) < p.days) ...[
            const SizedBox(height: Sp.xs),
            Text(
              l.projectedSpend(money(projected.rounded(0))),
              style: AppTextStyles.caption.copyWith(
                color: overPace ? palette.warning : palette.textLow,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: palette.textLow),
        ),
        Text(
          value,
          style: AppTextStyles.numberSmall.copyWith(
            color: tone ?? palette.textHigh,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 4),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Rad.full),
    ),
    child: Text(text, style: AppTextStyles.caption.copyWith(color: tone)),
  );
}

/// Spending and income for the last six months, side by side.
class _Trend extends ConsumerWidget {
  const _Trend({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = FlourishPalette.of(context);
    final series = ref.watch(spendingSeriesProvider((month, 6))).valueOrNull;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ReportSection(
      title: context.l10n.monthlyTrend,
      subtitle: context.l10n.monthlyTrendNote,
      child: series == null
          ? ShimmerLoading.card(height: 160)
          : series.every(
              (s) => s.spending <= Amount.zero && s.income <= Amount.zero,
            )
          ? MutedText(context.l10n.chartAppearsLater)
          : SpendingBarChart(
              values: [for (final s in series) s.spending.toDouble()],
              secondary: [for (final s in series) s.income.toDouble()],
              color: palette.expense,
              secondaryColor: palette.income,
              label: (i) => DateFormat.MMM(locale).format(series[i].start),
              tooltip: (i, v) =>
                  '${DateFormat.yMMM(locale).format(series[i].start)}\n'
                  '${CurrencyFormatter.formatCompact(v, currency: ref.read(spendingPeriodProvider(month)).valueOrNull?.currency ?? '')}',
            ),
    );
  }
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.name,
    required this.count,
    required this.value,
    required this.share,
  });

  final String name;
  final int count;
  final String value;
  final double share;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: palette.accentSoft,
            child: Text(
              name.characters.first.toUpperCase(),
              style: AppTextStyles.bodyMedium.copyWith(color: palette.accent),
            ),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: palette.textHigh,
                  ),
                ),
                Text(
                  '${context.l10n.purchases(count)} · ${(share * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.caption.copyWith(color: palette.textLow),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: AppTextStyles.numberSmall.copyWith(color: palette.textHigh),
          ),
        ],
      ),
    );
  }
}
