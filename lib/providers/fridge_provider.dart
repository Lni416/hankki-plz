import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ingredient.dart';
import '../models/mock_data.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

class FridgeNotifier extends StreamNotifier<List<Ingredient>> {
  @override
  Stream<List<Ingredient>> build() {
    final firebaseAvailable = ref.read(firebaseAvailableProvider);
    if (!firebaseAvailable) {
      return Stream.value(mockIngredients);
    }

    final authAsync = ref.watch(authStateProvider);

    // auth가 복원 중이면 빈 리스트 대신 로딩 상태를 유지 (never-emitting stream)
    if (authAsync.isLoading) {
      final controller = StreamController<List<Ingredient>>();
      ref.onDispose(controller.close);
      return controller.stream;
    }

    final uid = authAsync.value?.uid;
    if (uid == null) {
      return Stream.value([]);
    }
    return FirestoreService.streamIngredients(uid);
  }

  Future<void> addIngredient(Ingredient ingredient) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || !ref.read(firebaseAvailableProvider)) {
      // 오프라인/비인증 시 낙관적 업데이트
      state = AsyncData([...state.valueOrNull ?? [], ingredient]);
      return;
    }
    await FirestoreService.addIngredient(uid, ingredient);
    // Firestore 스트림이 자동으로 상태를 갱신함
  }

  Future<void> removeIngredient(String id) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || !ref.read(firebaseAvailableProvider)) {
      state = AsyncData(
          (state.valueOrNull ?? []).where((i) => i.id != id).toList());
      return;
    }
    await FirestoreService.removeIngredient(uid, id);
  }

  Future<void> updateQuantity(String id, double quantity) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || !ref.read(firebaseAvailableProvider)) {
      state = AsyncData((state.valueOrNull ?? []).map((i) {
        if (i.id == id) return i.copyWith(quantity: quantity);
        return i;
      }).toList());
      return;
    }
    await FirestoreService.updateIngredientQuantity(uid, id, quantity);
  }
}

final fridgeProvider =
    StreamNotifierProvider<FridgeNotifier, List<Ingredient>>(FridgeNotifier.new);

final urgentIngredientsProvider = Provider<List<Ingredient>>((ref) {
  final ingredients = ref.watch(fridgeProvider).valueOrNull ?? [];
  return ingredients.where((i) => i.isUrgent && !i.isExpired).toList();
});
