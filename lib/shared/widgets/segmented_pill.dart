import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:flourish/core/theme/app_text_styles.dart';

/// Segmented control with a thumb that springs between equal-width options.
class SegmentedPill extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor,
    this.height = 40,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Thumb tint. Defaults to the raised surface; pass a semantic color (e.g.
  /// income/expense) to cross-fade the thumb as the selection changes.
  final Color? activeColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = FlourishPalette.of(context);
    final duration = Motion.of(context, const Duration(milliseconds: 380));
    final count = labels.length;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(Rad.full),
        border: Border.all(color: palette.stroke),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / count;
          final thumbColor = activeColor == null
              ? palette.raised
              : activeColor!.withValues(alpha: 0.18);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Motion.springSnappy,
                left: segment * selectedIndex,
                top: 0,
                bottom: 0,
                width: segment,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Motion.morph,
                  decoration: BoxDecoration(
                    color: thumbColor,
                    borderRadius: BorderRadius.circular(Rad.full),
                    border: Border.all(
                      color:
                          activeColor?.withValues(alpha: 0.35) ??
                          palette.highlight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selectedIndex,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == selectedIndex) return;
                            Haptics.select();
                            onChanged(i);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: duration,
                              curve: Motion.morph,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 13,
                                color: i == selectedIndex
                                    ? (activeColor ?? palette.textHigh)
                                    : palette.textLow,
                              ),
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
