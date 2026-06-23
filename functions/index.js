const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin");

admin.initializeApp();

// API 키를 Firebase Secret Manager에 저장 (배포 시 설정)
const geminiApiKey = defineSecret("GEMINI_API_KEY");

/**
 * Gemini AI 프록시 함수
 * - 인증된 사용자만 호출 가능
 * - Firestore users/{uid}.isPremium 으로 프리미엄 판단
 * - mode: "generate" (큐레이션·이메일 등) | "chat" (챗봇)
 */
exports.callGemini = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 60,
    memory: "256MiB",
    region: "asia-northeast3", // 서울 리전
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

    // ── Gemini 호출 ────────────────────────────────────
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({
      model: "gemini-2.5-flash",
      generationConfig: {
        temperature: mode === "chat" ? 0.7 : 0.9,
        maxOutputTokens: mode === "chat" ? 2048 : 4096,
      },
      ...(mode === "chat"
        ? { systemInstruction: "당신은 간결하고 친절한 한국어 챗봇입니다." }
        : {}),
    });

    let text;
    try {
      if (mode === "chat" && Array.isArray(history) && history.length > 0) {
        // 채팅: 이전 대화 히스토리 포함
        const chat = model.startChat({ history });
        const result = await chat.sendMessage(prompt);
        text = result.response.text();
      } else {
        // 일반 생성
        const result = await model.generateContent(prompt);
        text = result.response.text();
      }
    } catch (e) {
      throw new HttpsError("internal", `Gemini 오류: ${e.message}`);
    }

    return { text, isPremium };
  }
);
