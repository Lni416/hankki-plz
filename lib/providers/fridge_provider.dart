import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient.dart';
import '../models/mock_data.dart';

class FridgeNotifier extends StateNotifier<List<Ingredient>> {
  FridgeNotifier() : super(mockIngredients);

  void addIngredient(Ingredient ingredient) {
    state = [...state, ingredient];
  }

  void removeIngredient(String id) {
    state = state.where((i) => i.id != id).toList();
  }

  void updateQuantity(String id, double quantity) {
    state = state.map((i) {
      if (i.id == id) return i.copyWith(quantity: quantity);
      return i;
    }).toList();
  }

  List<Ingredient> get urgentIngredients =>
      state.where((i) => i.isUrgent && !i.isExpired).toList();

  List<Ingredient> get expiredIngredients =>
      state.where((i) => i.isExpired).toList();

  List<Ingredient> get byCategory =>
      [...state]..sort((a, b) => a.category.index.compareTo(b.category.index));
}

final fridgeProvider =
    StateNotifierProvider<FridgeNotifier, List<Ingredient>>(
  (ref) => FridgeNotifier(),
);

final urgentIngredientsProvider = Provider<List<Ingredient>>((ref) {
  return ref.watch(fridgeProvider.notifier).urgentIngredients;
});
