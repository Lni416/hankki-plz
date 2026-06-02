import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_models.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

class FavoriteNotifier extends StreamNotifier<List<FavoriteRecipe>> {
  @override
  Stream<List<FavoriteRecipe>> build() {
    if (!ref.read(firebaseAvailableProvider)) {
      return Stream.value(const []);
    }

    final authAsync = ref.watch(authStateProvider);

    // auth 복원 중이면 빈 리스트 대신 로딩 유지
    if (authAsync.isLoading) {
      final controller = StreamController<List<FavoriteRecipe>>();
      ref.onDispose(controller.close);
      return controller.stream;
    }

    final uid = authAsync.value?.uid;
    if (uid == null) return Stream.value(const []);
    return FirestoreService.streamFavorites(uid);
  }

  bool isFavorite(String recipeId) {
    return (state.valueOrNull ?? const [])
        .any((f) => f.recipeId == recipeId);
  }

  Future<void> toggle(String recipeId, String title, String emoji) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || !ref.read(firebaseAvailableProvider)) return;
    if (isFavorite(recipeId)) {
      await FirestoreService.removeFavorite(uid, recipeId);
    } else {
      await FirestoreService.addFavorite(uid, recipeId, title, emoji);
    }
  }
}

final favoritesProvider =
    StreamNotifierProvider<FavoriteNotifier, List<FavoriteRecipe>>(
        FavoriteNotifier.new);
