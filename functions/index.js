const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenAI } = require("@google/genai");
const admin = require("firebase-admin");

admin.initializeApp();

const PROJECT_ID = "my-nexus-hub";
const LOCATION = "asia-northeast3"; // 서울 리전

// ── 무료 한도 설정 ────────────────────────────────────────────
//
// 한도는 Firestore `config/limits` 문서가 단일 기준이다.
// 코드에 박아두면 숫자를 바꿀 때마다 서버 배포 + 앱 업데이트가 필요하고,
// 업데이트하지 않은 사용자는 화면에 표시되는 잔여 횟수와 실제 차단 시점이
// 어긋나 버그로 인식한다. 문서로 빼두면 콘솔에서 숫자만 바꿔도
// 서버와 앱이 동시에 따라온다.
//
// 문서가 없거나 읽기에 실패하면 아래 기본값으로 **막는 쪽**으로 동작한다.
// (설정을 못 읽었다고 무제한으로 열어주면 그게 곧 우회 경로다)
const DEFAULT_LIMITS = { dailyFree: 10, monthlyFree: 100 };

// Functions 인스턴스는 호출 간 재사용되므로 짧게 캐시해 매 호출 읽기를 줄인다.
const LIMITS_CACHE_MS = 60 * 1000;
let _limitsCache = null;
let _limitsCachedAt = 0;

async function getLimits() {
  const now = Date.now();
  if (_limitsCache && now - _limitsCachedAt < LIMITS_CACHE_MS) {
    return _limitsCache;
  }
  try {
    const snap = await admin.firestore().doc("config/limits").get();
    const d = snap.exists ? snap.data() : {};
    _limitsCache = {
      dailyFree: Number.isFinite(d.dailyFree)
        ? d.dailyFree
        : DEFAULT_LIMITS.dailyFree,
      monthlyFree: Number.isFinite(d.monthlyFree)
        ? d.monthlyFree
        : DEFAULT_LIMITS.monthlyFree,
    };
    _limitsCachedAt = now;
  } catch (e) {
    console.error("limits 문서 읽기 실패, 기본값 사용:", e.message);
    _limitsCache = { ...DEFAULT_LIMITS };
    _limitsCachedAt = now;
  }
  return _limitsCache;
}

/**
 * Gemini AI 프록시 함수 (Vertex AI IAM 방식 — API 키 불필요)
 * - 인증된 사용자만 호출 가능
 * - Firestore users/{uid}.isPremium 으로 프리미엄 판단
 * - 무료 유저: 일 30회 한도 (Firestore 트랜잭션으로 서버사이드 체크)
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

    // ── 프리미엄 확인 + 일일 사용량 체크 (Firestore 트랜잭션) ──
    let isPremium = false;
    const uid = request.auth.uid;
    const userRef = admin.firestore().collection("users").doc(uid);

    const limits = await getLimits();

    try {
      await admin.firestore().runTransaction(async (tx) => {
        const userDoc = await tx.get(userRef);
        const data = userDoc.exists ? userDoc.data() : null;

        isPremium = data?.isPremium === true;
        if (isPremium) return;

        const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
        const month = today.slice(0, 7); // YYYY-MM

        const lastDate = data?.lastUsageDate || "";
        const lastMonth = data?.lastUsageMonth || "";
        const dailyCount = lastDate === today ? (data?.dailyUsage || 0) : 0;
        const monthlyCount =
          lastMonth === month ? (data?.monthlyUsage || 0) : 0;

        if (dailyCount >= limits.dailyFree) {
          throw new HttpsError(
            "resource-exhausted",
            `오늘 무료 사용량(${limits.dailyFree}회)을 다 썼어요. 내일 다시 사용할 수 있어요.`
          );
        }

        // 일일 한도만으로는 최악의 경우(매일 한도를 채우는 사용자)를 막지
        // 못한다. 월 상한이 있어야 사용자당 비용에 실제 천장이 생긴다.
        if (monthlyCount >= limits.monthlyFree) {
          throw new HttpsError(
            "resource-exhausted",
            `이번 달 무료 사용량(${limits.monthlyFree}회)을 다 썼어요. 다음 달에 다시 사용할 수 있어요.`
          );
        }

        const usage = {
          dailyUsage: dailyCount + 1,
          lastUsageDate: today,
          monthlyUsage: monthlyCount + 1,
          lastUsageMonth: month,
        };

        if (userDoc.exists) {
          tx.update(userRef, usage);
        } else {
          // 문서가 없으면 만들어서 카운트한다.
          // 예전에는 여기서 그냥 return 해 사용량 체크를 통째로 건너뛰었다.
          // 즉 유저 문서를 지우기만 하면 한도가 사라지는 상태였다.
          tx.set(
            userRef,
            {
              uid,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              ...usage,
            },
            { merge: true }
          );
        }
      });
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      // fail-closed: 사용량을 확인하지 못했으면 호출을 막는다.
      // 예전에는 여기서 그냥 통과시켰기 때문에, 트랜잭션을 실패하게
      // 만들 수만 있으면 한도 없이 Vertex AI를 쓸 수 있었다.
      console.error("Usage transaction failed:", e);
      throw new HttpsError(
        "unavailable",
        "사용량을 확인하지 못했어요. 잠시 후 다시 시도해주세요."
      );
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
        // thinking 토큰 비용 차단 (Gemini 2.5 Flash 기본값 활성화 → 명시적 OFF)
        thinkingConfig: { thinkingBudget: 0 },
      },
    };

    let text;
    try {
      if (mode === "chat" && Array.isArray(history) && history.length > 0) {
        // 채팅: 이전 대화 히스토리 포함
        const chat = ai.chats.create({
          ...modelConfig,
          history,
          systemInstruction: "당신은 간결하고 친절한 한국어 챗봇입니다.",
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

/**
 * 계정 및 모든 데이터 영구 삭제 (Google Play 정책 필수)
 *
 * users/{uid} 문서와 그 **하위 서브컬렉션 전체**(links, events,
 * video_clips, settings)를 재귀적으로 지운 뒤 Auth 계정을 삭제한다.
 *
 * 이전 버전은 users/{uid} 문서 하나만 지웠다. 당시 링크·일정·클립이
 * 소유자 식별자 없는 전역 컬렉션이라 애초에 지울 수가 없었기 때문인데,
 * 그 상태로는 "모든 사용자 데이터 삭제"라는 Play 정책을 충족하지 못한다.
 * 데이터를 users/{uid} 하위로 옮기면서 재귀 삭제가 가능해졌다.
 */
exports.deleteUserAccount = onCall(
  {
    timeoutSeconds: 300,
    memory: "512MiB",
    region: LOCATION,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    try {
      // 1. users/{uid} 문서 + 모든 서브컬렉션 재귀 삭제
      await db.recursiveDelete(db.collection("users").doc(uid));

      // 2. Firebase Auth 계정 삭제
      await admin.auth().deleteUser(uid);

      console.log(`계정 삭제 완료: ${uid}`);
      return { success: true };
    } catch (e) {
      console.error("deleteUserAccount error:", e.message, e.stack);
      throw new HttpsError("internal", `계정 삭제 오류: ${e.message}`);
    }
  }
);
