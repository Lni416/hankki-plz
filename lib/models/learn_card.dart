enum CardType { intro, technique, quiz, tip }

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

  const LearnCard({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.emoji,
    this.quizOptions,
  });

  String get typeLabel {
    switch (type) {
      case CardType.intro:
        return '재료 소개';
      case CardType.technique:
        return '조리 기술';
      case CardType.quiz:
        return '퀴즈';
      case CardType.tip:
        return '요린이 팁';
    }
  }
}
