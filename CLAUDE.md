# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**한끼를 부탁해 (hankki-plz)** — 냉장고 재료 기반 요리 학습 Flutter 앱 (iOS / Android / Web).
- **배포 URL**: https://hankki-plz.web.app
- **GitHub**: https://github.com/Lni416/hankki-plz
- **Firebase 프로젝트**: hankki-plz (Firestore, Auth, Hosting, Functions)

## Commands

```bash
# 의존성 설치
flutter pub get

# 정적 분석
flutter analyze

# Web 빌드 (build/web/ 출력)
flutter build web --release

# 개발 서버 실행 (Web)
flutter run -d chrome

# Firebase Hosting 배포
firebase deploy --only hosting

# Firestore 규칙만 배포
firebase deploy --only firestore:rules

# 레시피 200개 재생성 (data/recipes-seed.json)
python3 scripts/generate_recipes.py

# Firestore 레시피 시드 (idempotent — 중복 없이 덮어쓰기)
node scripts/seed.js

# 로컬 서버 미리보기
cd build/web && python3 -m http.server 8788
```

## Architecture

### 상태 관리 (Riverpod)

| Provider | 파일 | 역할 |
|---|---|---|
| `firebaseAvailableProvider` | `auth_provider.dart` | Firebase 초기화 여부 — main.dart의 ProviderScope에서 override |
| `authStateProvider` | `auth_provider.dart` | `FirebaseAuth.instance.authStateChanges()` 스트림 |
| `authNotifierProvider` | `auth_provider.dart` | Google 로그인 / 익명 로그인 / 로그아웃 |
| `fridgeProvider` | `fridge_provider.dart` | 냉장고 재료 목록 (Firestore 실시간 스트림, CRUD) |
| `urgentIngredientsProvider` | `fridge_provider.dart` | 유통기한 D-2 이하 재료 파생값 |
| `allRecipesProvider` | `recipe_provider.dart` | Firestore에서 전체 레시피 로드 (비면 mockRecipes 폴백) |
| `recommendedRecipesProvider` | `recipe_provider.dart` | 보유재료 매칭률→유통기한임박→난이도 순 정렬 |
| `topRecommendationsProvider` | `recipe_provider.dart` | 홈 '오늘의 추천' 최대 10개 |
| `selectedRecipeProvider` | `recipe_provider.dart` | 레시피 상세 진입 시 선택된 Recipe (in-memory StateProvider) |
| `learnProvider` | `learn_provider.dart` | XP / 레벨 / 스트릭 / todayCompleted (Firestore 연동) |
| `currentLessonCardsProvider` | `learn_provider.dart` | 선택 레시피 기반 학습카드 동적 생성 |
| `favoritesProvider` | `favorite_provider.dart` | 찜한 레시피 (Firestore 스트림) |
| `historyProvider` | `history_provider.dart` | 요리 히스토리 (Firestore 스트림) |
| `notificationsProvider` | `notification_history_provider.dart` | 알림 내역 (Firestore 스트림) |

**Auth 로딩 가드 패턴** (fridge / recipe / history 등 모든 Firestore provider 공통):
```dart
final authAsync = ref.watch(authStateProvider);
if (authAsync.isLoading) {
  // 빈 스트림 반환 → AsyncLoading 유지 (빈 화면 방지)
  final controller = StreamController<T>(); ref.onDispose(controller.close);
  return controller.stream;
}
```

**중앙 Auth 게이트** (`lib/main.dart`): Firebase 사용 중이고 auth가 로딩 중이면 `MaterialApp.router` 대신 스플래시만 렌더. 어떤 provider도 auth 확정 전에 실행되지 않도록 차단.

### 라우팅 (go_router)

`lib/app/router.dart` — 단일 `ShellRoute`로 5개 탭:

```
/home  /fridge  /recipe  /recipe/detail  /learn  /profile
/profile/favorites  /profile/history  /profile/notifications  /profile/help
```

탭 이동: `context.go(path)`, 서브 화면: `context.push(path)` / `Navigator.push`.
`/recipe/detail`은 ShellRoute 하위라 하단 탭이 유지됨.

