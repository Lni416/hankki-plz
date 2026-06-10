import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// 보유 재료 매칭 표시 — "5개 중 4개 보유" 형태의 직관적 라벨
class MatchRateBar extends StatelessWidget {
  final int matched;
  final int total;
  final bool showLabel;

  const MatchRateBar({
    super.key,
    required this.matched,
    required this.total,
    this.showLabel = true,
  });

  double get _rate => total > 0 ? matched / total : 0.0;

  Color get _barColor {
    if (_rate >= 0.8) return AppColors.secondary;
    if (_rate >= 0.5) return AppColors.warning;
    return AppColors.danger;
  }

  String get _label {
    if (matched >= total) return '재료 다 있어요!';
    if (total - matched == 1) return '1개만 더!';
    return '$total개 중 $matched개 보유';
  }

  Color get _labelColor {
    if (matched >= total) return AppColors.secondary;
    if (total - matched == 1) return AppColors.warning;
    return _barColor;
  }

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _rate,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
              minHeight: 6,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _labelColor,
            ),
          ),
        ],
      ],
    );
  }
}
