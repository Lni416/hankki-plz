/**
 * 레시피 데이터를 Firestore에 시드하는 스크립트 (1회성)
 *
 * 각 레시피 문서를 업로드하고, recipe.lessonCards에 직접 작성된 학습카드를
 * recipes/{recipeId}/lessonCards/{order} 서브컬렉션에 저장한다.
 * (Gemini API 호출 없음 — 카드는 data/recipes-labeled.json에 직접 포함)
 *
 * 사용법:
 *   export GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json
 *   npx ts-node scripts/seed-to-firestore.ts
 *
 * 입력: data/recipes-labeled.json
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";
import { v4 as uuidv4 } from "uuid";

// 200개 생성 카탈로그(recipes-seed.json)가 있으면 우선 사용, 없으면 직접 작성본 사용
const SEED_FILE = path.join(__dirname, "../data/recipes-seed.json");
const LABELED_FILE = path.join(__dirname, "../data/recipes-labeled.json");
const INPUT_FILE = fs.existsSync(SEED_FILE) ? SEED_FILE : LABELED_FILE;

admin.initializeApp();
const db = admin.firestore();

interface QuizOption {
  text: string;
  isCorrect: boolean;
}

interface LessonCard {
  order: number;
  type: "intro" | "technique" | "quiz" | "tip";
  title: string;
  content: string;
  emoji: string;
  quizOptions?: QuizOption[];
}

interface LabeledRecipe {
  title: string;
  emoji: string;
  description: string;
  difficulty: number;
  cookingTimeMinutes: number;
  servings: number;
  category: string;
  tags: string[];
  ingredients: unknown[];
  steps: unknown[];
  nutrition: unknown;
  thumbnailUrl?: string;
  lessonCards?: LessonCard[];
  _featureScore?: number;
  _mlDifficulty?: number;
}

async function seed() {
  if (!fs.existsSync(INPUT_FILE)) {
    console.error(`❌ 파일 없음: ${INPUT_FILE}`);
    process.exit(1);
  }

  const recipes: LabeledRecipe[] = JSON.parse(
    fs.readFileSync(INPUT_FILE, "utf-8")
  );
  console.log(`📦 ${recipes.length}개 레시피 업로드 + 학습카드 시드 시작...`);

  let uploaded = 0;
  let cardsCreated = 0;

  for (const recipe of recipes) {
    const id = uuidv4();
    const recipeRef = db.collection("recipes").doc(id);

    // 디버깅/카드 필드 제거 후 레시피 문서 저장
    const {
      _featureScore: _f,
      _mlDifficulty: _m,
      lessonCards,
      ...clean
    } = recipe;

    const batch = db.batch();
    batch.set(recipeRef, {
      ...clean,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      generatedBy: "manual",
    });

    // 학습카드 서브컬렉션
    const cards = lessonCards ?? [];
    for (const card of cards) {
      const cardRef = recipeRef
        .collection("lessonCards")
        .doc(String(card.order));
      batch.set(cardRef, card);
    }

    await batch.commit();
    uploaded++;
    cardsCreated += cards.length;
    console.log(
      `  ✅ [${uploaded}/${recipes.length}] ${recipe.title} — 카드 ${cards.length}장`
    );
  }

  console.log(
    `\n🎉 시드 완료! 레시피 ${uploaded}개, 학습카드 ${cardsCreated}장이 Firestore에 추가되었습니다.`
  );
}

seed().catch((e) => {
  console.error("❌ 시드 실패:", e);
  process.exit(1);
});
