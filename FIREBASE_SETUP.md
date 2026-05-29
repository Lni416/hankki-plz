# Firebase 프로젝트 설정 가이드 (백엔드팀)

## 1. Firebase Console에서 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/) → **프로젝트 추가**
2. 프로젝트 이름: `hankki-plz`
3. Google Analytics 활성화 권장

## 2. 앱 등록

### Android 앱 추가
- 패키지명: `com.gdg.hankki.plz`
- SHA-1 인증서 지문 등록 (Google 로그인 필수):
  ```bash
  # 디버그 키
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```
- `google-services.json` 다운로드 → `android/app/google-services.json` 에 배치

### iOS 앱 추가
- 번들 ID: `com.gdg.hankki.plz`
- `GoogleService-Info.plist` 다운로드 → `ios/Runner/GoogleService-Info.plist` 에 배치
- `REVERSED_CLIENT_ID` 값을 `ios/Runner/Info.plist`의 `REPLACE_WITH_REVERSED_CLIENT_ID` 부분에 교체

## 3. Firebase 서비스 활성화

Firebase Console → 각 서비스 활성화:
- **Authentication** → 로그인 제공업체: Google, 익명 활성화
- **Firestore Database** → 프로덕션 모드로 생성 (서울 리전: `asia-northeast3`)
- **Storage** → 기본 버킷 생성
- **Cloud Functions** → Node.js 22
- **Cloud Messaging (FCM)** → 기본 활성화

## 4. Firestore 보안 규칙 배포

```bash
firebase deploy --only firestore:rules
```

규칙 파일 (`firestore.rules`):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth.uid == uid;
    }
    match /recipes/{recipeId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    match /recipes/{recipeId}/lessonCards/{cardId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

## 5. Firestore 인덱스

`firestore.indexes.json`:
```json
{
  "indexes": [
    {
      "collectionGroup": "ingredients",
      "queryScope": "COLLECTION",
      "fields": [{"fieldPath": "addedAt", "order": "ASCENDING"}]
    }
  ]
}
```

## 6. 레시피 시드 데이터 업로드

ML/AI팀이 `data/recipes-labeled.json` 생성 후:
```bash
cd functions
npm run seed  # scripts/seed-recipes.ts 실행
```

## 7. 확인

```bash
flutter run -d android  # 또는 -d ios
```

앱 실행 후 Google 로그인 버튼 → Google 계정 선택 → 홈 화면 진입 확인.
