/**
 * Firestore 레시피 시드 (plain Node — ts-node 불필요)
 *
 * data/recipes-seed.json 의 레시피를 recipes/{id} 에 업로드하고,
 * lessonCards 가 있으면 recipes/{id}/lessonCards/{order} 서브컬렉션에 저장한다.
 *
 * - doc id 는 title 기반 결정적 해시 → 재실행 시 중복 없이 덮어쓰기(idempotent)
 * - 인증: scripts/service-account.json (gitignore됨) 사용
 *
 * 실행:  node scripts/seed.js
 */
const admin = require("firebase-admin");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const INPUT = path.join(__dirname, "../data/recipes-seed.json");
const KEY = path.join(__dirname, "service-account.json");

if (!fs.existsSync(KEY)) {
  console.error("❌ service-account.json 없음:", KEY);
  process.exit(1);
}
if (!fs.existsSync(INPUT)) {
  console.error("❌ 입력 파일 없음:", INPUT);
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(KEY)) });
const db = admin.firestore();

const idFor = (title) =>
  crypto.createHash("md5").update(title).digest("hex").slice(0, 20);

async function seed() {
  const recipes = JSON.parse(fs.readFileSync(INPUT, "utf-8"));
  console.log(`📦 ${recipes.length}개 레시피 시드 시작...`);

  let uploaded = 0;
  let cards = 0;
  // Firestore 배치 한도(500 op) 고려해 작은 청크로 커밋
  for (let i = 0; i < recipes.length; i += 100) {
    const chunk = recipes.slice(i, i + 100);
    const batch = db.batch();
    for (const recipe of chunk) {
      const id = idFor(recipe.title);
      const ref = db.collection("recipes").doc(id);
      const { lessonCards, _featureScore, _mlDifficulty, ...clean } = recipe;
      batch.set(ref, {
        ...clean,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedBy: "catalog",
      });
      for (const card of lessonCards || []) {
        batch.set(ref.collection("lessonCards").doc(String(card.order)), card);
        cards++;
      }
      uploaded++;
    }
    await batch.commit();
    console.log(`  ✅ ${Math.min(i + 100, recipes.length)}/${recipes.length}`);
  }

  console.log(`\n🎉 완료! 레시피 ${uploaded}개, 학습카드 ${cards}장 업로드.`);
}

seed()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ 시드 실패:", e.message);
    process.exit(1);
  });
