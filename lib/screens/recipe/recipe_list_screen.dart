import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/difficulty_stars.dart';
import '../../widgets/match_rate_bar.dart';

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recommendedRecipesProvider);
    final selectedDiff = ref.watch(selectedDifficultyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('레시피 추천 🍳'),
      ),
      body: Column(
        children: [
          _buildSearchBar(ref),
          _buildDifficultyFilter(ref, selectedDiff),
          Expanded(
            child: recipes.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: recipes.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecipeListCard(
                        recipe: recipes[i],
                        index: i,
                        onTap: () {
                          ref.read(selectedRecipeProvider.notifier).state =
                              recipes[i];
                          context.go('/recipe/detail');
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        decoration: const InputDecoration(
          hintText: '요리 이름 또는 재료로 검색',
          prefixIcon: Icon(Icons.search, color: AppColors.textHint),
        ),
        onChanged: (v) =>
            ref.read(searchQueryProvider.notifier).state = v,
      ),
    );
  }

  Widget _buildDifficultyFilter(WidgetRef ref, int? selected) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          _FilterChip(
            label: '전체',
            selected: selected == null,
            onTap: () =>
                ref.read(selectedDifficultyProvider.notifier).state = null,
          ),
          ...List.generate(5, (i) => _FilterChip(
                label: '★' * (i + 1),
                selected: selected == i + 1,
                onTap: () => ref
                    .read(selectedDifficultyProvider.notifier)
                    .state = i + 1,
              )),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🤔', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('조건에 맞는 레시피가 없어요',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeListCard extends StatelessWidget {
  final dynamic recipe;
  final int index;
  final VoidCallback onTap;

  const _RecipeListCard({
    required this.recipe,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: recipe.hasUrgentIngredient
                ? AppColors.warning.withOpacity(0.5)
                : AppColors.divider,
            width: recipe.hasUrgentIngredient ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(recipe.emoji,
                    style: emojiStyle(36)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (recipe.hasUrgentIngredient)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '⚠️ 임박',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DifficultyStars(difficulty: recipe.difficulty),
                      const SizedBox(width: 8),
                      Text(
                        recipe.difficultyLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.timer_outlined,
                          size: 13, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.cookingTimeMinutes}분',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('보유 재료 ',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textHint)),
                      Expanded(
                        child: MatchRateBar(
                          matched: recipe.matchedCount,
                          total: recipe.totalRequired,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn()
        .slideY(begin: 0.05);
  }
}
