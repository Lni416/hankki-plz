import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/learn_card.dart';
import '../models/user_stats.dart';
import '../models/profile_models.dart';

class FirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── 냉장고 재료 ──────────────────────────────────────────────────────────

  static Stream<List<Ingredient>> streamIngredients(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('ingredients')
        .orderBy('addedAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Ingredient.fromFirestore(d)).toList());
  }

  static Future<void> addIngredient(String uid, Ingredient ingredient) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('ingredients')
        .doc(ingredient.id)
        .set(ingredient.toMap());
  }

  static Future<void> removeIngredient(String uid, String id) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('ingredients')
        .doc(id)
        .delete();
  }

  static Future<void> updateIngredientQuantity(
      String uid, String id, double quantity) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('ingredients')
        .doc(id)
        .update({'quantity': quantity});
  }

  // ── 레시피 ───────────────────────────────────────────────────────────────

  static Future<List<Recipe>> getAllRecipes() async {
    final snap = await _db.collection('recipes').get();
    return snap.docs.map((d) => Recipe.fromFirestore(d)).toList();
  }

  static Future<void> cacheRecipe(Recipe recipe) async {
    await _db
        .collection('recipes')
        .doc(recipe.id)
        .set({...recipe.toMap(), 'cachedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
  }

  // ── 학습 카드 ──────────────────────────────────────────────────────────────

  static Future<List<LearnCard>> getLessonCards(String recipeId) async {
    final snap = await _db
        .collection('recipes')
        .doc(recipeId)
        .collection('lessonCards')
        .orderBy('order')
        .get();
    return snap.docs.map((d) => LearnCard.fromFirestore(d)).toList();
  }

  // ── 사용자 통계 ────────────────────────────────────────────────────────────

  static Future<UserStats> getUserStats(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return const UserStats();
    }
    return UserStats.fromFirestore(doc);
  }

  static Future<void> updateUserStats(String uid, UserStats stats) async {
    await _db
        .collection('users')
        .doc(uid)
        .set(stats.toMap(), SetOptions(merge: true));
  }

  // ── 찜한 레시피 ───────────────────────────────────────────────────────────

  static Stream<List<FavoriteRecipe>> streamFavorites(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FavoriteRecipe.fromFirestore(d)).toList());
  }

  static Future<void> addFavorite(
      String uid, String recipeId, String title, String emoji) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(recipeId)
        .set({
      'recipeId': recipeId,
      'title': title,
      'emoji': emoji,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> removeFavorite(String uid, String recipeId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(recipeId)
        .delete();
  }

  // ── 요리 히스토리 ─────────────────────────────────────────────────────────

  static Stream<List<CookingHistoryEntry>> streamHistory(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('history')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CookingHistoryEntry.fromFirestore(d)).toList());
  }

  static Future<void> addHistory(
      String uid, String recipeId, String title, String emoji, int xpEarned) async {
    await _db.collection('users').doc(uid).collection('history').add({
      'recipeId': recipeId,
      'title': title,
      'emoji': emoji,
      'xpEarned': xpEarned,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 알림 내역 ─────────────────────────────────────────────────────────────

  static Stream<List<AppNotification>> streamNotifications(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppNotification.fromFirestore(d)).toList());
  }

  // ── 추천 이력 ─────────────────────────────────────────────────────────────

  static Future<Set<String>> getRecommendedRecipeIds(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('recommendedRecipes')
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  static Future<void> saveRecommendation(
      String uid, String recipeId, double matchRate) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('recommendedRecipes')
        .doc(recipeId)
        .set({
      'matchRate': matchRate,
      'recommendedAt': FieldValue.serverTimestamp(),
      'completed': false,
    }, SetOptions(merge: true));
  }
}
