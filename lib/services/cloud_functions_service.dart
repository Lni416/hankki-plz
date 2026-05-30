import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';

/// Firebase Cloud Functions 호출 서비스
/// Firebase 미설정 시에는 목 응답 반환
class CloudFunctionsService {
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  // ── 재료 인식 ─────────────────────────────────────────────────────────────

  /// 이미지 파일을 Gemini Vision으로 분석해 재료 이름 목록 반환
  static Future<List<String>> recognizeIngredients(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final callable = _functions.httpsCallable('recognizeIngredients');
      final result = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64Image,
        'mimeType': 'image/jpeg',
      });

      final data = result.data;
      final ingredients = List<String>.from(data['ingredients'] as List? ?? []);
      return ingredients;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('재료 인식 실패: ${e.message}');
    }
  }

  // ── 레시피 추천 ───────────────────────────────────────────────────────────

  /// 사용자 재료 + 난이도 레벨로 추천 레시피 요청
  static Future<List<Map<String, dynamic>>> getRecommendedRecipes({
    required List<String> ingredientNames,
    required int difficultyLevel,
    required String uid,
  }) async {
    try {
      final callable = _functions.httpsCallable('getRecommendedRecipes');
      final result = await callable.call<Map<String, dynamic>>({
        'ingredients': ingredientNames,
        'difficultyLevel': difficultyLevel,
        'uid': uid,
      });

      final data = result.data;
      return List<Map<String, dynamic>>.from(
          (data['recipes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    } on FirebaseFunctionsException catch (e) {
      throw Exception('레시피 추천 실패: ${e.message}');
    }
  }

  // ── 학습카드 생성 ─────────────────────────────────────────────────────────

  /// 해당 레시피의 학습카드를 Gemini로 생성하도록 Cloud Function 요청.
  /// Function이 카드를 recipes/{recipeId}/lessonCards에 저장하므로,
  /// 호출 후 Firestore에서 다시 읽어오면 된다.
  static Future<void> generateLessonCards(String recipeId) async {
    try {
      final callable = _functions.httpsCallable('generateLessonCardsForRecipe');
      await callable.call<Map<String, dynamic>>({'recipeId': recipeId});
    } on FirebaseFunctionsException catch (e) {
      throw Exception('학습카드 생성 실패: ${e.message}');
    }
  }
}
