/**
 * 레시피 데이터를 Firestore에 시드하는 스크립트 (1회성)
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

const INPUT_FILE = path.join(__dirname, "../data/recipes-labeled.json");

admin.initializeApp();
const db = admin.firestore();

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
  console.log(`📦 ${recipes.length}개 레시피 업로드 시작...`);

  const BATCH_LIMIT = 400; // Firestore 배치 한 번에 500 작업 제한 (여유 둠)
  let uploaded = 0;

  for (let i = 0; i < recipes.length; i += BATCH_LIMIT) {
    const chunk = recipes.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();

    for (const recipe of chunk) {
      const id = uuidv4();
      const ref = db.collection("recipes").doc(id);

      // 디버깅 전용 필드 제거
      const { _featureScore: _f, _mlDifficulty: _m, ...clean } = recipe;

      batch.set(ref, {
        ...clean,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedBy: "gemini",
      });
    }

    await batch.commit();
    uploaded += chunk.length;
    console.log(`  ✅ ${uploaded}/${recipes.length} 업로드됨`);
  }

  console.log(`\n🎉 시드 완료! Firestore recipes 컬렉션에 ${uploaded}개 레시피가 추가되었습니다.`);
}

seed().catch((e) => {
  console.error("❌ 시드 실패:", e);
  process.exit(1);
});
