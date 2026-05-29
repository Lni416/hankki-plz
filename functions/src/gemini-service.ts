import { GoogleGenerativeAI, Part } from "@google/generative-ai";

const getGeminiClient = () => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("GEMINI_API_KEY secret is not set");
  return new GoogleGenerativeAI(apiKey);
};

// ── 재료 인식 ──────────────────────────────────────────────────────────────

/**
 * Base64 이미지에서 식재료를 인식해 한국어 이름 배열 반환
 */
export async function recognizeIngredientsFromImage(
  imageBase64: string,
  mimeType: string = "image/jpeg"
): Promise<string[]> {
  const genAI = getGeminiClient();
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

  const imagePart: Part = {
    inlineData: { data: imageBase64, mimeType },
  };

  const prompt = `이 사진에서 식재료를 모두 찾아 한국어 이름으로만 JSON 배열로 반환하세요.
예시: ["달걀", "당근", "대파", "두부"]
이미지에 식재료가 없으면 빈 배열 []을 반환하세요.
JSON 배열 외에 다른 텍스트는 포함하지 마세요.`;

  const result = await model.generateContent([prompt, imagePart]);
  const text = result.response.text().trim();

  try {
    const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
    return JSON.parse(cleaned) as string[];
  } catch {
    // 파싱 실패 시 텍스트에서 추출 시도
    const matches = text.match(/["']([가-힣\s]+)["']/g);
    if (matches) return matches.map((m) => m.replace(/["']/g, "").trim());
    return [];
  }
}

// ── 학습 카드 생성 ─────────────────────────────────────────────────────────

export interface LearnCardData {
  order: number;
  type: "intro" | "technique" | "quiz" | "tip";
  title: string;
  content: string;
  emoji: string;
  quizOptions?: Array<{ text: string; isCorrect: boolean }>;
}

/**
 * 레시피 제목으로 학습 카드 5장 생성 (1회성 배치 처리용)
 */
export async function generateLessonCards(
  recipeTitle: string,
  recipeDescription: string
): Promise<LearnCardData[]> {
  const genAI = getGeminiClient();
  const model = genAI.getGenerativeModel({ model: "gemini-1.5-pro" });

  const prompt = `"${recipeTitle}" 요리를 위한 학습 카드 5장을 만들어주세요.
요리 설명: ${recipeDescription}

아래 JSON 배열 형식으로만 반환하세요:
[
  {
    "order": 1,
    "type": "intro",
    "title": "재료 소개 제목",
    "content": "재료와 기본 설명 (2-3문장)",
    "emoji": "적절한 이모지"
  },
  {
    "order": 2,
    "type": "technique",
    "title": "핵심 기술 제목",
    "content": "조리 핵심 기술 설명 (2-3문장)",
    "emoji": "적절한 이모지"
  },
  {
    "order": 3,
    "type": "technique",
    "title": "화력/시간 조절",
    "content": "불 세기와 조리 시간 팁 (2-3문장)",
    "emoji": "🔥"
  },
  {
    "order": 4,
    "type": "quiz",
    "title": "퀴즈 질문",
    "content": "퀴즈 힌트나 배경 설명",
    "emoji": "❓",
    "quizOptions": [
      {"text": "보기1", "isCorrect": true},
      {"text": "보기2", "isCorrect": false},
      {"text": "보기3", "isCorrect": false},
      {"text": "보기4", "isCorrect": false}
    ]
  },
  {
    "order": 5,
    "type": "tip",
    "title": "요린이 꿀팁",
    "content": "초보자를 위한 응용/변형 팁 (2-3문장)",
    "emoji": "💡"
  }
]`;

  const result = await model.generateContent(prompt);
  const text = result.response.text().trim();
  const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
  return JSON.parse(cleaned) as LearnCardData[];
}
