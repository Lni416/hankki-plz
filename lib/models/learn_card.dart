import 'package:cloud_firestore/cloud_firestore.dart';

enum CardType { intro, step, technique, quiz, tip }

class QuizOption {
  final String text;
  final bool isCorrect;
  const QuizOption({required this.text, required this.isCorrect});
}

class LearnCard {
  final String id;
  final CardType type;
  final String title;
  final String content;
  final String emoji;
  final List<QuizOption>? quizOptions;

  /// 조리 단계 카드 전용: 팁 텍스트
  final String? tip;

  /// 조리 단계 카드 전용: 단계 번호 (1, 2, 3...)
  final int? stepNumber;

  const LearnCard({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.emoji,
    this.quizOptions,
    this.tip,
    this.stepNumber,
  });

  String get typeLabel {
    switch (type) {
      case CardType.intro:
        return '재료 소개';
      case CardType.step:
        return '조리 단계';
      case CardType.technique:
        return '조리 기술';
      case CardType.quiz:
        return '퀴즈';
      case CardType.tip:
        return '요린이 팁';
    }
  }

  factory LearnCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LearnCard(
      id: doc.id,
      type: CardType.values.firstWhere(
        (t) => t.name == (data['type'] as String? ?? 'intro'),
        orElse: () => CardType.intro,
      ),
      title: data['title'] as String,
      content: data['content'] as String,
      emoji: data['emoji'] as String? ?? '🍳',
      tip: data['tip'] as String?,
      stepNumber: (data['stepNumber'] as num?)?.toInt(),
      quizOptions: data['quizOptions'] != null
          ? (data['quizOptions'] as List<dynamic>)
              .map((e) => QuizOption(
                    text: e['text'] as String,
                    isCorrect: e['isCorrect'] as bool,
                  ))
              .toList()
          : null,
    );
  }
}
