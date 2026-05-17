import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class DifficultyStars extends StatelessWidget {
  final int difficulty;
  final double size;

  const DifficultyStars({
    super.key,
    required this.difficulty,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < difficulty ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < difficulty ? AppColors.streakGold : AppColors.textHint,
        );
      }),
    );
  }
}
