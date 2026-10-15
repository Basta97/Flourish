import '../../core/finance/transaction_classifier.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/database.dart' show Category;
import '../../shared/widgets/animated_list_item.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/sparkline.dart';
import '../../shared/widgets/stat_pill.dart';
import '../providers/category_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_providers.dart';
import '../providers/transaction_providers.dart';
import '../providers/theme_providers.dart';
import '../../core/services/preferences_service.dart';
import '../../data/finance/finance_store.dart';

class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});
  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  void initState() {
    super.initState();
    final day = PreferencesService.getInt('month_start_day', defaultValue: 1);
    if (DateTime.now().day < day) month = DateTime(month.year, month.month - 1);
  }

  // The report walks every transaction through valuation; cache the future
  // and rebuild it only when its inputs change.
  Future<Json>? _future;
  Object? _futureKey;
  int? _touched;

  void _shiftMonth(int delta) {
    Haptics.select();
    setState(() {
      month = DateTime(month.year, month.month + delta);
      _touched = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final revision = identityHashCode(ref.watch(financeRevisionProvider));
    final tx = identityHashCode(ref.watch(transactionsProvider).valueOrNull);
    final currency = ref.watch(defaultCurrencyProvider);
    final key = (revision, tx, currency, month);
    if (_futureKey != key) {
      _futureKey = key;
      _future = _report(currency);
    }
    final palette = FlourishPalette.of(context);
    final categoryColors = {
      for (final c in ref.watch(categoriesProvider).valueOrNull ?? <Category>[])
        c.name: Color(c.color),
    };

    return FutureBuilder<Json>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              for (final h in [56.0, 120.0, 260.0, 160.0])
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.lg),
                  child: ShimmerLoading.card(height: h),
                ),
            ],
          );
        }
        final j = snapshot.data!;
        final groups = j['categories'] as Map<String, Amount>,
            incomeGroups = j['incomeSources'] as Map<String, Amount>;
        final wealth = ref.watch(wealthProvider).valueOrNull;
        final total = amountOf(j['expense']);
        final history = j['history'] as List<Json>;
        final sortedGroups = groups.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        Color colorOf(String name, int i) =>
            categoryColors[name] ??
            Color(
              AppColors.categoryPalette[i % AppColors.categoryPalette.length],
            );
        String money(Amount a) =>
            CurrencyFormatter.format(a.toDouble(), currency: currency);
        final income = amountOf(j['income']),
            previous = amountOf(j['previousExpense']);
        final change = previous > Amount.zero
            ? (total.toDouble() - previous.toDouble()) /
                  previous.toDouble() *
                  100
            : null;

        final sections = <Widget>[
          // ‹ October 2026 ›
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Previous month',
                style: IconButton.styleFrom(shape: const CircleBorder()),
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM y').format(month),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(color: palette.textHigh),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Next month',
                style: IconButton.styleFrom(shape: const CircleBorder()),
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: StatPill(
                  label: 'Income',
                  icon: Icons.south_west_rounded,
                  tone: palette.income,
                  value: income.toDouble(),
                  exactText: CurrencyFormatter.formatCompact(
                    income.toDouble(),
                    currency: currency,
                  ),
                  format: (v) =>
                      CurrencyFormatter.formatCompact(v, currency: currency),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatPill(
                  label: change == null
                      ? 'Expenses'
                      : 'Expenses · ${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% vs last',
                  icon: Icons.north_east_rounded,
                  tone: palette.expense,
                  value: total.toDouble(),
                  format: (v) =>
                      CurrencyFormatter.formatCompact(v, currency: currency),
                ),
              ),
            ],
          ),
          if (j['missing'] != 0)
            _Notice(
              '${j['missing']} records need historical FX; totals are incomplete.',
            ),
          _Section(
            title: 'Spending by category',
            child: total <= Amount.zero
                ? _Muted('No spending this month.')
                : Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: _AnimatedDonut(
                          key: ValueKey(month),
                          values: [
                            for (final e in sortedGroups) e.value.toDouble(),
                          ],
                          colors: [
                            for (var i = 0; i < sortedGroups.length; i++)
                              colorOf(sortedGroups[i].key, i),
                          ],
                          touched: _touched,
                          onTouch: (i) => setState(() => _touched = i),
                          center: _touched == null
                              ? money(total)
                              : money(sortedGroups[_touched!].value),
                          centerLabel: _touched == null
                              ? 'TOTAL'
                              : sortedGroups[_touched!].key.toUpperCase(),
                        ),
                      ),
                      const SizedBox(height: Sp.lg),
                      for (var i = 0; i < sortedGroups.length; i++)
                        _ShareRow(
                          label: sortedGroups[i].key,
                          value: money(sortedGroups[i].value),
                          share:
                              sortedGroups[i].value.toDouble() /
                              total.toDouble(),
                          color: colorOf(sortedGroups[i].key, i),
                          highlighted: _touched == i,
                          onTap: () => _drilldown(
                            context,
                            j['records'] as List<Json>,
                            sortedGroups[i].key,
                          ),
                        ),
                    ],
                  ),
          ),
          _Section(
            title: 'Income sources',
            child: incomeGroups.isEmpty
                ? _Muted('No income this month.')
                : Column(
                    children: [
                      for (final e in incomeGroups.entries)
                        _ValueRow(e.key, money(e.value), tone: palette.income),
                    ],
                  ),
          ),
          if (wealth != null) ...[
            () {
              final allocation = _allocation(
                wealth.items
                    .where((i) => !i.liability && i.converted != null)
                    .map((i) => (i.group, i.converted!)),
              ).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final sum = allocation.fold(
                0.0,
                (s, e) => s + e.value.toDouble(),
              );
              return _Section(
                title: 'Asset allocation',
                child: allocation.isEmpty || sum <= 0
                    ? _Muted('No valued assets yet.')
                    : Column(
                        children: [
                          _StackedBar(
                            shares: [
                              for (final e in allocation)
                                e.value.toDouble() / sum,
                            ],
                            colors: [
                              for (var i = 0; i < allocation.length; i++)
                                Color(
                                  AppColors.categoryPalette[(i * 3 + 3) %
                                      AppColors.categoryPalette.length],
                                ),
                            ],
                          ),
                          const SizedBox(height: Sp.md),
                          for (var i = 0; i < allocation.length; i++)
                            _ShareRow(
                              label: allocation[i].key,
                              value: money(allocation[i].value),
                              share: allocation[i].value.toDouble() / sum,
                              color: Color(
                                AppColors.categoryPalette[(i * 3 + 3) %
                                    AppColors.categoryPalette.length],
                              ),
                              showBar: false,
                            ),
                        ],
                      ),
              );
            }(),
            _Section(
              title: 'Currency exposure',
              subtitle: 'Original amounts, before conversion.',
              child: Column(
                children: [
                  for (final e in _allocation(
                    wealth.items.map(
                      (i) =>
                          (i.currency, i.liability ? -i.original : i.original),
                    ),
                  ).entries)
                    _ValueRow(
                      e.key,
                      CurrencyFormatter.format(
                        e.value.toDouble(),
                        currency: e.key,
                      ),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Holding gains since opening',
              subtitle:
                  'Price gains and the FX effect on acquisition cost are separate. Missing acquisition history stays unknown.',
              child: Column(
                children: [
                  for (final item in wealth.items.where(
                    (i) => i.gain != null || i.fxGain != null,
                  ))
                    _ValueRow(
                      item.name,
                      'Price ${item.gain?.fixed() ?? 'unknown'} · FX ${item.fxGain?.fixed() ?? 'unknown'}',
                      tone: (item.gain ?? Amount.zero) >= Amount.zero
                          ? palette.income
                          : palette.expense,
                    ),
                  if (!wealth.items.any(
                    (i) => i.gain != null || i.fxGain != null,
                  ))
                    _Muted('No gains recorded yet.'),
                ],
              ),
            ),
          ],
          _Section(
            title: 'Net worth history',
            subtitle:
                'Recorded observations only. No values are invented before tracking began.',
            child: Column(
              children: [
                if (history.length > 1)
                  Sparkline(
                    values: [
                      for (final p in history)
                        amountOf(p['netWorth']).toDouble(),
                    ],
                    height: 140,
                    strokeWidth: 2.6,
                  )
                else
                  _Muted('The chart appears after a few days of tracking.'),
                const SizedBox(height: Sp.sm),
                for (final point in history.reversed.take(8))
                  _ValueRow(point['date'], money(amountOf(point['netWorth']))),
              ],
            ),
          ),
          _Section(
            title: 'Expected cash flow · next 30 days',
            subtitle:
                'Based on unconfirmed contract schedules. This is a projection, not available cash.',
            child: _ValueRow(
              '${j['forecastMissing']} unconverted payments',
              money(amountOf(j['forecast'])),
              tone: amountOf(j['forecast']) >= Amount.zero
                  ? palette.income
                  : palette.expense,
            ),
          ),
          _Section(
            title: 'Realized investment gains',
            child: (j['gains'] as List<Json>).isEmpty
                ? _Muted('No realized gains yet.')
                : Column(
                    children: [
                      for (final gain in j['gains'] as List<Json>)
                        _ValueRow(
                          gain['date'].toString().substring(0, 10),
                          '${gain['realizedGain']} ${gain['currency']}',
                        ),
                    ],
                  ),
          ),
        ];

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          itemCount: sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: Sp.lg),
          itemBuilder: (context, i) => i < Motion.maxStaggered
              ? AnimatedListItem(index: i, child: sections[i])
              : sections[i],
        );
      },
    );
  }

  Map<String, Amount> _allocation(Iterable<(String, Amount)> values) {
    final out = <String, Amount>{};
    for (final (key, value) in values) {
      out[key] = (out[key] ?? Amount.zero) + value;
    }
    return out;
  }

  Future<Json> _report(String currency) async {
    final db = ref.read(databaseProvider),
        store = ref.read(financeStoreProvider),
        valuation = ref.read(valuationProvider);
    final day = PreferencesService.getInt(
      'month_start_day',
      defaultValue: 1,
    ).clamp(1, 28);
    final start = DateTime(month.year, month.month, day),
        end = DateTime(month.year, month.month + 1, day),
        previous = DateTime(month.year, month.month - 1, day);
    final categories = {for (final c in await db.getAllCategories()) c.id: c};
    final parents = {
      for (final p in await store.list('categoryParents'))
        p['child'].toString(): p['parent'] as int,
    };
    final groups = <String, Amount>{},
        incomeGroups = <String, Amount>{},
        records = <Json>[];
    var income = Amount.zero,
        expense = Amount.zero,
        prior = Amount.zero,
        missing = 0,
        forecast = Amount.zero,
        forecastMissing = 0;
    final inRange = (await db.getAllTransactions())
        .where(
          (t) =>
              !t.transactionDate.isBefore(previous) &&
              t.transactionDate.isBefore(end),
        )
        .toList();
    final allDetails = await store.transactionDetailsFor(
      inRange.map((t) => t.id),
    );
    for (final t in inRange) {
      final category = categories[t.categoryId];
      final flow = TransactionClassifier.classify(
        t,
        allDetails[t.id],
        category,
      );
      if (!flow.isCashFlow) continue;
      final signed = await valuation.transactionValue(t.id, currency);
      final amount = signed == null || flow != FlowClass.refund
          ? signed
          : -signed;
      if (amount == null) {
        missing++;
        continue;
      }
      if (t.transactionDate.isBefore(start)) {
        if (flow != FlowClass.income) prior += amount;
        continue;
      }
      var parent = parents['${t.categoryId}'];
      final visited = <int>{t.categoryId};
      while (parent != null &&
          visited.add(parent) &&
          parents.containsKey('$parent')) {
        parent = parents['$parent'];
      }
      final name = categories[parent]?.name ?? category?.name ?? 'Other';
      if (flow == FlowClass.income) {
        income += amount;
        incomeGroups[name] = (incomeGroups[name] ?? Amount.zero) + amount;
      } else {
        expense += amount;
        groups[name] = (groups[name] ?? Amount.zero) + amount;
      }
      records.add({
        'id': t.id,
        'name': name,
        'date': t.transactionDate.toIso8601String(),
        'note': t.note ?? '',
        'amount': '$amount',
        'currency': currency,
      });
    }
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
          forecastMissing++;
        } else {
          forecast += c.isDebt ? -value : value;
        }
      }
    }
    final history = await ref.read(netWorthHistoryProvider.future);
    return {
      'income': income.fixed(),
      'expense': expense.fixed(),
      'previousExpense': prior.fixed(),
      'categories': groups,
      'incomeSources': incomeGroups,
      'missing': missing,
      'records': records,
      'history': history,
      'forecast': forecast.fixed(),
      'forecastMissing': forecastMissing,
      'gains': (await store.list(
        'activity',
      )).where((a) => a['realizedGain'] != null).toList(),
    };
  }

  Future<void> _drilldown(
    BuildContext context,
    List<Json> rows,
    String category,
  ) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(category),
      content: SizedBox(
        width: 420,
        height: 350,
        child: ListView(
          children: [
            for (final row in rows.where((r) => r['name'] == category))
              ListTile(
                title: Text(row['note']),
                subtitle: Text(row['date']),
                trailing: Text('${row['currency']} ${row['amount']}'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.subtitle.copyWith(color: palette.textHigh),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Sp.xs),
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: palette.textLow,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: Sp.md),
          child,
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.sm),
    child: Text(
      text,
      style: AppTextStyles.body.copyWith(
        color: FlourishPalette.of(context).textLow,
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = FlourishPalette.of(context).warning;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: tone),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value, {this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: palette.textHigh),
            ),
          ),
          const SizedBox(width: Sp.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.numberSmall.copyWith(
                color: tone ?? palette.textHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Legend row: color dot, label, amount, and a share bar that fills in.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.value,
    required this.share,
    required this.color,
    this.highlighted = false,
    this.showBar = true,
    this.onTap,
  });

  final String label;
  final String value;
  final double share;
  final Color color;
  final bool highlighted;
  final bool showBar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final row = AnimatedContainer(
      duration: Motion.of(context, Motion.base),
      curve: Motion.morph,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.sm),
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(Rad.sm),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: palette.textHigh,
                  ),
                ),
              ),
              Text(
                '${(share * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.caption.copyWith(color: palette.textLow),
              ),
              const SizedBox(width: Sp.md),
              Text(
                value,
                style: AppTextStyles.numberSmall.copyWith(
                  color: palette.textHigh,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.textLow,
                ),
              ],
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.full),
              child: SizedBox(
                height: 4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: share.clamp(0, 1)),
                  duration: Motion.of(
                    context,
                    const Duration(milliseconds: 900),
                  ),
                  curve: Motion.enter,
                  builder: (context, v, _) => Stack(
                    children: [
                      Container(color: palette.stroke),
                      FractionallySizedBox(
                        widthFactor: v,
                        child: Container(color: color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null
        ? row
        : Pressable(onTap: onTap, scale: 0.98, child: row);
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
      duration: Motion.of(context, const Duration(milliseconds: 900)),
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
                    margin: EdgeInsets.only(
                      right: i == shares.length - 1 ? 0 : 2,
                    ),
                    color: colors[i],
                  ),
                ),
              Expanded(
                flex: ((1 - t) * 1000).round().clamp(0, 1000) + 0,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Donut that sweeps in on first build; tapping a slice pops it outward and
/// shows its amount in the middle.
class _AnimatedDonut extends StatelessWidget {
  const _AnimatedDonut({
    super.key,
    required this.values,
    required this.colors,
    required this.touched,
    required this.onTouch,
    required this.center,
    required this.centerLabel,
  });

  final List<double> values;
  final List<Color> colors;
  final int? touched;
  final ValueChanged<int?> onTouch;
  final String center;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 1100)),
      curve: Motion.enter,
      builder: (context, t, _) => Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: t.clamp(0, 1),
            child: PieChart(
              // fl_chart's own tween would restart every frame of the
              // sweep, so it only runs once the sweep has settled.
              duration: t < 1 ? Duration.zero : Motion.of(context, Motion.base),
              curve: Motion.springSnappy,
              PieChartData(
                startDegreeOffset: -90 - 140 * (1 - t),
                sectionsSpace: 2,
                centerSpaceRadius: 58,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent) return;
                    final i = response?.touchedSection?.touchedSectionIndex;
                    Haptics.select();
                    onTouch(i == null || i < 0 || i == touched ? null : i);
                  },
                ),
                sections: [
                  for (var i = 0; i < values.length; i++)
                    PieChartSectionData(
                      value: values[i],
                      color: colors[i],
                      title: '',
                      radius: (touched == i ? 30.0 : 22.0) * t,
                    ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.eyebrow.copyWith(
                    fontSize: 10,
                    color: palette.textLow,
                  ),
                ),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: FittedBox(
                    child: Text(
                      center,
                      style: AppTextStyles.number.copyWith(
                        color: palette.textHigh,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
