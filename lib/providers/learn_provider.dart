import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learn_card.dart';
import '../models/mock_data.dart';
import '../models/user_stats.dart';
import '../providers/recipe_provider.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

export '../models/user_stats.dart';

class LearnNotifier extends AsyncNotifier<UserStats> {
  @override
  Future<UserStats> build() async {
    if (!ref.read(firebaseAvailableProvider)) {
      return const UserStats(streak: 3, xp: 420, level: 2);
    }
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return const UserStats();
    }
    return await FirestoreService.getUserStats(uid);
  }

  Future<void> completeLesson(int xpEarned) async {
    final current = state.valueOrNull ?? const UserStats();
    final now = DateTime.now();
    final newXp = current.xp + xpEarned;
    final newLevel = (newXp / 300).floor() + 1;

    // 스트릭 계산
    int newStreak = current.streak;
    if (current.lastStudyDate == null) {
      newStreak = 1;
    } else {
      final lastDate = DateTime(
        current.lastStudyDate!.year,
        current.lastStudyDate!.month,
        current.lastStudyDate!.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(lastDate).inDays;
      if (diff == 0) {
        // 오늘 이미 학습함 — 스트릭 유지
      } else if (diff == 1) {
        newStreak = current.streak + 1;
      } else {
        newStreak = 1; // 하루 이상 끊기면 리셋
      }
    }

    // 주간 XP 업데이트 (0=월, 6=일)
    final weekday = now.weekday - 1; // 0-based
    final newWeeklyXp = List<int>.from(current.weeklyXp);
    newWeeklyXp[weekday] = (newWeeklyXp[weekday]) + xpEarned;

    final newStats = current.copyWith(
      xp: newXp,
      level: newLevel,
      streak: newStreak,
      todayLessons: current.todayLessons + 1,
      todayCompleted: true,
      lastStudyDate: now,
      weeklyXp: newWeeklyXp,
    );

    state = AsyncData(newStats);

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null && ref.read(firebaseAvailableProvider)) {
      await FirestoreService.updateUserStats(uid, newStats);
    }
  }
}

final learnProvider =
    AsyncNotifierProvider<LearnNotifier, UserStats>(LearnNotifier.new);

/// 선택된 레시피의 학습카드 — Firestore 우선, 없으면 목 데이터
final currentLessonCardsProvider = FutureProvider<List<LearnCard>>((ref) async {
  if (!ref.read(firebaseAvailableProvider)) {
    return mockLearnCards;
  }
  final recipe = ref.watch(selectedRecipeProvider);
  if (recipe == null) return mockLearnCards;

  try {
    final cards = await FirestoreService.getLessonCards(recipe.id);
    return cards.isEmpty ? mockLearnCards : cards;
  } catch (_) {
    return mockLearnCards;
  }
});

final lessonProgressProvider = StateProvider<int>((ref) => 0);
final quizAnswerProvider = StateProvider<int?>((ref) => null);
