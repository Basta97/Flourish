import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';
import 'package:flourish/data/database/database.dart';
import 'package:flourish/shared/widgets/category_icon_widget.dart';
import 'package:flourish/shared/widgets/pressable.dart';

/// Building blocks shared by the Add and Edit transaction sheets.

/// Accent for a transaction mode: expense coral, income mint, transfer jade.
Color modeColor(BuildContext context, String mode) {
  final palette = FlourishPalette.of(context);
  return switch (mode) {
    'income' => palette.income,
    'expense' => palette.expense,
    _ => palette.accent,
  };
}

/// Small uppercase section label inside a sheet.
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppTextStyles.eyebrow.copyWith(
                color: FlourishPalette.of(context).textLow,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Large centered amount entry under a currency-code label. The digits take
/// the mode color, cross-fading
/// when the mode changes.
class AmountInput extends StatelessWidget {
  const AmountInput({
    super.key,
    required this.controller,
    required this.currency,
    required this.color,
    this.errorText,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String currency;
  final Color color;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Column(
      children: [
        Text(
          currency,
          style: AppTextStyles.eyebrow.copyWith(color: palette.textLow),
        ),
        const SizedBox(height: Sp.xs),
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: color),
          duration: Motion.of(context, Motion.base),
          curve: Motion.morph,
          builder: (context, tint, _) => TextField(
            controller: controller,
            autofocus: autofocus,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            cursorColor: tint,
            style: AppTextStyles.numberHero.copyWith(color: tint),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: AppTextStyles.numberHero.copyWith(
                color: palette.textLow.withValues(alpha: 0.35),
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorText: errorText,
              errorStyle: AppTextStyles.caption.copyWith(
                color: AppColors.danger,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: Sp.sm),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Horizontally scrolling account pills; the selected one gets a tinted ring.
class AccountChips extends StatelessWidget {
  const AccountChips({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelected,
    required this.color,
  });

  final List<Account> accounts;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Sp.sm),
        itemBuilder: (context, i) {
          final a = accounts[i];
          final selected = a.id == selectedId;
          // Builder gives each chip its own context so the selected one can
          // be scrolled into view.
          return Builder(
            builder: (chipContext) {
              // Bring a preselected chip into view (no-op once visible).
              if (selected) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!chipContext.mounted) return;
                  Scrollable.ensureVisible(
                    chipContext,
                    alignmentPolicy:
                        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                  );
                });
              }
              return Pressable(
                haptic: false,
                scale: 0.95,
                semanticLabel: a.name,
                onTap: () {
                  if (selected) return;
                  Haptics.select();
                  onSelected(a.id);
                  Scrollable.ensureVisible(
                    chipContext,
                    alignment: 0.5,
                    duration: Motion.of(chipContext, Motion.base),
                    curve: Motion.morph,
                  );
                },
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.base),
                  curve: Motion.morph,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.14)
                        : AppColors.mutedSurface(context),
                    borderRadius: BorderRadius.circular(Rad.full),
                    border: Border.all(
                      color: selected
                          ? color.withValues(alpha: 0.6)
                          : palette.stroke,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: selected ? palette.textHigh : palette.textLow,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        a.currency,
                        style: AppTextStyles.caption.copyWith(
                          color: selected ? color : palette.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Four-column category picker. Selection springs a tinted ring around the
/// tile and nudges it up in scale.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: Sp.sm,
        crossAxisSpacing: Sp.sm,
        mainAxisExtent: 84,
      ),
      itemBuilder: (context, i) {
        final c = categories[i];
        final selected = c.id == selectedId;
        final tint = Color(c.color);
        return Pressable(
          haptic: false,
          scale: 0.92,
          semanticLabel: c.name,
          onTap: () {
            if (selected) return;
            Haptics.select();
            onSelected(c.id);
          },
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.base),
            curve: Motion.morph,
            decoration: BoxDecoration(
              color: selected
                  ? tint.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(
                color: selected ? tint.withValues(alpha: 0.7) : palette.stroke,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.1 : 1,
                  duration: Motion.of(context, Motion.slow),
                  curve: Motion.springSnappy,
                  child: CategoryIconWidget(
                    iconName: c.icon,
                    color: tint,
                    size: 36,
                    iconSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  c.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: selected ? palette.textHigh : palette.textLow,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Date row with quick Today / Yesterday pills and a full picker.
/// Picking a date keeps the original time of day.
class DatePills extends StatelessWidget {
  const DatePills({super.key, required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  static DateTime _withTime(DateTime day, DateTime time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final isToday = day == today, isYesterday = day == yesterday;
    final other = !isToday && !isYesterday;

    return Row(
      children: [
        _Pill(
          label: 'Today',
          selected: isToday,
          onTap: () => onChanged(_withTime(today, value)),
        ),
        const SizedBox(width: Sp.sm),
        _Pill(
          label: 'Yesterday',
          selected: isYesterday,
          onTap: () => onChanged(_withTime(yesterday, value)),
        ),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: _Pill(
            icon: Icons.calendar_today_rounded,
            label: other ? DateFormat('EEE, MMM d, y').format(value) : 'Pick',
            selected: other,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: now.subtract(const Duration(days: 365 * 5)),
                lastDate: now.add(const Duration(days: 365 * 5)),
              );
              if (picked != null) onChanged(_withTime(picked, value));
            },
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final fg = selected ? palette.textHigh : palette.textLow;
    return Pressable(
      scale: 0.95,
      onTap: () {
        Haptics.select();
        onTap();
      },
      haptic: false,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        curve: Motion.morph,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: Sp.md),
        decoration: BoxDecoration(
          color: selected ? palette.raised : AppColors.mutedSurface(context),
          borderRadius: BorderRadius.circular(Rad.full),
          border: Border.all(
            color: selected ? palette.highlight : palette.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SubmitState { idle, busy, done }

/// Primary action that tints with the mode and morphs label → spinner → ✓.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.color,
    required this.state,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final SubmitState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : AppColors.backgroundDark;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: Motion.of(context, Motion.base),
      curve: Motion.morph,
      builder: (context, tint, _) => FilledButton(
        onPressed: state == SubmitState.idle ? onPressed : () {},
        style: FilledButton.styleFrom(
          backgroundColor: tint,
          foregroundColor: onColor,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rad.full),
          ),
          textStyle: AppTextStyles.subtitle,
        ),
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.base),
          switchInCurve: Motion.settle,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: switch (state) {
            SubmitState.idle => Text(label, key: const ValueKey('label')),
            SubmitState.busy => SizedBox(
              key: const ValueKey('busy'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: onColor,
              ),
            ),
            SubmitState.done => Icon(
              Icons.check_rounded,
              key: const ValueKey('done'),
              size: 28,
              color: onColor,
            ),
          },
        ),
      ),
    );
  }
}
