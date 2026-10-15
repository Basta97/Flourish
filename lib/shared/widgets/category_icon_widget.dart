import 'package:flutter/material.dart';
import 'package:flourish/core/utils/icon_utils.dart';

class CategoryIconWidget extends StatelessWidget {
  final String iconName;
  final Color color;
  final double size;
  final double iconSize;

  const CategoryIconWidget({
    super.key,
    required this.iconName,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(
        IconUtils.categoryIcon(iconName),
        color: color,
        size: iconSize,
      ),
    );
  }
}
