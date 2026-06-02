import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/recipe_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('찜한 레시피 ❤️'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (favorites) {
          if (favorites.isEmpty) {
            return _buildEmpty();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: favorites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final fav = favorites[i];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Text(fav.emoji, style: emojiStyle(32)),
                  title: Text(
                    fav.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: AppColors.danger),
                    onPressed: () => ref
                        .read(favoritesProvider.notifier)
                        .toggle(fav.recipeId, fav.title, fav.emoji),
                  ),
                  onTap: () {
                    final List<Recipe> recipes =
                        ref.read(allRecipesProvider).valueOrNull ??
                            ref.read(recommendedRecipesProvider);
                    final match = recipes
                        .where((r) => r.id == fav.recipeId)
                        .toList();
                    if (match.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('레시피 정보를 찾을 수 없어요')),
                      );
                      return;
                    }
                    ref.read(selectedRecipeProvider.notifier).state =
                        match.first;
                    context.go('/recipe/detail');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('🤍', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text(
            '아직 찜한 레시피가 없어요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '레시피 상세 화면에서 ♥를 눌러 저장해 보세요',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
