import 'package:flutter/material.dart';
import 'package:flourish/core/motion/motion.dart';
import 'package:flourish/core/theme/app_spacing.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  factory ShimmerLoading.card({double height = 100}) =>
      ShimmerLoading(child: _ShimmerCard(height: height));

  factory ShimmerLoading.listItem() =>
      const ShimmerLoading(child: _ShimmerListItem());

  factory ShimmerLoading.circle({double size = 42}) =>
      ShimmerLoading(child: _ShimmerCircle(size: size));

  /// A rounded bar of the given size, for text and number placeholders.
  factory ShimmerLoading.block({
    double width = 120,
    double height = 14,
    double radius = Rad.sm,
  }) => ShimmerLoading(
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF161A22) : const Color(0xFFE9ECF0),
      highlightColor: isDark
          ? const Color(0xFF232836)
          : const Color(0xFFF6F7F9),
      period: const Duration(milliseconds: 1400),
      enabled: !Motion.reduced(context),
      child: child,
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double height;
  const _ShimmerCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Rad.lg),
      ),
    );
  }
}

class _ShimmerListItem extends StatelessWidget {
  const _ShimmerListItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.screenH,
        vertical: Sp.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Rad.md),
            ),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Sp.xs),
                  ),
                ),
                const SizedBox(height: Sp.sm),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Sp.xs),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Sp.sm),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  final double size;
  const _ShimmerCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A column of list-row skeletons, the standard page loader.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: Sp.md),
      children: [for (var i = 0; i < count; i++) ShimmerLoading.listItem()],
    );
  }
}
