import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/l10n.dart';

/// What the motivation card is cheering about.
sealed class Motivation {
  const Motivation();
}

/// Money kept this month; [amount] is already formatted.
class SavedMotivation extends Motivation {
  const SavedMotivation(this.amount);
  final String amount;
}

/// A savings goal passed a quarter mark (25, 50, 75 or 100%).
class GoalMotivation extends Motivation {
  const GoalMotivation(this.goal, this.percent);
  final String goal;
  final int percent;
}

/// Nothing to celebrate yet: a rotating encouraging line.
class DailyMotivation extends Motivation {
  const DailyMotivation();
}

/// A small card on Home with an encouraging line. Wins (money saved, goal
/// milestones) get a one-off sparkle burst; tapping shows another line.
/// Everything is static when the OS asks to reduce motion.
class MotivationCard extends StatefulWidget {
  const MotivationCard({super.key, required this.motivation});

  final Motivation motivation;

  @override
  State<MotivationCard> createState() => _MotivationCardState();
}

class _MotivationCardState extends State<MotivationCard>
    with SingleTickerProviderStateMixin {
  // Starts on today's line so it changes day to day but not on every visit.
  late int _quote = DateTime.now().difference(DateTime(2024)).inDays;
  bool _showQuote = false;
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _celebrating => !_showQuote && widget.motivation is! DailyMotivation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _celebrating && !Motion.reduced(context)) {
        _burst.forward();
      }
    });
  }

  @override
  void didUpdateWidget(MotivationCard old) {
    super.didUpdateWidget(old);
    if (old.motivation.runtimeType != widget.motivation.runtimeType &&
        _celebrating &&
        !Motion.reduced(context)) {
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  String _text(AppLocalizations l) {
    if (_showQuote) return _quoteText(l);
    return switch (widget.motivation) {
      SavedMotivation(:final amount) => l.motivationSaved(amount),
      GoalMotivation(:final goal, percent: 100) => l.motivationGoalDone(goal),
      GoalMotivation(:final goal, :final percent) => l.motivationGoalMilestone(
        percent,
        goal,
      ),
      DailyMotivation() => _quoteText(l),
    };
  }

  String _quoteText(AppLocalizations l) {
    final quotes = [
      l.motivationQuote1,
      l.motivationQuote2,
      l.motivationQuote3,
      l.motivationQuote4,
      l.motivationQuote5,
      l.motivationQuote6,
      l.motivationQuote7,
    ];
    return quotes[_quote % quotes.length];
  }

  void _next() {
    Haptics.select();
    setState(() {
      if (_showQuote || widget.motivation is DailyMotivation) _quote++;
      _showQuote = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = FlourishPalette.of(context);
    final reduced = Motion.reduced(context);
    final celebrating = _celebrating;
    final tone = celebrating ? palette.accent : const Color(0xFF8B7CF6);
    final text = _text(l);

    Widget card = Semantics(
      button: true,
      label: text,
      hint: l.motivationNextHint,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _next,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(color: tone.withValues(alpha: 0.28)),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                tone.withValues(alpha: 0.16),
                palette.surface.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CustomPaint(
                  painter: _BurstPainter(_burst, tone),
                  child: _Badge(
                    tone: tone,
                    celebrating: celebrating,
                    reduced: reduced,
                  ),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (celebrating ? l.motivationWinTitle : l.motivationTitle)
                          .toUpperCase(),
                      style: AppTextStyles.eyebrow.copyWith(color: tone),
                    ),
                    const SizedBox(height: Sp.xs),
                    AnimatedSwitcher(
                      duration: reduced ? Duration.zero : Motion.base,
                      switchInCurve: Motion.enter,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [...previous, ?current],
                      ),
                      child: Text(
                        text,
                        key: ValueKey(text),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: palette.textHigh,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!reduced && celebrating) {
      card = card
          .animate(delay: const Duration(milliseconds: 500))
          .shimmer(
            duration: const Duration(milliseconds: 1400),
            color: Colors.white.withValues(alpha: 0.10),
          );
    }
    return card;
  }
}

/// The round icon: a sparkle for wins, a gently breathing sprout otherwise.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.tone,
    required this.celebrating,
    required this.reduced,
  });

  final Color tone;
  final bool celebrating;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    Widget icon = Icon(
      celebrating ? Icons.auto_awesome_rounded : Icons.spa_outlined,
      size: 20,
      color: tone,
    );
    if (!reduced) {
      icon = celebrating
          ? icon
                .animate()
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1, 1),
                  duration: Motion.slow,
                  curve: Motion.settle,
                )
                .rotate(begin: -0.15, end: 0, duration: Motion.slow)
          : icon
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1.06, 1.06),
                  duration: const Duration(milliseconds: 1800),
                  curve: Curves.easeInOut,
                );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone.withValues(alpha: 0.16),
      ),
      child: Center(child: icon),
    );
  }
}

/// Eight dots that fly out of the badge and fade, once.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.animation, this.color) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t == 0 || t == 1) return;
    final eased = Curves.easeOutCubic.transform(t);
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - t).clamp(0, 1) * 0.9);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      final distance = size.width * (0.45 + 0.55 * eased);
      final offset =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(offset, (i.isEven ? 2.6 : 1.8) * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}
