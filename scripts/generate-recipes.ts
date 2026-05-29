/**
 * 레시피 100개 사전 생성 스크립트 (1회성 오프라인 배치)
 *
 * 사용법:
 *   export GEMINI_API_KEY=your_key
 *   npx ts-node scripts/generate-recipes.ts
 *
 * 출력: data/recipes-raw.json
 */

import * as fs from "fs";
import * as path from "path";
import { GoogleGenerativeAI } from "@google/generative-ai";

const OUTPUT_DIR = path.join(__dirname, "../data");
const OUTPUT_FILE = path.join(OUTPUT_DIR, "recipes-raw.json");
const BATCH_SIZE = 10; // 한 번 요청당 레시피 수
const DELAY_MS = 3000; // rate limit 방지 대기

// ── 목표 요리 목록 (난이도별 분류) ────────────────────────────────────────
const RECIPE_TARGETS: Array<{ title: string; difficulty: number }> = [
  // ★ 매우 쉬움 (20개)
  { title: "계란후라이", difficulty: 1 },
  { title: "라면", difficulty: 1 },
  { title: "김치볶음밥", difficulty: 1 },
  { title: "참치마요덮밥", difficulty: 1 },
  { title: "햄볶음밥", difficulty: 1 },
  { title: "달걀 스크램블", difficulty: 1 },
  { title: "바나나 요거트", difficulty: 1 },
  { title: "토마토 샐러드", difficulty: 1 },
  { title: "오이 냉채", difficulty: 1 },
  { title: "간장계란덮밥", difficulty: 1 },
  { title: "우유 죽", difficulty: 1 },
  { title: "전자레인지 달걀찜", difficulty: 1 },
  { title: "참치 샌드위치", difficulty: 1 },
  { title: "냉동만두 에어프라이어", difficulty: 1 },
  { title: "미역국 (즉석)", difficulty: 1 },
  { title: "소시지 볶음", difficulty: 1 },
  { title: "묵은지 볶음밥", difficulty: 1 },
  { title: "치즈 토스트", difficulty: 1 },
  { title: "오트밀 죽", difficulty: 1 },
  { title: "콘치즈 (전자레인지)", difficulty: 1 },
  // ★★ 쉬움 (25개)
  { title: "된장찌개", difficulty: 2 },
  { title: "계란볶음밥", difficulty: 2 },
  { title: "야채볶음", difficulty: 2 },
  { title: "오이무침", difficulty: 2 },
  { title: "시금치나물", difficulty: 2 },
  { title: "콩나물무침", difficulty: 2 },
  { title: "어묵탕", difficulty: 2 },
  { title: "감자조림", difficulty: 2 },
  { title: "두부 된장국", difficulty: 2 },
  { title: "베이컨 볶음", difficulty: 2 },
  { title: "참깨 시금치 무침", difficulty: 2 },
  { title: "감자채볶음", difficulty: 2 },
  { title: "당근 라페", difficulty: 2 },
  { title: "마늘 버터 파스타", difficulty: 2 },
  { title: "달걀 국", difficulty: 2 },
  { title: "팽이버섯 볶음", difficulty: 2 },
  { title: "콩나물국", difficulty: 2 },
  { title: "미역 냉국", difficulty: 2 },
  { title: "아욱국", difficulty: 2 },
  { title: "무국", difficulty: 2 },
  { title: "라면 떡볶이 (즉석)", difficulty: 2 },
  { title: "두부 부침", difficulty: 2 },
  { title: "오이 소박이", difficulty: 2 },
  { title: "계란말이", difficulty: 2 },
  { title: "쑥갓 겉절이", difficulty: 2 },
  // ★★★ 보통 (25개)
  { title: "김치찌개", difficulty: 3 },
  { title: "제육볶음", difficulty: 3 },
  { title: "두부조림", difficulty: 3 },
  { title: "어묵볶음", difficulty: 3 },
  { title: "부대찌개", difficulty: 3 },
  { title: "닭볶음탕", difficulty: 3 },
  { title: "순두부찌개", difficulty: 3 },
  { title: "고등어 조림", difficulty: 3 },
  { title: "돼지고기 간장볶음", difficulty: 3 },
  { title: "해물파전", difficulty: 3 },
  { title: "비빔국수", difficulty: 3 },
  { title: "떡볶이", difficulty: 3 },
  { title: "오징어볶음", difficulty: 3 },
  { title: "닭가슴살 샐러드", difficulty: 3 },
  { title: "콩비지찌개", difficulty: 3 },
  { title: "알탕", difficulty: 3 },
  { title: "된장 삼겹살 구이", difficulty: 3 },
  { title: "김치 칼국수", difficulty: 3 },
  { title: "쭈꾸미볶음", difficulty: 3 },
  { title: "소고기 뭇국", difficulty: 3 },
  { title: "닭갈비", difficulty: 3 },
  { title: "참치 김치찌개", difficulty: 3 },
  { title: "동태찌개", difficulty: 3 },
  { title: "감자탕 (간편)", difficulty: 3 },
  { title: "돼지 수육", difficulty: 3 },
  // ★★★★ 어려움 (20개)
  { title: "불고기", difficulty: 4 },
  { title: "잡채", difficulty: 4 },
  { title: "갈비찜", difficulty: 4 },
  { title: "낙지볶음", difficulty: 4 },
  { title: "꽃게탕", difficulty: 4 },
  { title: "삼겹살 김치찜", difficulty: 4 },
  { title: "돼지 등갈비 찜", difficulty: 4 },
  { title: "차돌박이 된장찌개", difficulty: 4 },
  { title: "소고기 미역국", difficulty: 4 },
  { title: "닭백숙", difficulty: 4 },
  { title: "해물 된장찌개", difficulty: 4 },
  { title: "매운 아귀찜", difficulty: 4 },
  { title: "소고기 장조림", difficulty: 4 },
  { title: "고기만두 (직접 만들기)", difficulty: 4 },
  { title: "수제비", difficulty: 4 },
  { title: "칼국수 (직접 면 반죽)", difficulty: 4 },
  { title: "콩나물 해장국", difficulty: 4 },
  { title: "돼지불백", difficulty: 4 },
  { title: "낙곱새", difficulty: 4 },
  { title: "해물 순두부찌개", difficulty: 4 },
  // ★★★★★ 매우 어려움 (10개)
  { title: "삼계탕", difficulty: 5 },
  { title: "갈비탕", difficulty: 5 },
  { title: "전복죽", difficulty: 5 },
  { title: "보쌈 (직접)", difficulty: 5 },
  { title: "수육국밥", difficulty: 5 },
  { title: "어복쟁반", difficulty: 5 },
  { title: "설렁탕", difficulty: 5 },
  { title: "우거지 갈비탕", difficulty: 5 },
  { title: "냉면 (직접 육수)", difficulty: 5 },
  { title: "곰탕", difficulty: 5 },
];

