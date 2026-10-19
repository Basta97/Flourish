import 'package:flourish/l10n/l10n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/services/preferences_service.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/core/utils/currency_formatter.dart';
import 'package:flourish/core/finance/valuation_service.dart';
import 'package:flourish/presentation/providers/finance_providers.dart';
import 'package:flourish/presentation/providers/theme_providers.dart';
import 'package:flourish/presentation/wealth/holdings_view.dart'
    show currencies;
import 'package:flourish/shared/widgets/animated_counter.dart';
import 'package:flourish/shared/widgets/shimmer_loading.dart';
import 'package:flourish/shared/widgets/sparkline.dart';

/// The Home showcase card: net worth counting up over a slow aurora glow,
/// a trend sparkline from recorded snapshots, and the asset breakdown.
///
/// The card is always ink-dark (in light mode too) so the number reads like a
/// premium statement; text inside therefore uses fixed light colors.
///
/// [compact] drops the sparkline and shrinks the number, for screens (Wealth)
/// where the card sits above other content.
class NetWorthHero extends ConsumerWidget {
  const NetWorthHero({super.key, this.compact = false});

  final bool compact;

  static const _textHigh = Color(0xFFF2F4F7);
  static const _textLow = Color(0xFF9AA3B2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(defaultCurrencyProvider);
    final wealth = ref.watch(wealthProvider);
    final history =
        ref.watch(netWorthHistoryProvider).valueOrNull ?? const <Json>[];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.10),
            blurRadius: 40,
            spreadRadius: -8,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rad.xl - 1),
        child: ColoredBox(
          color: AppColors.heroSurface(context),
          child: Stack(
            children: [
              const Positioned.fill(child: _Aurora()),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Sp.xl,
                  compact ? Sp.lg : Sp.xl,
                  Sp.xl,
                  compact ? Sp.md : Sp.lg,
                ),
                child: wealth.when(
                  data: (w) => _content(context, ref, w, history, currency),
                  // The card is dark in both themes, so skeletons use dark tones.
                  loading: () => Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(brightness: Brightness.dark),
                    child: _skeleton(),
                  ),
                  error: (e, _) => SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        context.l10n.couldNotLoadNetWorth,
                        style: AppTextStyles.body.copyWith(color: _textLow),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    WealthSummary w,
    List<Json> history,
    String currency,
  ) {
    final palette = FlourishPalette.dark;
    final net = w.netWorth.toDouble();
    final values = [
      for (final point
          in history.length > 30
              ? history.sublist(history.length - 30)
              : history)
        amountOf(point['netWorth']).toDouble(),
    ];
    final delta = _deltaPercent(history, net);
    String fmt(double v) => CurrencyFormatter.format(v, currency: currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                w.complete
                    ? context.l10n.netWorthCaps
                    : context.l10n.knownNetWorthCaps,
                style: AppTextStyles.eyebrow.copyWith(color: _textLow),
              ),
            ),
            _CurrencyChip(currency: currency),
          ],
        ),
        SizedBox(height: compact ? Sp.sm : Sp.md),
        SizedBox(
          height: compact ? 36 : 46,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedCounter(
                value: net,
                format: fmt,
                exactText: fmt(w.netWorth.rounded().toDouble()),
                deltaPercent: delta,
                style:
                    (compact
                            ? AppTextStyles.numberLarge
                            : AppTextStyles.numberHero)
                        .copyWith(color: _textHigh),
              ),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: Sp.lg),
          if (values.length >= 2)
            Sparkline(values: values, color: palette.accent, height: 60)
          else
            SizedBox(
              height: 60,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.l10n.trendLineLater,
                  style: AppTextStyles.caption.copyWith(color: _textLow),
                ),
              ),
            ),
        ],
        SizedBox(height: compact ? Sp.md : Sp.lg),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
        const SizedBox(height: Sp.md),
        Row(
          children: [
            _Breakdown(
              label: context.l10n.assets,
              value: fmt(w.assets.toDouble()),
            ),
            _Breakdown(
              label: context.l10n.debts,
              value: fmt(w.liabilities.toDouble()),
            ),
            _Breakdown(
              label: context.l10n.liquid,
              value: fmt(w.liquid.toDouble()),
            ),
          ],
        ),
        if (!w.complete || w.stale) ...[
          const SizedBox(height: Sp.md),
          _Notice(
            text: !w.complete
                ? context.l10n.pricesMissing
                : context.l10n.pricesStale,
          ),
        ],
      ],
    );
  }

  /// Change versus the oldest snapshot within the last 30 days. Null when
  /// there is no earlier observation to compare against.
  static double? _deltaPercent(List<Json> history, double current) {
    if (history.isEmpty) return null;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10);
    final base = history.firstWhere(
      (p) =>
          p['date'].toString().compareTo(cutoff) >= 0 &&
          p['date'].toString() != today,
      orElse: () => const {},
    );
    if (base.isEmpty) return null;
    final from = amountOf(base['netWorth']).toDouble();
    if (from == 0) return null;
    return (current - from) / from.abs() * 100;
  }

  Widget _skeleton() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShimmerLoading.block(width: 90, height: 11),
      const SizedBox(height: Sp.lg),
      ShimmerLoading.block(width: 220, height: 40, radius: Rad.md),
      const SizedBox(height: Sp.lg),
      ShimmerLoading.block(width: double.infinity, height: 60, radius: Rad.md),
      const SizedBox(height: Sp.xl),
      ShimmerLoading.block(width: 240, height: 28),
    ],
  );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      // A gap so long amounts in neighbouring columns never touch.
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: Sp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTextStyles.eyebrow.copyWith(
                fontSize: 10,
                color: NetWorthHero._textLow,
              ),
            ),
            const SizedBox(height: Sp.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: AppTextStyles.numberSmall.copyWith(
                  color: NetWorthHero._textHigh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const tone = AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: tone),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: tone.withValues(alpha: 0.95),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable currency badge; opens a menu to change the reporting currency.
class _CurrencyChip extends ConsumerWidget {
  const _CurrencyChip({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: context.l10n.reportingCurrency,
      initialValue: currency,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(maxHeight: 360, minWidth: 120),
      onOpened: Haptics.select,
      onSelected: (c) async {
        Haptics.select();
        ref.read(defaultCurrencyProvider.notifier).state = c;
        await PreferencesService.setString('default_currency', c);
      },
      itemBuilder: (context) => [
        for (final c in currencies.keys)
          PopupMenuItem(value: c, height: 40, child: Text(c)),
      ],
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 6, 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(Rad.full),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency,
              style: AppTextStyles.caption.copyWith(
                color: NetWorthHero._textHigh,
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: NetWorthHero._textLow,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two soft jade/indigo glows drifting slowly behind the hero. Static under
/// reduce-motion.
class _Aurora extends StatefulWidget {
  const _Aurora();

  @override
  State<_Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<_Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          return Stack(
            children: [
              _glow(
                Alignment(0.9 + 0.15 * math.cos(t), -1.1 + 0.2 * math.sin(t)),
                AppColors.primaryLight.withValues(alpha: 0.22),
                1.1,
              ),
              _glow(
                Alignment(-1.0 + 0.2 * math.sin(t), 1.2 + 0.15 * math.cos(t)),
                AppColors.secondary.withValues(alpha: 0.16),
                0.9,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _glow(Alignment center, Color color, double radius) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
