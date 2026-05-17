import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learn_card.dart';
import '../models/mock_data.dart';

class UserStats {
  final int streak;
  final int xp;
  final int level;
  final int todayLessons;
  final bool todayCompleted;

  const UserStats({
    this.streak = 3,
    this.xp = 420,
    this.level = 2,
    this.todayLessons = 0,
    this.todayCompleted = false,
  });

  int get xpToNextLevel => (level * 300) - xp;
  double get levelProgress => xp / (level * 300);

  String get levelTitle {
    if (level <= 1) return '요린이';
    if (level <= 3) return '입문 요리사';
    if (level <= 5) return '집밥 달인';
    if (level <= 8) return '요리 고수';
    return '집밥의 신';
  }

  UserStats copyWith({
    int? streak,
    int? xp,
    int? level,
    int? todayLessons,
    bool? todayCompleted,
  }) =>
      UserStats(
        streak: streak ?? this.streak,
        xp: xp ?? this.xp,
        level: level ?? this.level,
        todayLessons: todayLessons ?? this.todayLessons,
        todayCompleted: todayCompleted ?? this.todayCompleted,
      );
}

class LearnNotifier extends StateNotifier<UserStats> {
  LearnNotifier() : super(const UserStats());

  void completeLesson(int xpEarned) {
    final newXp = state.xp + xpEarned;
    final newLevel = (newXp / 300).floor() + 1;
    state = state.copyWith(
      xp: newXp,
      level: newLevel,
      todayLessons: state.todayLessons + 1,
      todayCompleted: true,
    );
  }
}

final learnProvider = StateNotifierProvider<LearnNotifier, UserStats>(
  (ref) => LearnNotifier(),
);

final currentLessonCardsProvider = Provider<List<LearnCard>>((ref) {
  return mockLearnCards;
});

final lessonProgressProvider = StateProvider<int>((ref) => 0);
final quizAnswerProvider = StateProvider<int?>((ref) => null);
