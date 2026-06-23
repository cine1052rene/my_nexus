const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenAI } = require("@google/genai");
const admin = require("firebase-admin");

admin.initializeApp();

const PROJECT_ID = "my-nexus-hub";
const LOCATION = "asia-northeast3"; // 서울 리전

/**
 * Gemini AI 프록시 함수 (Vertex AI IAM 방식 — API 키 불필요)
 * - 인증된 사용자만 호출 가능
 * - Firestore users/{uid}.isPremium 으로 프리미엄 판단
 * - mode: "generate" (큐레이션·이메일 등) | "chat" (챗봇)
 */
exports.callGemini = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    region: LOCATION,
  },
  async (request) => {
    // ── 인증 확인 ─────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const { prompt, history, mode = "generate" } = request.data;
    if (!prompt || typeof prompt !== "string") {
      throw new HttpsError("invalid-argument", "prompt가 필요합니다.");
    }

    // ── 프리미엄 확인 (Firestore) ──────────────────────
    let isPremium = false;
    try {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(request.auth.uid)
        .get();
      isPremium = userDoc.exists && userDoc.data()?.isPremium === true;
    } catch (_) {
      // 조회 실패 시 무료로 처리
    }

    // ── @google/genai Vertex AI 모드 (IAM 자동 인증) ───
    const ai = new GoogleGenAI({
      vertexai: true,
      project: PROJECT_ID,
      location: LOCATION,
    });

    const modelConfig = {
      model: "gemini-2.5-flash",
      config: {
        temperature: mode === "chat" ? 0.7 : 0.9,
        maxOutputTokens: mode === "chat" ? 2048 : 4096,
      },
    };

    let text;
    try {
      if (mode === "chat" && Array.isArray(history) && history.length > 0) {
        // 채팅: 이전 대화 히스토리 포함
        // history 형식: [{role: "user"|"model", parts: [{text: "..."}]}]
        const chat = ai.chats.create({
          ...modelConfig,
          history,
          ...(mode === "chat"
            ? {
                systemInstruction:
                  "당신은 간결하고 친절한 한국어 챗봇입니다.",
              }
            : {}),
        });
        const result = await chat.sendMessage({ message: prompt });
        text = result.text;
      } else {
        // 일반 생성
        const contents = [{ role: "user", parts: [{ text: prompt }] }];
        if (mode === "chat") {
          modelConfig.systemInstruction =
            "당신은 간결하고 친절한 한국어 챗봇입니다.";
        }
        const result = await ai.models.generateContent({
          ...modelConfig,
          contents,
        });
        text = result.text;
      }
    } catch (e) {
      console.error("Gemini error:", e.message, e.stack);
      throw new HttpsError("internal", `Gemini 오류: ${e.message}`);
    }

    return { text, isPremium };
  }
);
