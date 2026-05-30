import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_stats.dart';
import '../../providers/learn_provider.dart';
import '../../widgets/streak_badge.dart';
import 'lesson_screen.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(learnProvider);
    final stats = statsAsync.valueOrNull ?? const UserStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 📚'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: statsAsync.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : StreakBadge(streak: stats.streak),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildLevelCard(stats),
          const SizedBox(height: 20),
          _buildDailyLesson(context, stats),
          const SizedBox(height: 20),
          _buildWeeklyQuests(stats),
          const SizedBox(height: 20),
          _buildBadges(stats),
        ],
      ),
    );
  }

  Widget _buildLevelCard(UserStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Lv.${stats.level}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                stats.levelTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.levelProgress.clamp(0.0, 1.0),
              backgroundColor: Colors.white30,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${stats.xp} XP',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '다음 레벨까지 ${stats.xpToNextLevel} XP',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1);
  }

  Widget _buildDailyLesson(BuildContext context, UserStats stats) {
    return GestureDetector(
      onTap: () {
        if (!stats.todayCompleted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LessonScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: stats.todayCompleted
              ? AppColors.secondary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: stats.todayCompleted
                ? AppColors.secondary.withOpacity(0.3)
                : AppColors.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: stats.todayCompleted
                    ? AppColors.secondary.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  stats.todayCompleted ? '✅' : '🍳',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.todayCompleted ? '오늘 학습 완료!' : '오늘의 레슨',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats.todayCompleted
                        ? '훌륭해요! 내일도 이어가요 🔥'
                        : '계란볶음밥 완성하기 · 카드 5장 · +50 XP',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!stats.todayCompleted)
              const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildWeeklyQuests(UserStats stats) {
    final quests = [
      _Quest('오늘 레슨 완료하기', stats.todayLessons.clamp(0, 1), 1, '📚'),
      _Quest('XP 50 모으기', stats.xp.clamp(0, 50), 50, '🌟'),
      _Quest('5일 연속 학습', stats.streak.clamp(0, 5), 5, '🔥'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주간 퀘스트',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...quests.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuestTile(quest: e.value, index: e.key),
              ),
            ),
      ],
    );
  }

  Widget _buildBadges(UserStats stats) {
    final badges = [
      ('⭐', '첫 레슨', stats.xp > 0),
      ('🔥', '3일 스트릭', stats.streak >= 3),
      ('💪', '7일 스트릭', stats.streak >= 7),
      ('🌱', 'XP 100 달성', stats.xp >= 100),
      ('🍳', '레벨 2', stats.level >= 2),
      ('👨‍🍳', '입문 요리사', stats.level >= 3),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '획득한 뱃지',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: badges.map((b) {
            return Container(
              width: 80,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: b.$3 ? AppColors.surface : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: b.$3
                      ? AppColors.streakGold.withOpacity(0.5)
                      : AppColors.divider,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    b.$1,
                    style: TextStyle(
                      fontSize: 28,
                      color: b.$3 ? null : const Color(0xFFCCCCCC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: b.$3
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Quest {
  final String title;
  final int current;
  final int total;
  final String emoji;
  const _Quest(this.title, this.current, this.total, this.emoji);
}

class _QuestTile extends StatelessWidget {
  final _Quest quest;
  final int index;

  const _QuestTile({required this.quest, required this.index});

  @override
  Widget build(BuildContext context) {
    final done = quest.current >= quest.total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? AppColors.secondary.withOpacity(0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? AppColors.secondary.withOpacity(0.3)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Text(quest.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: quest.current / quest.total,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            done ? AppColors.secondary : AppColors.primary,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${quest.current}/${quest.total}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: done
                            ? AppColors.secondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (done) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: AppColors.secondary, size: 22),
          ],
        ],
      ),
    ).animate(delay: Duration(milliseconds: 60 * index)).fadeIn().slideX();
  }
}
