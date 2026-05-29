# 한끼를 부탁해 (hankki-plz)

> 냉장고 속 재료로 오늘 뭐 해먹지? — 매일 조금씩 요리를 배우는 Flutter기반 어플리케이션

## 소개

냉장고 재료 기반 요리 학습 앱입니다.  
보유 재료를 등록하면 매칭률 순으로 레시피를 추천하고, 학습 카드로 요리를 배울 수 있습니다.

## 주요 기능

- **냉장고 관리** — 카메라 인식(YOLOv8) 또는 수동 입력, 유통기한 D-day 배지
- **레시피 추천** — 보유 재료 매칭률 + 난이도(★1~5) 기반 정렬, 임박 재료 우선
- **학습 모드** — 카드형 레슨(소개/기술/퀴즈), XP·레벨업, 스트릭, 주간 퀘스트
- **할인 알림** — 부족 재료 가격 추적, 평소 대비 저렴할 때만 푸시 알림

## 기술 스택

| 영역 | 기술 |
|---|---|
| 프레임워크 | Flutter 3 (iOS / Android / Web) |
| 상태 관리 | Riverpod 2 |
| 라우팅 | go_router |
| UI | fl_chart, flutter_animate, Noto Sans KR |
| AI (계획) | YOLOv8 (식재료 인식), Gemini API (레시피 생성) |
| 백엔드 (계획) | Firebase (Auth, Firestore, FCM) |

## 실행 방법

```bash
flutter pub get
flutter run -d chrome        # Web
flutter run -d <device_id>   # iOS / Android
```

Web 빌드 후 로컬 서버:
```bash
flutter build web --release
cd build/web && python3 -m http.server 8788
```

## 프로젝트 구조

```
lib/
├── app/          # 라우터, ShellScaffold (하단 탭)
├── core/theme/   # AppTheme, AppColors
├── models/       # Ingredient, Recipe, LearnCard, MockData
├── providers/    # Riverpod: Fridge / Recipe / Learn
├── screens/      # 홈, 냉장고, 레시피, 학습, 프로필
└── widgets/      # StreakBadge, DifficultyStars, MatchRateBar
```

> 현재 버전은 Mock 데이터 기반 데모입니다. Firebase 및 실 API 연동은 Phase 2에서 진행 예정입니다.
