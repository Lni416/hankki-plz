import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../models/mock_data.dart';
import '../services/firestore_service.dart';
import 'fridge_provider.dart';
import 'auth_provider.dart';

final selectedDifficultyProvider = StateProvider<int?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Firestore에서 모든 레시피 로드 (또는 Firebase 미설정 시 목 데이터)
final allRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  if (!ref.read(firebaseAvailableProvider)) {
    return mockRecipes;
  }
  // 새로고침 시 auth 복원 전에 Firestore에 접근하면 권한 오류가 발생하므로
  // authStateProvider가 로딩 중이면 완료될 때까지 대기 (watch → 자동 재실행)
  final authAsync = ref.watch(authStateProvider);
  if (authAsync.isLoading) return [];
  if (authAsync.value == null) return mockRecipes;
  try {
    final recipes = await FirestoreService.getAllRecipes();
    // Firestore가 비어 있으면(시드 전) 목 데이터로 폴백 — 빈 화면 방지
    return recipes.isEmpty ? mockRecipes : recipes;
  } catch (_) {
    return mockRecipes; // Firestore 오류 시 목 데이터 폴백
  }
});

/// 냉장고 재료 기반으로 점수 계산 후 정렬된 레시피 목록
final recommendedRecipesProvider = Provider<List<Recipe>>((ref) {
  final fridge = ref.watch(fridgeProvider).valueOrNull ?? [];
  final allRecipesAsync = ref.watch(allRecipesProvider);
  final allRecipes = allRecipesAsync.valueOrNull ?? mockRecipes;
  final selectedDiff = ref.watch(selectedDifficultyProvider);
  final query = ref.watch(searchQueryProvider);

  final fridgeNames = fridge.map((i) => i.name.toLowerCase()).toSet();
  final urgentNames = fridge
      .where((i) => i.isUrgent)
      .map((i) => i.name.toLowerCase())
      .toSet();

  // 사용자 레벨 기반 난이도 선호도 계산
  // (learnProvider 순환참조 방지 위해 별도 provider로 분리)

  final scored = allRecipes.map((recipe) {
    final requiredIngredients =
        recipe.ingredients.where((i) => !i.isOptional).toList();
    final total = requiredIngredients.length;

    final matched = requiredIngredients.where((ri) {
      final riName = ri.name.toLowerCase();
      return fridgeNames.any(
          (fn) => fn.contains(riName) || riName.contains(fn));
    }).length;

    final hasUrgent = recipe.ingredients.any((ri) {
      final riName = ri.name.toLowerCase();
      return urgentNames.any(
          (un) => un.contains(riName) || riName.contains(un));
    });

    final matchRate = total > 0 ? matched / total : 0.0;

    return recipe.copyWith(
      matchRate: matchRate,
      hasUrgentIngredient: hasUrgent,
    );
  }).toList();

  var filtered = scored;

  if (selectedDiff != null) {
    filtered = filtered.where((r) => r.difficulty == selectedDiff).toList();
  }

  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    filtered = filtered.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q)) ||
          r.ingredients
              .any((i) => i.name.toLowerCase().contains(q));
    }).toList();
  }

  filtered.sort((a, b) {
    // 1순위: 유통기한 임박 재료 사용 레시피
    if (a.hasUrgentIngredient != b.hasUrgentIngredient) {
      return a.hasUrgentIngredient ? -1 : 1;
    }
    // 2순위: 보유 재료 매칭률 높은 순
    final byMatch = b.matchRate.compareTo(a.matchRate);
    if (byMatch != 0) return byMatch;
    // 3순위: 매칭률이 같으면 쉬운 난이도 먼저 (입문자 우선)
    return a.difficulty.compareTo(b.difficulty);
  });

  return filtered;
});

/// 홈 화면 '오늘의 추천'에 노출할 최대 10개 추천 레시피
final topRecommendationsProvider = Provider<List<Recipe>>((ref) {
  final recommended = ref.watch(recommendedRecipesProvider);
  return recommended.take(10).toList();
});

final selectedRecipeProvider = StateProvider<Recipe?>((ref) => null);
