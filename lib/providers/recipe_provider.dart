import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../models/mock_data.dart';
import 'fridge_provider.dart';

final selectedDifficultyProvider = StateProvider<int?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

final recommendedRecipesProvider = Provider<List<Recipe>>((ref) {
  final fridge = ref.watch(fridgeProvider);
  final selectedDiff = ref.watch(selectedDifficultyProvider);
  final query = ref.watch(searchQueryProvider);

  final fridgeNames = fridge.map((i) => i.name.toLowerCase()).toSet();
  final urgentNames =
      fridge.where((i) => i.isUrgent).map((i) => i.name.toLowerCase()).toSet();

  final scored = mockRecipes.map((recipe) {
    final total = recipe.ingredients.where((i) => !i.isOptional).length;
    final matched = recipe.ingredients
        .where((ri) => !ri.isOptional &&
            fridgeNames.any((fn) => fn.contains(ri.name.toLowerCase()) ||
                ri.name.toLowerCase().contains(fn)))
        .length;
    final hasUrgent = recipe.ingredients.any((ri) =>
        urgentNames.any((un) => un.contains(ri.name.toLowerCase()) ||
            ri.name.toLowerCase().contains(un)));

    recipe.matchRate = total > 0 ? matched / total : 0;
    recipe.hasUrgentIngredient = hasUrgent;
    return recipe;
  }).toList();

  var filtered = scored;

  if (selectedDiff != null) {
    filtered = filtered.where((r) => r.difficulty == selectedDiff).toList();
  }

  if (query.isNotEmpty) {
    filtered = filtered
        .where((r) =>
            r.title.toLowerCase().contains(query.toLowerCase()) ||
            r.tags.any((t) => t.contains(query.toLowerCase())))
        .toList();
  }

  filtered.sort((a, b) {
    if (a.hasUrgentIngredient != b.hasUrgentIngredient) {
      return a.hasUrgentIngredient ? -1 : 1;
    }
    return b.matchRate.compareTo(a.matchRate);
  });

  return filtered;
});

final selectedRecipeProvider = StateProvider<Recipe?>((ref) => null);
