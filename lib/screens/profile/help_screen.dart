import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      '🧊 냉장고에 재료는 어떻게 추가하나요?',
      '냉장고 탭의 "재료 추가" 버튼을 누르고, 빠른 선택에서 고르거나 이름을 직접 입력하세요. '
          '"카메라 인식"을 쓰면 사진에서 식재료를 자동으로 찾아드려요.',
    ),
    (
      '🍽️ 레시피는 어떤 기준으로 추천되나요?',
      '냉장고에 있는 재료와 레시피 필수 재료의 매칭률을 계산해 정렬합니다. '
          '유통기한이 임박한 재료를 쓰는 레시피가 가장 먼저 추천돼요.',
    ),
    (
      '📚 학습(레슨)은 어떻게 진행되나요?',
      '레시피를 고른 뒤 "오늘의 레슨"을 시작하면 재료 소개 → 조리 단계 → 퀴즈 순서로 '
          '카드를 넘기며 따라할 수 있어요. 완료하면 XP와 스트릭이 쌓입니다.',
    ),
    (
      '❤️ 찜한 레시피는 어디서 보나요?',
      '레시피 상세 화면 우측 상단의 하트를 누르면 저장되고, 프로필 → 찜한 레시피에서 모아볼 수 있어요.',
    ),
    (
      '🔥 스트릭(연속 학습)은 무엇인가요?',
      '매일 레슨을 하나라도 완료하면 스트릭이 1씩 올라갑니다. 하루라도 거르면 다시 1부터 시작해요.',
    ),
    (
      '🔔 알림은 언제 오나요?',
      '재료 유통기한이 임박하거나, 학습 리마인더 시점에 알림을 보내드려요. '
          '프로필의 알림 설정에서 켜고 끌 수 있습니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도움말 💁'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _faqs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Text(
                  faq.$1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      faq.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
