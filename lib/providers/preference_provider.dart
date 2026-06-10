import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import 'favorite_provider.dart';
import 'history_provider.dart';
import 'recipe_provider.dart';

/// 사용자 취향 프로필 — 찜·요리 히스토리 기반 카테고리/태그 가중치
class UserPreference {
  final Map<String, double> categoryWeight; // '한식' 등, 0~1 정규화
  final Map<String, double> tagWeight; // '볶음', '한그릇' 등, 0~1 정규화
  final int signalCount; // 찜 + 히스토리 건수

  const UserPreference({
    this.categoryWeight = const {},
    this.tagWeight = const {},
    this.signalCount = 0,
  });

  static const empty = UserPreference();

  /// 레시피에 대한 개인화 점수 (0~1)
  double scoreFor(Recipe recipe) {
    if (signalCount < 3) return 0.0; // 콜드 스타트 — 데이터 부족 시 미적용
    final catScore = categoryWeight[recipe.category] ?? 0.0;
    double tagScore = 0.0;
    if (recipe.tags.isNotEmpty) {
      final sum = recipe.tags
          .map((t) => tagWeight[t] ?? 0.0)
          .fold(0.0, (a, b) => a + b);
      tagScore = sum / recipe.tags.length;
    }
    return catScore * 0.6 + tagScore * 0.4;
  }
}

/// 찜(가중치 2.0) + 완료 히스토리(가중치 1.0)를 집계해 취향 프로필 생성.
/// FavoriteRecipe/CookingHistoryEntry에는 recipeId만 있으므로
/// allRecipes와 조인해 category/tags를 가져온다.
final userPreferenceProvider = Provider<UserPreference>((ref) {
  final favorites = ref.watch(favoritesProvider).valueOrNull ?? [];
  final history = ref.watch(historyProvider).valueOrNull ?? [];
  final allRecipes = ref.watch(allRecipesProvider).valueOrNull ?? [];

  if (allRecipes.isEmpty) return UserPreference.empty;

  final recipeById = {for (final r in allRecipes) r.id: r};

  final categoryScore = <String, double>{};
  final tagScore = <String, double>{};
  var signals = 0;

  void accumulate(String recipeId, double weight) {
    final recipe = recipeById[recipeId];
    if (recipe == null) return;
    signals++;
    categoryScore.update(recipe.category, (v) => v + weight,
        ifAbsent: () => weight);
    for (final tag in recipe.tags) {
      tagScore.update(tag, (v) => v + weight, ifAbsent: () => weight);
    }
  }

  for (final f in favorites) {
    accumulate(f.recipeId, 2.0);
  }
  for (final h in history) {
    accumulate(h.recipeId, 1.0); // 반복 완료는 자연스럽게 누적
  }

  if (signals == 0) return UserPreference.empty;

  // max 정규화 → 0~1
  Map<String, double> normalize(Map<String, double> m) {
    if (m.isEmpty) return const {};
    final maxV = m.values.reduce((a, b) => a > b ? a : b);
    if (maxV <= 0) return const {};
    return m.map((k, v) => MapEntry(k, v / maxV));
  }

  return UserPreference(
    categoryWeight: normalize(categoryScore),
    tagWeight: normalize(tagScore),
    signalCount: signals,
  );
});
