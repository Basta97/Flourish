import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/pressable.dart';

/// What the Add button's picker returns.
enum AddChoice { expense, income, transfer, scan, template }

/// Fans the transaction types out above the island's Add button. Resolves to
/// the chosen type, or null when dismissed.
Future<AddChoice?> showAddTypeMenu(BuildContext context) {
  final l = context.l10n;
  return showGeneralDialog<AddChoice>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: Motion.of(context, Motion.base),
    transitionBuilder: (context, animation, _, child) => BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: 6 * animation.value,
        sigmaY: 6 * animation.value,
      ),
      child: FadeTransition(opacity: animation, child: child),
    ),
    pageBuilder: (context, _, _) {
      final palette = FlourishPalette.of(context);
      final options = [
        (
          AddChoice.template,
          l.useTemplate,
          Icons.bookmark_outline,
          palette.accent,
        ),
        (
          AddChoice.expense,
          l.expense,
          Icons.north_east_rounded,
          palette.expense,
        ),
        (AddChoice.income, l.income, Icons.south_west_rounded, palette.income),
        (
          AddChoice.transfer,
          l.transfer,
          Icons.swap_horiz_rounded,
          const Color(0xFF5B9DF5),
        ),
        (
          AddChoice.scan,
          l.scanOrImport,
          Icons.document_scanner_outlined,
          const Color(0xFF8B7CF6),
        ),
      ];
      final reduced = Motion.reduced(context);
      final bottom = MediaQuery.paddingOf(context).bottom;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          // Stands in for the island's Add button, turned into a close.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + 12 + 8,
            child: Center(
              child: Pressable(
                onTap: () => Navigator.of(context).pop(),
                scale: 0.9,
                semanticLabel: MaterialLocalizations.of(
                  context,
                ).closeButtonLabel,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryLight, AppColors.primaryDeep],
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppColors.backgroundDark,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: Sp.screenH,
            right: Sp.screenH,
            // Island: 12 bottom gap + 72 tall; leave a little air above it.
            bottom: bottom + 12 + 72 + Sp.lg,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.whatToAdd,
                    style: AppTextStyles.eyebrow.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: Sp.md),
                  Row(
                    children: [
                      for (var i = 0; i < options.length; i++)
                        Expanded(
                          child: _Option(
                            label: options[i].$2,
                            icon: options[i].$3,
                            tone: options[i].$4,
                            onTap: () {
                              Haptics.select();
                              Navigator.of(context).pop(options[i].$1);
                            },
                          ).maybeAnimate(reduced, i),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

extension on Widget {
  /// Rises out of the Add button, fanning left to right.
  Widget maybeAnimate(bool reduced, int index) => reduced
      ? this
      : animate(delay: Motion.staggerDelay(index))
            .fadeIn(duration: Motion.base, curve: Motion.enter)
            .slideY(
              begin: 0.6,
              end: 0,
              duration: Motion.slow,
              curve: Motion.settle,
            )
            .scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1, 1),
              duration: Motion.slow,
              curve: Motion.settle,
            );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.raised,
              border: Border.all(color: tone.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: tone.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: tone, size: 24),
          ),
          const SizedBox(height: Sp.sm),
          ExcludeSemantics(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTextStyles.caption.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
