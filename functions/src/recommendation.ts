import * as admin from "firebase-admin";

export interface RecipeDoc {
  id: string;
  title: string;
  emoji: string;
  difficulty: number;
  cookingTimeMinutes: number;
  ingredients: Array<{ name: string; amount: number; unit: string; isOptional?: boolean }>;
  tags: string[];
  thumbnailUrl?: string;
  description?: string;
}

export interface UserContext {
  fridgeIngredients: string[];   // 보유 재료 이름 목록
  urgentIngredients: string[];   // D-2 이하 임박 재료
  userLevel: number;             // 사용자 XP 레벨 (1~)
  recommendedHistory: string[];  // 이미 추천된 recipeId 목록
}

export interface ScoredRecipe extends RecipeDoc {
  matchRate: number;
  hasUrgentIngredient: boolean;
  score: number;
}

// ── 점수 계산 ──────────────────────────────────────────────────────────────

/**
 * 재료 이름 정규화 — 공백/조사 제거 후 소문자
 */
function normalize(name: string): string {
  return name.toLowerCase().replace(/\s/g, "");
}

function ingredientMatchRate(
  recipeIngredients: RecipeDoc["ingredients"],
  fridgeNames: string[]
): number {
  const required = recipeIngredients.filter((i) => !i.isOptional);
  if (required.length === 0) return 1.0;
  const normFridge = fridgeNames.map(normalize);

  const matched = required.filter((ri) => {
    const riNorm = normalize(ri.name);
    return normFridge.some(
      (fn) => fn.includes(riNorm) || riNorm.includes(fn)
    );
  }).length;

  return matched / required.length;
}

function difficultyScore(recipeDifficulty: number, userLevel: number): number {
  // 레벨 → 선호 난이도 매핑
  let preferred: number;
  if (userLevel <= 2) preferred = 1.5;
  else if (userLevel <= 4) preferred = 2.5;
  else if (userLevel <= 6) preferred = 3.5;
  else preferred = 4.5;

  return 1 - Math.abs(recipeDifficulty - preferred) / 5;
}

function urgencyBonus(
  recipeIngredients: RecipeDoc["ingredients"],
  urgentNames: string[]
): number {
  if (urgentNames.length === 0) return 0;
  const normUrgent = urgentNames.map(normalize);
  const hasUrgent = recipeIngredients.some((ri) => {
    const riNorm = normalize(ri.name);
    return normUrgent.some((un) => un.includes(riNorm) || riNorm.includes(un));
  });
  return hasUrgent ? 0.5 : 0;
}

function noveltyScore(recipeId: string, history: string[]): number {
  return history.includes(recipeId) ? -0.5 : 0;
}

/**
 * 레시피 목록에 점수를 계산해 내림차순 정렬 후 반환
 * 가중치: 재료매칭 40% + 난이도 30% + 임박재료 20% + 신규성 10%
 */
export function scoreAndSort(
  recipes: RecipeDoc[],
  ctx: UserContext,
  topN = 10
): ScoredRecipe[] {
  const scored: ScoredRecipe[] = recipes.map((recipe) => {
    const matchRate = ingredientMatchRate(recipe.ingredients, ctx.fridgeIngredients);
    const diffScore = difficultyScore(recipe.difficulty, ctx.userLevel);
    const urgBonus = urgencyBonus(recipe.ingredients, ctx.urgentIngredients);
    const novelty = noveltyScore(recipe.id, ctx.recommendedHistory);

    const hasUrgentIngredient = urgBonus > 0;
    const score =
      0.4 * matchRate +
      0.3 * diffScore +
      0.2 * (hasUrgentIngredient ? 1 : 0) +
      0.1 * (1 + novelty); // novelty는 -0.5 ~ 0

    return { ...recipe, matchRate, hasUrgentIngredient, score };
  });

  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, topN);
}

// ── Firestore 조회 ─────────────────────────────────────────────────────────

export async function fetchAllRecipes(): Promise<RecipeDoc[]> {
  const snap = await admin.firestore().collection("recipes").get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() } as RecipeDoc));
}

export async function fetchRecommendedHistory(uid: string): Promise<string[]> {
  const snap = await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("recommendedRecipes")
    .select() // ID만 가져옴
    .get();
  return snap.docs.map((d) => d.id);
}

export async function saveRecommendations(
  uid: string,
  recipes: ScoredRecipe[]
): Promise<void> {
  const batch = admin.firestore().batch();
  const ref = admin.firestore().collection("users").doc(uid).collection("recommendedRecipes");
  for (const r of recipes) {
    batch.set(
      ref.doc(r.id),
      {
        matchRate: r.matchRate,
        recommendedAt: admin.firestore.FieldValue.serverTimestamp(),
        completed: false,
      },
      { merge: true }
    );
  }
  await batch.commit();
}