// ── Gemini 요청 ─────────────────────────────────────────────────────────────

interface RecipeResult {
  title: string;
  emoji: string;
  description: string;
  difficulty: number;
  cookingTimeMinutes: number;
  servings: number;
  category: string;
  tags: string[];
  ingredients: Array<{
    name: string;
    amount: number;
    unit: string;
    isOptional?: boolean;
  }>;
  steps: Array<{
    order: number;
    description: string;
    tip?: string;
    durationMinutes?: number;
  }>;
  nutrition: {
    calories: number;
    carbs: number;
    protein: number;
    fat: number;
  };
}

async function generateBatch(
  model: ReturnType<GoogleGenerativeAI["getGenerativeModel"]>,
  targets: typeof RECIPE_TARGETS
): Promise<RecipeResult[]> {
  const titleList = targets
    .map((t) => `- ${t.title} (난이도 ${t.difficulty}성)`)
    .join("\n");

  const prompt = `다음 한국 요리들의 상세 레시피를 JSON 배열로 작성해주세요.
각 요리는 실제 레시피여야 하며, 아래 형식을 정확히 따르세요.

요리 목록:
${titleList}

JSON 형식 (배열):
[
  {
    "title": "요리명",
    "emoji": "요리에 맞는 이모지",
    "description": "요리 한 줄 소개",
    "difficulty": 1~5 숫자,
    "cookingTimeMinutes": 조리시간(숫자),
    "servings": 인분(숫자),
    "category": "한식/분식/국/찌개/볶음/무침/구이 중 하나",
    "tags": ["태그1", "태그2"],
    "ingredients": [
      {"name": "재료명", "amount": 수량, "unit": "단위", "isOptional": false}
    ],
    "steps": [
      {"order": 1, "description": "조리 단계 설명", "tip": "팁(없으면 생략)", "durationMinutes": 시간(없으면 생략)}
    ],
    "nutrition": {"calories": 칼로리, "carbs": 탄수화물g, "protein": 단백질g, "fat": 지방g}
  }
]

JSON 배열만 반환하고 다른 텍스트는 포함하지 마세요.`;

  const result = await model.generateContent(prompt);
  const text = result.response.text().trim();
  const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
  return JSON.parse(cleaned) as RecipeResult[];
}

// ── 메인 ──────────────────────────────────────────────────────────────────

async function main() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error("❌ GEMINI_API_KEY 환경변수를 설정해주세요");
    process.exit(1);
  }

  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  // 이미 생성된 파일이 있으면 이어서 진행
  let existing: RecipeResult[] = [];
  if (fs.existsSync(OUTPUT_FILE)) {
    existing = JSON.parse(fs.readFileSync(OUTPUT_FILE, "utf-8")) as RecipeResult[];
    console.log(`📂 기존 ${existing.length}개 레시피 발견 — 이어서 생성합니다`);
  }
  const existingTitles = new Set(existing.map((r) => r.title));
  const remaining = RECIPE_TARGETS.filter((t) => !existingTitles.has(t.title));
  console.log(`🍳 생성 대상: ${remaining.length}개`);

  if (remaining.length === 0) {
    console.log("✅ 모든 레시피가 이미 생성되어 있습니다.");
    return;
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-pro" });

  const all = [...existing];

  for (let i = 0; i < remaining.length; i += BATCH_SIZE) {
    const batch = remaining.slice(i, i + BATCH_SIZE);
    console.log(`\n📦 배치 ${Math.floor(i / BATCH_SIZE) + 1}: ${batch.map((b) => b.title).join(", ")}`);

    try {
      const results = await generateBatch(model, batch);
      all.push(...results);
      fs.writeFileSync(OUTPUT_FILE, JSON.stringify(all, null, 2), "utf-8");
      console.log(`  ✅ ${results.length}개 생성 완료 (누적: ${all.length}개)`);
    } catch (e) {
      console.error(`  ❌ 배치 실패:`, e);
      console.log("  💾 현재까지 저장 후 대기...");
      fs.writeFileSync(OUTPUT_FILE, JSON.stringify(all, null, 2), "utf-8");
    }

    if (i + BATCH_SIZE < remaining.length) {
      console.log(`  ⏳ ${DELAY_MS}ms 대기 중...`);
      await new Promise((r) => setTimeout(r, DELAY_MS));
    }
  }

  console.log(`\n🎉 완료! ${all.length}개 레시피 → ${OUTPUT_FILE}`);
  console.log("👉 다음 단계: npx ts-node scripts/label-difficulty.ts");
}

main().catch(console.error);
