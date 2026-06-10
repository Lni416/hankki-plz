import 'package:cloud_firestore/cloud_firestore.dart';

/// 재료 중요도 — core: 이것만 있으면 OK / recommended: 있으면 더 좋음 / optional: 선택
enum IngredientImportance { core, recommended, optional }

class RecipeIngredient {
  final String name;
  final double amount;
  final String unit;
  final IngredientImportance importance;

  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.importance = IngredientImportance.core,
  });

  /// 하위호환 — 기존 코드의 isOptional 사용처 유지
  bool get isOptional => importance == IngredientImportance.optional;

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    // importance 문자열이 있으면 우선, 없으면 기존 isOptional 기반 (구문서 호환)
    final importanceStr = map['importance'] as String?;
    final IngredientImportance importance;
    if (importanceStr != null) {
      importance = IngredientImportance.values.firstWhere(
        (v) => v.name == importanceStr,
        orElse: () => IngredientImportance.core,
      );
    } else {
      importance = (map['isOptional'] as bool? ?? false)
          ? IngredientImportance.optional
          : IngredientImportance.core;
    }
    return RecipeIngredient(
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      unit: map['unit'] as String,
      importance: importance,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'importance': importance.name,
        'isOptional': isOptional, // 구버전 호환용 동시 기록
      };
}

class RecipeStep {
  final int order;
  final String description;
  final String? tip;
  final Duration? duration;

  const RecipeStep({
    required this.order,
    required this.description,
    this.tip,
    this.duration,
  });

  factory RecipeStep.fromMap(Map<String, dynamic> map) => RecipeStep(
        order: (map['order'] as num).toInt(),
        description: map['description'] as String,
        tip: map['tip'] as String?,
        duration: map['durationMinutes'] != null
            ? Duration(minutes: (map['durationMinutes'] as num).toInt())
            : null,
      );

  Map<String, dynamic> toMap() => {
        'order': order,
        'description': description,
        if (tip != null) 'tip': tip,
        if (duration != null) 'durationMinutes': duration!.inMinutes,
      };
}

class Nutrition {
  final int calories;
  final double carbs;
  final double protein;
  final double fat;

  const Nutrition({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  factory Nutrition.fromMap(Map<String, dynamic> map) => Nutrition(
        calories: (map['calories'] as num).toInt(),
        carbs: (map['carbs'] as num).toDouble(),
        protein: (map['protein'] as num).toDouble(),
        fat: (map['fat'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'calories': calories,
        'carbs': carbs,
        'protein': protein,
        'fat': fat,
      };
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final int difficulty;
  final int cookingTimeMinutes;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final Nutrition nutrition;
  final List<String> tags;
  final String emoji;
  final String category;
  final String? thumbnailUrl;

  // 보유 재료 기반 계산값 — 불변 필드, copyWith으로만 생성
  final double matchRate;
  final bool hasUrgentIngredient;
  final int matchedCount; // 보유 중인 필수재료 수
  final int totalRequired; // 전체 필수재료 수
  final List<String> missingIngredients; // 부족한 필수재료 이름

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.cookingTimeMinutes,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    required this.tags,
    required this.emoji,
    required this.category,
    this.thumbnailUrl,
    this.matchRate = 0.0,
    this.hasUrgentIngredient = false,
    this.matchedCount = 0,
    this.totalRequired = 0,
    this.missingIngredients = const [],
  });

  Recipe copyWith({
    double? matchRate,
    bool? hasUrgentIngredient,
    String? thumbnailUrl,
    int? matchedCount,
    int? totalRequired,
    List<String>? missingIngredients,
  }) =>
      Recipe(
        id: id,
        title: title,
        description: description,
        difficulty: difficulty,
        cookingTimeMinutes: cookingTimeMinutes,
        servings: servings,
        ingredients: ingredients,
        steps: steps,
        nutrition: nutrition,
        tags: tags,
        emoji: emoji,
        category: category,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        matchRate: matchRate ?? this.matchRate,
        hasUrgentIngredient: hasUrgentIngredient ?? this.hasUrgentIngredient,
        matchedCount: matchedCount ?? this.matchedCount,
        totalRequired: totalRequired ?? this.totalRequired,
        missingIngredients: missingIngredients ?? this.missingIngredients,
      );

  String get difficultyLabel {
    switch (difficulty) {
      case 1:
        return '매우 쉬움';
      case 2:
        return '쉬움';
      case 3:
        return '보통';
      case 4:
        return '어려움';
      case 5:
        return '매우 어려움';
      default:
        return '보통';
    }
  }

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      difficulty: (data['difficulty'] as num?)?.toInt() ?? 2,
      cookingTimeMinutes:
          (data['cookingTimeMinutes'] as num?)?.toInt() ?? 20,
      servings: (data['servings'] as num?)?.toInt() ?? 2,
      ingredients: (data['ingredients'] as List<dynamic>? ?? [])
          .map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
          .toList(),
      steps: (data['steps'] as List<dynamic>? ?? [])
          .map((e) => RecipeStep.fromMap(e as Map<String, dynamic>))
          .toList(),
      nutrition: data['nutrition'] != null
          ? Nutrition.fromMap(data['nutrition'] as Map<String, dynamic>)
          : const Nutrition(calories: 400, carbs: 50, protein: 20, fat: 15),
      tags: List<String>.from(data['tags'] as List? ?? []),
      emoji: data['emoji'] as String? ?? '🍽️',
      category: data['category'] as String? ?? '기타',
      thumbnailUrl: data['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'difficulty': difficulty,
        'cookingTimeMinutes': cookingTimeMinutes,
        'servings': servings,
        'ingredients': ingredients.map((i) => i.toMap()).toList(),
        'steps': steps.map((s) => s.toMap()).toList(),
        'nutrition': nutrition.toMap(),
        'tags': tags,
        'emoji': emoji,
        'category': category,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      };
}
