import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { recognizeIngredientsFromImage, generateLessonCards } from "./gemini-service";
import {
  fetchAllRecipes,
  fetchRecommendedHistory,
  saveRecommendations,
  scoreAndSort,
  UserContext,
} from "./recommendation";

admin.initializeApp();

const REGION = "asia-northeast3";

// ── 재료 인식 ──────────────────────────────────────────────────────────────

export const recognizeIngredients = onCall(
  { region: REGION, secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "로그인이 필요합니다");

    const { imageBase64, mimeType } = request.data as {
      imageBase64: string;
      mimeType?: string;
    };

    if (!imageBase64) throw new HttpsError("invalid-argument", "이미지 데이터가 없습니다");

    const ingredients = await recognizeIngredientsFromImage(
      imageBase64,
      mimeType ?? "image/jpeg"
    );
    return { ingredients };
  }
);

// ── 레시피 추천 ───────────────────────────────────────────────────────────

export const getRecommendedRecipes = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "로그인이 필요합니다");

    const { ingredients, difficultyLevel, uid } = request.data as {
      ingredients: string[];
      difficultyLevel: number;
      uid: string;
    };

    if (request.auth.uid !== uid) {
      throw new HttpsError("permission-denied", "다른 사용자의 데이터에 접근할 수 없습니다");
    }

    const [allRecipes, history] = await Promise.all([
      fetchAllRecipes(),
      fetchRecommendedHistory(uid),
    ]);

    const ctx: UserContext = {
      fridgeIngredients: ingredients ?? [],
      urgentIngredients: [],          // 클라이언트에서 전달 가능 — 현재는 생략
      userLevel: difficultyLevel ?? 2,
      recommendedHistory: history,
    };

    const scored = scoreAndSort(allRecipes, ctx, 10);
    await saveRecommendations(uid, scored);

    return {
      recipes: scored.map(({ score: _score, ...rest }) => rest), // score 제거 후 반환
    };
  }
);

// ── 학습 카드 생성 ─────────────────────────────────────────────────────────

export const generateLessonCardsForRecipe = onCall(
  { region: REGION, secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "로그인이 필요합니다");

    const { recipeId } = request.data as { recipeId: string };
    if (!recipeId) throw new HttpsError("invalid-argument", "recipeId가 없습니다");

    const db = admin.firestore();

    // 이미 생성된 카드가 있으면 재사용
    const existing = await db
      .collection("recipes")
      .doc(recipeId)
      .collection("lessonCards")
      .get();
    if (!existing.empty) {
      return {
        cards: existing.docs.map((d) => ({ id: d.id, ...d.data() })),
      };
    }

    // 레시피 정보 조회
    const recipeDoc = await db.collection("recipes").doc(recipeId).get();
    if (!recipeDoc.exists) throw new HttpsError("not-found", "레시피를 찾을 수 없습니다");

    const recipe = recipeDoc.data()!;
    const cards = await generateLessonCards(
      recipe.title as string,
      recipe.description as string ?? ""
    );

    // Firestore에 저장 (1회성)
    const batch = db.batch();
    for (const card of cards) {
      const ref = db.collection("recipes").doc(recipeId).collection("lessonCards").doc();
      batch.set(ref, card);
    }
    await batch.commit();

    return { cards };
  }
);

// ── 스트릭 자동 계산 ────────────────────────────────────────────────────────

export const onStatsUpdated = onDocumentUpdated(
  {
    document: "users/{uid}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    // lastStudyDate가 변경됐을 때만 처리
    const beforeDate = before.lastStudyDate?.toDate?.();
    const afterDate = after.lastStudyDate?.toDate?.();
    if (!afterDate || beforeDate?.getTime() === afterDate.getTime()) return;

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const studyDay = new Date(afterDate);
    studyDay.setHours(0, 0, 0, 0);
    const diffDays =
      (today.getTime() - studyDay.getTime()) / (1000 * 60 * 60 * 24);

    // 주간 XP 리셋 (월요일마다)
    const dayOfWeek = today.getDay(); // 0=일, 1=월 ...
    if (dayOfWeek === 1 && diffDays === 0) {
      await event.data?.after?.ref.update({
        weeklyXp: Array(7).fill(0),
      });
    }
  }
);

// ── 유통기한 임박 FCM 알림 (매일 오전 9시, KST) ──────────────────────────────

export const sendExpiryNotifications = onSchedule(
  {
    schedule: "0 0 * * *", // UTC 00:00 = KST 09:00
    region: REGION,
    timeZone: "Asia/Seoul",
  },
  async () => {
    const db = admin.firestore();
    const messaging = admin.messaging();
    const now = admin.firestore.Timestamp.now();
    const threeDaysLater = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 3 * 24 * 60 * 60 * 1000
    );

    // 모든 사용자 순회 (실제 서비스에서는 페이지네이션 필요)
    const usersSnap = await db.collection("users").get();

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const urgentSnap = await db
        .collection("users")
        .doc(uid)
        .collection("ingredients")
        .where("expiryDate", "<=", threeDaysLater)
        .where("expiryDate", ">=", now)
        .get();

      if (urgentSnap.empty) continue;

      const names = urgentSnap.docs
        .map((d) => d.data().name as string)
        .slice(0, 3)
        .join(", ");

      const fcmToken = userDoc.data().fcmToken as string | undefined;
      if (!fcmToken) continue;

      await messaging.send({
        token: fcmToken,
        notification: {
          title: "🧊 유통기한 임박 재료가 있어요!",
          body: `${names} 등이 3일 이내에 유통기한이 지나요. 지금 요리해 보세요!`,
        },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default" } } },
      });
    }

    functions.logger.info("Expiry notifications sent");
  }
);
