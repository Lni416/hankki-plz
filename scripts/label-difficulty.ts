/**
 * 레시피 난이도 ML 라벨링 스크립트
 *
 * 사용법:
 *   npx ts-node scripts/label-difficulty.ts
 *
 * 입력:  data/recipes-raw.json
 * 출력:  data/recipes-labeled.json
 *
 * 알고리즘: 규칙 기반 점수 → 1~5 난이도 라벨
 */

import * as fs from "fs";
import * as path from "path";

const INPUT_FILE = path.join(__dirname, "../data/recipes-raw.json");
const OUTPUT_FILE = path.join(__dirname, "../data/recipes-labeled.json");

interface RawRecipe {
  title: string;
  difficulty: number; // Gemini가 부여한 초기 값
  cookingTimeMinutes: number;
  ingredients: Array<{ name: string; isOptional?: boolean }>;
  steps: Array<{ description: string }>;
  [key: string]: unknown;
}

// ── 특수 기술 키워드 ──────────────────────────────────────────────────────
const HARD_TECHNIQUES = [
  "반죽", "밀가루반죽", "육수", "삶은", "튀김", "튀기", "숙성", "발효",
  "장조림", "찜", "보쌈", "수육", "삼계", "곰탕", "설렁탕",
];
const MEDIUM_TECHNIQUES = [
  "볶음", "조림", "부침", "전", "구이", "무침", "간장", "된장",
  "고추장", "마리네이드",
];

/**
 * 피처 기반 난이도 점수 계산 (0~10)
 */
function computeDifficultyScore(recipe: RawRecipe): number {
  let score = 0;

  // 1. 재료 수 (필수 재료만)
  const requiredCount = recipe.ingredients.filter((i) => !i.isOptional).length;
  if (requiredCount <= 3) score += 0;
  else if (requiredCount <= 6) score += 1;
  else if (requiredCount <= 10) score += 2;
  else score += 3;

  // 2. 조리 단계 수
  const stepCount = recipe.steps.length;
  if (stepCount <= 3) score += 0;
  else if (stepCount <= 5) score += 1;
  else if (stepCount <= 8) score += 2;
  else score += 3;

  // 3. 조리 시간
  const time = recipe.cookingTimeMinutes;
  if (time <= 10) score += 0;
  else if (time <= 20) score += 1;
  else if (time <= 40) score += 2;
  else score += 3;

  // 4. 기술 복잡도
  const allText = [
    recipe.title,
    ...recipe.steps.map((s) => s.description),
  ].join(" ");

  const hasHard = HARD_TECHNIQUES.some((t) => allText.includes(t));
  const hasMedium = MEDIUM_TECHNIQUES.some((t) => allText.includes(t));
  if (hasHard) score += 3;
  else if (hasMedium) score += 1;

  return score;
}

/**
 * 점수 → 1~5 난이도 레이블 변환
 */
function scoreToDifficulty(score: number): number {
  if (score <= 2) return 1;
  if (score <= 4) return 2;
  if (score <= 6) return 3;
  if (score <= 8) return 4;
  return 5;
}

function main() {
  if (!fs.existsSync(INPUT_FILE)) {
    console.error(`❌ 입력 파일 없음: ${INPUT_FILE}`);
    console.error("   먼저 generate-recipes.ts를 실행하세요.");
    process.exit(1);
  }

  const recipes = JSON.parse(fs.readFileSync(INPUT_FILE, "utf-8")) as RawRecipe[];
  console.log(`📂 ${recipes.length}개 레시피 로드됨`);

  const distribution: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };

  const labeled = recipes.map((recipe) => {
    const featureScore = computeDifficultyScore(recipe);
    const mlDifficulty = scoreToDifficulty(featureScore);

    // Gemini 원본 값과 ML 값 평균 (반올림)
    const finalDifficulty = Math.round((recipe.difficulty + mlDifficulty) / 2);
    const clamped = Math.max(1, Math.min(5, finalDifficulty)) as 1 | 2 | 3 | 4 | 5;

    distribution[clamped]++;

    return {
      ...recipe,
      difficulty: clamped,
      _featureScore: featureScore,   // 디버깅용 (시드 업로드 시 제거)
      _mlDifficulty: mlDifficulty,
    };
  });

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(labeled, null, 2), "utf-8");

  console.log("\n📊 난이도 분포:");
  for (const [d, count] of Object.entries(distribution)) {
    const bar = "█".repeat(count);
    console.log(`  ★${"★".repeat(Number(d) - 1).padEnd(4)} ${bar} (${count}개)`);
  }

  console.log(`\n✅ 라벨링 완료 → ${OUTPUT_FILE}`);
  console.log("👉 다음 단계: npx ts-node scripts/seed-to-firestore.ts");
}

main();
