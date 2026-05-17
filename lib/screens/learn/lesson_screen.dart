import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../models/learn_card.dart';
import '../../providers/learn_provider.dart';

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key});

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _showResult = false;

  List<LearnCard> get _cards => ref.read(currentLessonCardsProvider);

  LearnCard get _current => _cards[_currentIndex];
  bool get _isLast => _currentIndex >= _cards.length - 1;

  void _next() {
    if (_current.type == CardType.quiz &&
        _selectedAnswer == null) return;

    if (_isLast) {
      _completLesson();
    } else {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _showResult = false;
      });
    }
  }

  void _completLesson() {
    ref.read(learnProvider.notifier).completeLesson(50);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 56))
                  .animate()
                  .scale(curve: Curves.elasticOut),
              const SizedBox(height: 12),
              const Text(
                '레슨 완료!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '+50 XP 획득\n스트릭 유지 🔥',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${_currentIndex + 1} / ${_cards.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _cards.length,
            backgroundColor: AppColors.divider,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey(_currentIndex),
                  child: _buildCard(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_current.type == CardType.quiz &&
                        _selectedAnswer == null)
                    ? null
                    : _next,
                child: Text(_isLast ? '완료하기' : '다음'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    switch (_current.type) {
      case CardType.quiz:
        return _buildQuizCard();
      default:
        return _buildContentCard();
    }
  }

  Widget _buildContentCard() {
    final typeColors = {
      CardType.intro: AppColors.primary,
      CardType.technique: const Color(0xFF9C27B0),
      CardType.tip: AppColors.streakGold,
      CardType.quiz: AppColors.secondary,
    };
    final color = typeColors[_current.type]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _current.typeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _current.emoji,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            _current.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _current.content,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildQuizCard() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '퀴즈',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _current.emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              _current.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _current.content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ...(_current.quizOptions ?? []).asMap().entries.map((e) {
              final i = e.key;
              final opt = e.value;
              final isSelected = _selectedAnswer == i;
              final isCorrect = opt.isCorrect;

              Color bgColor = AppColors.cardBg;
              Color borderColor = Colors.transparent;
              if (_showResult && isSelected) {
                bgColor = isCorrect
                    ? AppColors.secondary.withOpacity(0.1)
                    : AppColors.danger.withOpacity(0.1);
                borderColor =
                    isCorrect ? AppColors.secondary : AppColors.danger;
              } else if (isSelected) {
                bgColor = AppColors.primary.withOpacity(0.08);
                borderColor = AppColors.primary;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    if (_showResult) return;
                    setState(() {
                      _selectedAnswer = i;
                      _showResult = true;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt.text,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_showResult && isCorrect)
                          const Icon(Icons.check_circle,
                              color: AppColors.secondary, size: 20),
                        if (_showResult && isSelected && !isCorrect)
                          const Icon(Icons.cancel,
                              color: AppColors.danger, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_showResult) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_current.quizOptions?[_selectedAnswer!].isCorrect ??
                              false)
                          ? AppColors.secondary.withOpacity(0.1)
                          : AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      (_current.quizOptions?[_selectedAnswer!].isCorrect ??
                              false)
                          ? '🎉'
                          : '💡',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_current.quizOptions?[_selectedAnswer!].isCorrect ??
                                false)
                            ? '정답이에요! 찬밥은 수분이 적어 볶음밥이 더 잘 됩니다.'
                            : '정답은 "찬밥을 사용한다"예요. 수분이 적어 볶음밥이 더 잘 됩니다!',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),
            ],
          ],
        ),
      ),
    );
  }
}
