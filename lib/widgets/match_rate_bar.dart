import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class MatchRateBar extends StatelessWidget {
  final double rate;
  final bool showLabel;

  const MatchRateBar({super.key, required this.rate, this.showLabel = true});

  Color get _barColor {
    if (rate >= 0.8) return AppColors.secondary;
    if (rate >= 0.5) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (rate * 100).round();
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
              minHeight: 6,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _barColor,
            ),
          ),
        ],
      ],
    );
  }
}
