import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int streak;
  final int xp;
  final int level;
  final int todayLessons;
  final bool todayCompleted;
  final DateTime? lastStudyDate;
  final List<int> weeklyXp; // 7개 — 월~일 순서

  const UserStats({
    this.streak = 0,
    this.xp = 0,
    this.level = 1,
    this.todayLessons = 0,
    this.todayCompleted = false,
    this.lastStudyDate,
    this.weeklyXp = const [0, 0, 0, 0, 0, 0, 0],
  });

  int get xpToNextLevel => (level * 300) - xp;
  double get levelProgress => (xp % 300) / 300;

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
    DateTime? lastStudyDate,
    List<int>? weeklyXp,
  }) =>
      UserStats(
        streak: streak ?? this.streak,
        xp: xp ?? this.xp,
        level: level ?? this.level,
        todayLessons: todayLessons ?? this.todayLessons,
        todayCompleted: todayCompleted ?? this.todayCompleted,
        lastStudyDate: lastStudyDate ?? this.lastStudyDate,
        weeklyXp: weeklyXp ?? this.weeklyXp,
      );

  factory UserStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserStats(
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      todayLessons: (data['todayLessons'] as num?)?.toInt() ?? 0,
      todayCompleted: data['todayCompleted'] as bool? ?? false,
      lastStudyDate: data['lastStudyDate'] != null
          ? (data['lastStudyDate'] as Timestamp).toDate()
          : null,
      weeklyXp: data['weeklyXp'] != null
          ? List<int>.from(
              (data['weeklyXp'] as List).map((e) => (e as num).toInt()))
          : List.filled(7, 0),
    );
  }

  Map<String, dynamic> toMap() => {
        'streak': streak,
        'xp': xp,
        'level': level,
        'todayLessons': todayLessons,
        'todayCompleted': todayCompleted,
        'lastStudyDate':
            lastStudyDate != null ? Timestamp.fromDate(lastStudyDate!) : null,
        'weeklyXp': weeklyXp,
      };
}
