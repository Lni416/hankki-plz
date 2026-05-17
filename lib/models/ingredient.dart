import 'package:flutter/material.dart';

enum IngredientCategory {
  meat('육류', Icons.set_meal),
  vegetable('채소', Icons.eco),
  dairy('유제품', Icons.egg_alt),
  grain('곡류', Icons.grain),
  seasoning('조미료', Icons.soup_kitchen),
  processed('가공식품', Icons.inventory_2),
  seafood('해산물', Icons.water),
  fruit('과일', Icons.apple);

  const IngredientCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class Ingredient {
  final String id;
  final String name;
  final IngredientCategory category;
  final double quantity;
  final String unit;
  final DateTime expiryDate;
  final String emoji;

  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    required this.emoji,
  });

  int get daysUntilExpiry =>
      expiryDate.difference(DateTime.now()).inDays;

  bool get isExpired => daysUntilExpiry < 0;
  bool get isUrgent => daysUntilExpiry >= 0 && daysUntilExpiry <= 2;
  bool get isWarning => daysUntilExpiry > 2 && daysUntilExpiry <= 5;

  Color get expiryColor {
    if (isExpired) return const Color(0xFFF44336);
    if (isUrgent) return const Color(0xFFFF9800);
    if (isWarning) return const Color(0xFFFFB300);
    return const Color(0xFF4CAF50);
  }

  String get expiryLabel {
    if (isExpired) return '유통기한 초과';
    if (daysUntilExpiry == 0) return '오늘 까지';
    if (daysUntilExpiry == 1) return 'D-1';
    return 'D-${daysUntilExpiry}';
  }

  Ingredient copyWith({
    double? quantity,
    DateTime? expiryDate,
  }) =>
      Ingredient(
        id: id,
        name: name,
        category: category,
        quantity: quantity ?? this.quantity,
        unit: unit,
        expiryDate: expiryDate ?? this.expiryDate,
        emoji: emoji,
      );
}
