import 'package:cloud_firestore/cloud_firestore.dart';

/// 찜한 레시피 항목
class FavoriteRecipe {
  final String recipeId;
  final String title;
  final String emoji;
  final DateTime? addedAt;

  const FavoriteRecipe({
    required this.recipeId,
    required this.title,
    required this.emoji,
    this.addedAt,
  });

  factory FavoriteRecipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FavoriteRecipe(
      recipeId: data['recipeId'] as String? ?? doc.id,
      title: data['title'] as String? ?? '',
      emoji: data['emoji'] as String? ?? '🍽️',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 요리 히스토리 항목
class CookingHistoryEntry {
  final String id;
  final String recipeId;
  final String title;
  final String emoji;
  final int xpEarned;
  final DateTime? completedAt;

  const CookingHistoryEntry({
    required this.id,
    required this.recipeId,
    required this.title,
    required this.emoji,
    required this.xpEarned,
    this.completedAt,
  });

  factory CookingHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CookingHistoryEntry(
      id: doc.id,
      recipeId: data['recipeId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      emoji: data['emoji'] as String? ?? '🍳',
      xpEarned: (data['xpEarned'] as num?)?.toInt() ?? 0,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 앱 알림 내역 항목
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      type: data['type'] as String? ?? 'info',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
