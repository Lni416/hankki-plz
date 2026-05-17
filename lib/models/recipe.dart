class RecipeIngredient {
  final String name;
  final double amount;
  final String unit;
  final bool isOptional;

  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.isOptional = false,
  });
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

  // 보유 재료 기반 계산
  double matchRate;
  bool hasUrgentIngredient;

  Recipe({
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
    this.matchRate = 0.0,
    this.hasUrgentIngredient = false,
  });

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
}
