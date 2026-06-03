import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // 로고 영역
              Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('👨‍🍳', style: TextStyle(fontSize: 52)),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: 28),
              const Text(
                '한끼를 부탁해',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 10),
              const Text(
                '냉장고 재료로 오늘 뭐 해먹지?\n매일 조금씩, 맛있게 요리를 배워요 🍳',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ).animate().fadeIn(delay: 250.ms),
              const Spacer(flex: 2),
              // 기능 소개
              _FeatureRow(
                emoji: '🧊',
                title: '냉장고 관리',
                desc: '재료 등록 · 유통기한 D-day 알림',
              ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.1),
              const SizedBox(height: 14),
              _FeatureRow(
                emoji: '🍽️',
                title: '레시피 추천',
                desc: '보유 재료 매칭률 기반 맞춤 추천',
              ).animate().fadeIn(delay: 430.ms).slideX(begin: -0.1),
              const SizedBox(height: 14),
              _FeatureRow(
                emoji: '📚',
                title: '요리 학습',
                desc: '듀오링고 스타일 · XP · 스트릭',
              ).animate().fadeIn(delay: 510.ms).slideX(begin: -0.1),
              const Spacer(flex: 3),
              // 로그인 버튼
              if (authAsync.isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(authNotifierProvider.notifier)
                        .signInWithGoogle(),
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    label: const Text(
                      'Google로 계속하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(
                        color: AppColors.divider,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(authNotifierProvider.notifier)
                        .signInAnonymously(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '로그인 없이 둘러보기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 660.ms).slideY(begin: 0.1),
              ],
              if (authAsync.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  '로그인 실패: ${authAsync.error}',
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;

  const _FeatureRow({
    required this.emoji,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
