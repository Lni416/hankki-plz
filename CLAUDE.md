# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**한끼를 부탁해 (hankki-plz)** — 냉장고 재료 기반 요리 학습 Flutter 앱 (iOS / Android / Web).

## Commands

```bash
# 의존성 설치
flutter pub get

# 정적 분석
flutter analyze

# Web 빌드 (build/web/ 출력)
flutter build web --release

# iOS 빌드
flutter build ios --release

# Android 빌드
flutter build apk --release

# 개발 서버 실행 (Web)
flutter run -d chrome

# 특정 기기 실행
flutter run -d <device_id>

# 테스트 실행
flutter test

# 단일 테스트 실행
flutter test test/widget_test.dart
```

Web 빌드 후 로컬 서버 미리보기:
```bash
cd build/web && python3 -m http.server 8788
```

## Architecture

### 상태 관리 (Riverpod)

모든 전역 상태는 `lib/providers/`의 `StateNotifierProvider` / `Provider`로 관리합니다.

| Provider | 파일 | 역할 |
|---|---|---|
| `fridgeProvider` | `fridge_provider.dart` | 냉장고 재료 목록 (CRUD) |
| `urgentIngredientsProvider` | `fridge_provider.dart` | 유통기한 D-2 이하 재료 파생값 |
| `recommendedRecipesProvider` | `recipe_provider.dart` | 보유 재료 매칭률 계산 후 정렬된 레시피 목록. `fridgeProvider`·`selectedDifficultyProvider`·`searchQueryProvider`를 watch |
| `selectedRecipeProvider` | `recipe_provider.dart` | 레시피 상세 진입 시 선택된 Recipe 객체 |
| `learnProvider` | `learn_provider.dart` | XP / 레벨 / 스트릭 등 사용자 학습 통계 |

### 라우팅 (go_router)

`lib/app/router.dart`에서 단일 `ShellRoute`로 5개 탭을 감싸고, `ShellScaffold`가 하단 네비게이션 바를 담당합니다. 탭 경로:

```
/home  /fridge  /recipe  /recipe/detail  /learn  /profile
```

`/recipe/detail`은 ShellRoute 하위에 있으므로 하단 탭이 유지됩니다. 탭 이동은 `context.go(path)`를 사용합니다.

### 데이터 레이어

현재 **Mock 데이터 전용**입니다. `lib/models/mock_data.dart`에 재료 10종·레시피 4종·학습 카드 5장이 하드코딩되어 있습니다. 실 API 연동 시 이 파일의 상수를 교체하거나 각 provider에서 `AsyncNotifierProvider`로 전환합니다.

**핵심 모델**:
- `Ingredient` — `expiryDate` 기반으로 `isExpired` / `isUrgent` / `isWarning` / `expiryColor` / `expiryLabel`을 계산하는 computed 프로퍼티 보유
- `Recipe` — `matchRate`와 `hasUrgentIngredient`는 `recommendedRecipesProvider` 내부에서 재계산되는 **mutable 필드**임 (불변 객체 아님)
- `UserStats` — `copyWith` 패턴, XP 300 단위로 레벨업

### 주요 설계 결정

**레시피 매칭**: `recommendedRecipesProvider`는 재료 이름에 부분 문자열 포함 여부(`contains`)로 매칭합니다. 정밀도 개선이 필요하면 이 로직을 수정하세요.

**학습 플로우**: `LessonScreen`은 `currentLessonCardsProvider`의 카드 목록을 순서대로 소비하고, 마지막 카드 완료 시 `learnProvider.notifier.completeLesson(xp)`를 호출합니다. 상태는 in-memory이므로 앱 재시작 시 초기화됩니다.

**한국어 폰트**: `google_fonts` 패키지의 `GoogleFonts.notoSansKrTextTheme()`을 `AppTheme.light`에 적용합니다. Web에서는 구글 폰트 CDN에서 다운로드하므로 초기 로딩 시 잠깐 네이티브 폰트가 표시될 수 있습니다.

### 테마 / 디자인 토큰

모든 색상 상수는 `lib/core/theme/app_theme.dart`의 `AppColors` 클래스에 있습니다. 새 색상을 추가할 때 인라인 `Color(0xFF...)` 대신 여기에 정의하세요.
