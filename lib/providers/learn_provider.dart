import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learn_card.dart';
import '../models/mock_data.dart';
import '../models/recipe.dart';
import '../models/user_stats.dart';
import '../providers/recipe_provider.dart';
import '../services/cloud_functions_service.dart';
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

      // 요리 히스토리 기록 (선택된 레시피 기준)
      final recipe = ref.read(selectedRecipeProvider);
      if (recipe != null) {
        try {
          await FirestoreService.addHistory(
            uid,
            recipe.id,
            recipe.title,
            recipe.emoji,
            xpEarned,
          );
        } catch (_) {}
      }
    }
  }
}

final learnProvider =
    AsyncNotifierProvider<LearnNotifier, UserStats>(LearnNotifier.new);

/// 선택된 레시피의 학습카드 — 조리 순서대로 동적 생성
///
/// 구성: [재료 소개] → [조리 단계 ×N] → [퀴즈 (Firestore)] → [팁 (Firestore)]
/// Firestore 퀴즈·팁이 없으면 완성 카드로 대체.
final currentLessonCardsProvider = FutureProvider<List<LearnCard>>((ref) async {
  final recipe = ref.watch(selectedRecipeProvider);

  // 레시피가 없으면 mock 카드 반환
  if (recipe == null) return mockLearnCards;

  final cards = <LearnCard>[];

  // 1. 재료 소개 카드
  cards.add(_buildIntroCard(recipe));

  // 2. 조리 단계별 카드 (레시피 steps 순서대로)
  for (final step in recipe.steps) {
    cards.add(_buildStepCard(step, recipe.emoji));
  }

  // 3. 퀴즈·팁: Firestore lessonCards에서 가져오기
  if (ref.read(firebaseAvailableProvider)) {
    try {
      var lessonCards = await FirestoreService.getLessonCards(recipe.id);

      // Firestore에 카드가 없으면 Cloud Function으로 생성 후 재조회
      if (lessonCards.isEmpty) {
        try {
          await CloudFunctionsService.generateLessonCards(recipe.id);
          lessonCards = await FirestoreService.getLessonCards(recipe.id);
        } catch (_) {}
      }

      final quiz =
          lessonCards.where((c) => c.type == CardType.quiz).firstOrNull;
      final tip = lessonCards.where((c) => c.type == CardType.tip).firstOrNull;
      if (quiz != null) cards.add(quiz);
      if (tip != null) cards.add(tip);
    } catch (_) {}
  }

  // 4. 퀴즈·팁을 가져오지 못했으면 완성 카드 추가
  if (!cards.any((c) => c.type == CardType.quiz || c.type == CardType.tip)) {
    cards.add(LearnCard(
      id: 'complete',
      type: CardType.tip,
      title: '완성! 맛있게 드세요 🎉',
      content:
          '${recipe.title} 조리를 마쳤어요.\n직접 만든 음식이 제일 맛있습니다. 오늘도 수고했어요!',
      emoji: '🎉',
    ));
  }

  return cards;
});

/// 재료 소개 카드 생성
LearnCard _buildIntroCard(Recipe recipe) {
  final required = recipe.ingredients
      .where((i) => !i.isOptional)
      .map((i) {
        final amt = i.amount == i.amount.roundToDouble()
            ? i.amount.toInt().toString()
            : i.amount.toString();
        return '${i.name} $amt${i.unit}';
      })
      .join(' · ');

  final optional = recipe.ingredients.where((i) => i.isOptional).toList();
  final optionalText =
      optional.isEmpty ? '' : '\n선택 재료: ${optional.map((i) => i.name).join(', ')}';

  return LearnCard(
    id: 'intro',
    type: CardType.intro,
    title: '${recipe.title}, 시작해볼까요?',
    content:
        '⏱ ${recipe.cookingTimeMinutes}분  |  🍽 ${recipe.servings}인분\n\n필수 재료: $required$optionalText',
    emoji: recipe.emoji,
  );
}

/// 조리 단계 카드 생성
LearnCard _buildStepCard(RecipeStep step, String recipeEmoji) {
  return LearnCard(
    id: 'step_${step.order}',
    type: CardType.step,
    title: '${step.order}단계',
    content: step.description,
    emoji: recipeEmoji,
    tip: step.tip,
    stepNumber: step.order,
  );
}

final lessonProgressProvider = StateProvider<int>((ref) => 0);
final quizAnswerProvider = StateProvider<int?>((ref) => null);
