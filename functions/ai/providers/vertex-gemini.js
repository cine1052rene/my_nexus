// Google Gemini (Vertex AI, 서비스 계정 IAM 인증 — API 키 불필요)
//
// ⚠️ Gemini 3.x는 asia-northeast3(서울)에 배포돼 있지 않아 지역 엔드포인트로
// 부르면 404 "Publisher model not found"가 난다 (2026-09-03 실측).
// 그래서 함수 배포 리전과 분리해 global로 호출한다.
// 모델을 바꿀 땐 global 지원 여부를 먼저 실측할 것.

const { GoogleGenAI } = require("@google/genai");

const PROJECT_ID = "my-nexus-hub";
const VERTEX_LOCATION = "global";

let _client = null;
function client() {
  if (!_client) {
    _client = new GoogleGenAI({
      vertexai: true,
      project: PROJECT_ID,
      location: VERTEX_LOCATION,
    });
  }
  return _client;
}

function toContents(messages) {
  return messages.map((m) => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.text }],
  }));
}

/**
 * @param {object} req
 * @param {string} req.model
 * @param {string|undefined} req.system
 * @param {{role:string,text:string}[]} req.messages 마지막이 이번 사용자 입력
 * @param {number} req.temperature
 * @param {number} req.maxTokens
 * @param {(piece:string)=>Promise<void>} [req.onChunk] 있으면 스트리밍
 * @returns {Promise<string>} 전체 답변
 */
async function generate(req) {
  const config = {
    temperature: req.temperature,
    maxOutputTokens: req.maxTokens,
    // thinking 토큰은 출력 단가로 과금된다. 기본값이 동적 할당이라 명시적으로 끈다.
    thinkingConfig: { thinkingBudget: 0 },
  };
  if (req.system) config.systemInstruction = req.system;
  const params = { model: req.model, contents: toContents(req.messages), config };

  if (!req.onChunk) {
    const result = await client().models.generateContent(params);
    return result.text || "";
  }
  let text = "";
  const stream = await client().models.generateContentStream(params);
  for await (const chunk of stream) {
    const piece = chunk.text;
    if (!piece) continue;
    text += piece;
    await req.onChunk(piece);
  }
  return text;
}

module.exports = { id: "vertex-gemini", secret: null, generate };