### 데이터 레이어

**Firestore 컬렉션 구조:**
```
recipes/{id}                  ← 레시피 (200개, scripts/seed.js로 시드)
  lessonCards/{order}         ← 기존 18개 레시피의 학습카드
users/{uid}                   ← 사용자 통계 (XP, 스트릭, todayCompleted 등)
  ingredients/{id}            ← 냉장고 재료
  favorites/{recipeId}        ← 찜한 레시피
  history/{autoId}            ← 요리 히스토리
  notifications/{autoId}      ← 알림 내역
  recommendedRecipes/{id}     ← 추천 이력 (Cloud Functions 전용 쓰기)
```

**보안 규칙**: `firestore.rules` — 사용자 데이터는 본인만, 레시피는 인증된 사용자 읽기 전용.

**Mock 폴백**: Firebase 미설정이거나 Firestore가 비어있으면 `lib/models/mock_data.dart`의 mockRecipes / mockIngredients 사용.

**데이터 디렉터리** (`data/`)는 `.gitignore`로 추적 제외 — Firestore가 소스 오브 트루스. 재시드 필요 시:
```bash
python3 scripts/generate_recipes.py  # data/recipes-seed.json 생성 (200개)
node scripts/seed.js                 # Firestore 업로드
```

### 핵심 모델

- `Ingredient` — `expiryDate` 기반 computed: `isExpired` / `isUrgent(D-2이하)` / `expiryColor` / `expiryLabel`
- `Recipe` — `matchRate`·`hasUrgentIngredient`는 `recommendedRecipesProvider`에서 재계산, `copyWith`으로만 생성
- `UserStats` — `copyWith` 패턴, XP 300 단위 레벨업, `lastStudyDate` 기반 todayCompleted 날짜 보정
- `LearnCard` — `CardType { intro, step, technique, quiz, tip }`, step 카드에 `tip`·`stepNumber` 필드
- `FavoriteRecipe` / `CookingHistoryEntry` / `AppNotification` — `lib/models/profile_models.dart`

### 주요 설계 결정

**레시피 추천 정렬**: 유통기한임박 → 보유재료 매칭률(contains 부분매칭) → 쉬운 난이도 순.

**학습 플로우**: `LessonScreen`은 스크롤 피드 방식 (카드 전체를 세로 나열). `currentLessonCardsProvider`가 `recipe.steps`를 기반으로 `[재료소개] → [단계×N] → [퀴즈] → [팁]` 순으로 카드를 동적 생성. 퀴즈 답변 후 맨 아래 '레슨 완료하기' 버튼 활성화 → `learnProvider.notifier.completeLesson(50)` 호출.

**학습 날짜 보정**: `learnProvider.build()`에서 Firestore 데이터 로드 시 `lastStudyDate`가 오늘이 아니면 `todayCompleted/todayLessons`를 0으로, 이틀 이상 끊기면 `streak`도 0으로 보정.

**이모지 렌더링**: 웹에서 Google Fonts(Noto Sans KR)가 이모지를 덮어쓰는 버그 → `emojiStyle(double fontSize)` 함수 (`lib/core/theme/app_theme.dart`)로 `fontFamilyFallback` 명시. 모든 동적 이모지 Text 위젯에 적용.

**재료 이모지 자동 매핑**: `lib/core/util/ingredient_emoji.dart` — 이름 부분매칭→카테고리 폴백. `lib/core/util/ingredient_category_resolver.dart` — 이름→카테고리 자동 추론.

**최근 추가 재료**: `SharedPreferences`에 로컬 저장 (기기 단위, 최대 6개). Firestore 사용자 데이터와 저장 방식이 다름.

**보안**: `scripts/service-account.json`은 gitignore됨 — 절대 커밋 금지. `GOOGLE_APPLICATION_CREDENTIALS` 환경변수로만 사용.

### 테마 / 디자인 토큰

`lib/core/theme/app_theme.dart`의 `AppColors` 클래스. 인라인 `Color(0xFF...)` 대신 여기에 정의.
