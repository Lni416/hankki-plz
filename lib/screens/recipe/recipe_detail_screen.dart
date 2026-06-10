import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/fridge_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../widgets/difficulty_stars.dart';
import '../learn/lesson_screen.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = ref.watch(selectedRecipeProvider);
    if (recipe == null) {
      // 새로고침 후 selectedRecipeProvider가 초기화된 경우 — 레시피 목록으로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/recipe');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final fridge = ref.watch(fridgeProvider).valueOrNull ?? [];
    final fridgeNames = fridge.map((i) => i.name.toLowerCase()).toSet();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildSliverHeader(context, recipe),
        ],
        body: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: '재료'),
                Tab(text: '조리법'),
                Tab(text: '영양정보'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIngredientsTab(recipe, fridgeNames),
                  _buildStepsTab(recipe),
                  _buildNutritionTab(recipe),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildStartCookingBar(context, recipe),
    );
  }

  SliverAppBar _buildSliverHeader(BuildContext context, Recipe recipe) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new),
        onPressed: () => context.go('/recipe'),
      ),
      actions: [
        Consumer(
          builder: (context, ref, _) {
            final isFav = ref.watch(favoritesProvider).maybeWhen(
                  data: (favs) =>
                      favs.any((f) => f.recipeId == recipe.id),
                  orElse: () => false,
                );
            return IconButton(
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? AppColors.danger : null,
              ),
              onPressed: () {
                ref.read(favoritesProvider.notifier).toggle(
                      recipe.id,
                      recipe.title,
                      recipe.emoji,
                    );
              },
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppColors.cardBg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(recipe.emoji, style: emojiStyle(72)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  recipe.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              DifficultyStars(difficulty: recipe.difficulty, size: 16),
              const SizedBox(width: 6),
              Text(
                recipe.difficultyLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.timer_outlined,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                '${recipe.cookingTimeMinutes}분',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.people_outline,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                '${recipe.servings}인분',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  recipe.totalRequired == 0
                      ? '재료 정보 없음'
                      : recipe.matchedCount >= recipe.totalRequired
                          ? '재료 다 있어요!'
                          : '${recipe.totalRequired}개 중 ${recipe.matchedCount}개 보유',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientsTab(Recipe recipe, Set<String> fridgeNames) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (recipe.missingIngredients.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '부족한 재료: ${recipe.missingIngredients.join(', ')}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A6D00),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          '필수 재료',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        ...recipe.ingredients
            .where((i) => !i.isOptional)
            .toList()
            .asMap()
            .entries
            .map((e) => _IngredientRow(
                  ri: e.value,
                  index: e.key,
                  owned: fridgeNames.any((fn) =>
                      fn.contains(e.value.name.toLowerCase()) ||
                      e.value.name.toLowerCase().contains(fn)),
                )),
        if (recipe.ingredients.any((i) => i.isOptional)) ...[
          const SizedBox(height: 16),
          const Text(
            '선택 재료',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ...recipe.ingredients
              .where((i) => i.isOptional)
              .map((ri) => _IngredientRow(
                    ri: ri,
                    index: 0,
                    owned: fridgeNames.any((fn) =>
                        fn.contains(ri.name.toLowerCase()) ||
                        ri.name.toLowerCase().contains(fn)),
                  )),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '없는 재료는 할인 알림을 설정하면 저렴할 때 알려드려요!',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepsTab(Recipe recipe) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: recipe.steps.length,
      itemBuilder: (context, i) {
        final step = recipe.steps[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${step.order}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.description,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                    if (step.tip != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.streakGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Text('💡',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                step.tip!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7B5800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (step.duration != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 13, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            '약 ${step.duration!.inMinutes}분',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: Duration(milliseconds: 60 * i)).fadeIn().slideX();
      },
    );
  }

  Widget _buildNutritionTab(Recipe recipe) {
    final n = recipe.nutrition;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                '${n.calories}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'kcal / 1인분',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _NutritionCard(
              label: '탄수화물',
              value: n.carbs,
              unit: 'g',
              color: const Color(0xFF2196F3),
              emoji: '🍚',
            ),
            const SizedBox(width: 12),
            _NutritionCard(
              label: '단백질',
              value: n.protein,
              unit: 'g',
              color: const Color(0xFF4CAF50),
              emoji: '🥩',
            ),
            const SizedBox(width: 12),
            _NutritionCard(
              label: '지방',
              value: n.fat,
              unit: 'g',
              color: const Color(0xFFFF9800),
              emoji: '🫒',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _NutritionBar('탄수화물', n.carbs, 300, const Color(0xFF2196F3)),
        const SizedBox(height: 10),
        _NutritionBar('단백질', n.protein, 60, const Color(0xFF4CAF50)),
        const SizedBox(height: 10),
        _NutritionBar('지방', n.fat, 65, const Color(0xFFFF9800)),
        const SizedBox(height: 8),
        const Text(
          '* 일일 권장 섭취량 대비 비율',
          style: TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildStartCookingBar(BuildContext context, Recipe recipe) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LessonScreen(),
                  ),
                );
              },
              icon: const Text('👨‍🍳', style: TextStyle(fontSize: 18)),
              label: const Text('요리 시작하기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final RecipeIngredient ri;
  final int index;
  final bool owned;

  const _IngredientRow({
    required this.ri,
    required this.index,
    required this.owned,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: owned
              ? AppColors.secondary.withOpacity(0.06)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: owned
                ? AppColors.secondary.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              owned ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: owned ? AppColors.secondary : AppColors.textHint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ri.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: owned
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '${ri.amount.toStringAsFixed(ri.amount == ri.amount.roundToDouble() ? 0 : 1)} ${ri.unit}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 40 * index)).fadeIn();
  }
}

class _NutritionCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final String emoji;

  const _NutritionCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionBar extends StatelessWidget {
  final String label;
  final double value;
  final double recommended;
  final Color color;

  const _NutritionBar(this.label, this.value, this.recommended, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = (value / recommended * 100).round();
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (value / recommended).clamp(0.0, 1.0),
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
