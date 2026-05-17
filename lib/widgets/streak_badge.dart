import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_theme.dart';

class StreakBadge extends StatelessWidget {
  final int streak;
  final bool large;

  const StreakBadge({super.key, required this.streak, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 56.0 : 36.0;
    final fontSize = large ? 20.0 : 14.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔥', style: TextStyle(fontSize: fontSize * 0.8)),
          Text(
            '$streak',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize * 0.7,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    ).animate().scale(
          duration: 300.ms,
          curve: Curves.elasticOut,
        );
  }
}
