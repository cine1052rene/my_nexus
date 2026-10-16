const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenAI } = require("@google/genai");
const admin = require("firebase-admin");
const { initializeFirestore } = require("firebase-admin/firestore");

const app = admin.initializeApp();

// Firestore를 gRPC 대신 REST(HTTP/1.1)로 연결한다.
// 2026-10-14 실측: 콜드 스타트 인스턴스의 첫 Firestore 호출(한도 확인)이
// 1,543ms, 웜 상태는 60~82ms였다. 차이의 대부분이 gRPC 채널 초기화다.
// 이 함수들은 단건 읽기·트랜잭션·재귀 삭제만 쓰므로 REST로 충분하고,
// 실시간 리스너처럼 gRPC가 필요한 기능을 쓰면 SDK가 알아서 gRPC로 전환한다.
const db = initializeFirestore(app, { preferRest: true });

const PROJECT_ID = "my-nexus-hub";
// 2026-10-14 생성 (asia-northeast3). SNS 썸네일 사본 보관용.
const STORAGE_BUCKET = "my-nexus-hub.firebasestorage.app";
const LOCATION = "asia-northeast3"; // Cloud Functions 배포 리전 (서울)

// ── Vertex AI 호출 리전 ───────────────────────────────────────
//
// Functions 배포 리전(LOCATION)과 **반드시 분리해서 쓸 것.**
// Gemini 3.x 계열은 asia-northeast3에 아예 배포돼 있지 않아
// 지역 엔드포인트로 호출하면 404 "Publisher model not found"가 난다.
// (2026-09-03 실측: 3.5-flash-lite / 3.5-flash / 3.6-flash / 3.7-flash 전부
//  asia-northeast3 404, global OK. 2.5-flash만 둘 다 OK였음)
//
// 즉 모델명만 바꾸고 리전을 그대로 두면 챗봇이 통째로 죽는다.
// global 엔드포인트는 지역 데이터 레지던시를 보장하지 않는다 —
// 개인정보처리방침 5항에 Vertex AI 위탁이 이미 고지돼 있고
// 지역 관련 문구는 없으므로 현재 방침과 충돌하지 않는다.
const VERTEX_LOCATION = "global";

// ── 사용 모델 ─────────────────────────────────────────────────
//
// 100만 토큰당 단가 (입력/출력), 2026-10-14 공식 가격표 기준:
//   gemini-3.1-flash-lite $0.25 / $1.50   ← 채택 (Vertex 지원 2027-05-07 이후까지)
//   gemini-3.5-flash-lite $0.30 / $2.50   ← 직전 모델 (2026-09-03~10-14)
//   gemini-2.5-flash-lite $0.10 / $0.40   ← 2026-10-20 지원 종료라 탈락
//   gemini-3.6-flash      $0.75 / $3.75 → 2027-01-01부터 $1.50 / $7.50
//
// 운영비의 90%가 챗봇 LLM이고 그중 출력 토큰이 대부분이라, 출력 단가가
// 곧 원가다. 3.5→3.1 교체로 출력 단가가 40% 내려간다.
// 2026-10-14 global 엔드포인트 실측 (같은 링크 추천 질문 4회):
//   3.5-flash-lite 1.1~1.4초 / 3.1-flash-lite 1.0~1.3초 / 2.5-flash-lite 2.3~2.5초
// 답변 품질은 3.1이 오히려 나았다 (링크 4개 모두 활용, 3.5는 띄어쓰기 누락).
// thinkingBudget=0이라 추론 성능이 필요한 구간이 아니다.
//
// ⚠️ 모델을 바꿀 땐 VERTEX_LOCATION 지원 여부를 먼저 실측할 것.
// ⚠️ lib/shared/services/ai/gemini_service.dart 의 model 과 같은 값이어야 한다.
const GEMINI_MODEL = "gemini-3.1-flash-lite";

const CHAT_SYSTEM_INSTRUCTION = "당신은 간결하고 친절한 한국어 챗봇입니다.";

// Vertex 클라이언트는 인스턴스당 한 번만 만든다 (호출마다 만들 이유가 없음).
let _ai = null;
function getAi() {
  if (!_ai) {
    _ai = new GoogleGenAI({
      vertexai: true,
      project: PROJECT_ID,
      location: VERTEX_LOCATION,
    });
  }
  return _ai;
}

// 콜드 스타트 판별용 — 인스턴스의 첫 요청에서만 true.
let _warm = false;

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
    const snap = await db.doc("config/limits").get();
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
 * - 무료 유저: config/limits 일·월 한도 (Firestore 트랜잭션으로 서버사이드 체크)
 * - mode: "generate" (큐레이션·이메일 등) | "chat" (챗봇)
 * - 스트리밍: 클라이언트가 stream()으로 부르면 생성되는 대로
 *   {text: 조각}을 sendChunk로 보낸다. 일반 call()이면 sendChunk가
 *   아무 일도 하지 않으므로, 스트리밍을 모르는 구버전 앱도 그대로 동작한다.
 *   최종 반환값 {text, isPremium}은 두 경우 모두 동일하다.
 */
exports.callGemini = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    region: LOCATION,
  },
  async (request, response) => {
    const t0 = Date.now();
    const cold = !_warm;
    _warm = true;

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
    const userRef = db.collection("users").doc(uid);

    // 한도 문서 읽기와 사용자 문서 읽기를 동시에 진행한다.
    // (예전엔 한도를 다 읽은 뒤에야 트랜잭션을 시작해 왕복이 직렬로 쌓였다)
    // getLimits()는 실패해도 기본값을 돌려주므로 reject되지 않는다.
    const limitsPromise = getLimits();

    try {
      await db.runTransaction(async (tx) => {
        const userDoc = await tx.get(userRef);
        const data = userDoc.exists ? userDoc.data() : null;

        isPremium = data?.isPremium === true;
        if (isPremium) return;

        const limits = await limitsPromise;

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

    const tUsage = Date.now();

    // ── 생성 요청 구성 ─────────────────────────────────
    // 예전 코드는 chats.create()에 systemInstruction을 config 바깥에 넣어
    // 히스토리가 있는 대화에서는 시스템 지시가 적용되지 않았다.
    // 히스토리를 contents 앞에 그대로 붙이면 chats API 없이 같은 결과가 나온다.
    const config = {
      temperature: mode === "chat" ? 0.7 : 0.9,
      maxOutputTokens: mode === "chat" ? 2048 : 4096,
      // thinking 토큰 비용 차단 (기본값이 동적 할당이라 명시적 OFF 필요).
      // thinking 토큰은 출력 단가로 과금되므로 끄지 않으면 비용이 튄다.
      thinkingConfig: { thinkingBudget: 0 },
    };
    if (mode === "chat") config.systemInstruction = CHAT_SYSTEM_INSTRUCTION;

    const contents = [
      ...(mode === "chat" && Array.isArray(history) ? history : []),
      { role: "user", parts: [{ text: prompt }] },
    ];

    let text = "";
    let tFirst = 0;
    try {
      if (request.acceptsStreaming) {
        // 스트리밍: 생성되는 조각을 바로 앱으로 흘려보낸다.
        // 전체 생성 시간은 같지만 첫 글자가 훨씬 일찍 뜬다.
        const stream = await getAi().models.generateContentStream({
          model: GEMINI_MODEL,
          contents,
          config,
        });
        for await (const chunk of stream) {
          const piece = chunk.text;
          if (!piece) continue;
          if (!tFirst) tFirst = Date.now();
          text += piece;
          await response.sendChunk({ text: piece });
        }
      } else {
        const result = await getAi().models.generateContent({
          model: GEMINI_MODEL,
          contents,
          config,
        });
        text = result.text;
      }
    } catch (e) {
      console.error("Gemini error:", e.message, e.stack);
      throw new HttpsError("internal", `Gemini 오류: ${e.message}`);
    }

    // 구간별 소요 시간 — Cloud Logging에서 jsonPayload로 집계할 수 있다.
    // usageMs: 한도 확인(트랜잭션), modelMs: 모델 호출 전체,
    // firstChunkMs: 요청 시작부터 첫 조각 전송까지(스트리밍일 때만)
    const tEnd = Date.now();
    console.log(
      JSON.stringify({
        event: "callGemini_timing",
        model: GEMINI_MODEL,
        mode,
        cold,
        streaming: request.acceptsStreaming === true,
        usageMs: tUsage - t0,
        modelMs: tEnd - tUsage,
        firstChunkMs: tFirst ? tFirst - t0 : null,
        totalMs: tEnd - t0,
      })
    );

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

    try {
      // 1. users/{uid} 문서 + 모든 서브컬렉션 재귀 삭제
      await db.recursiveDelete(db.collection("users").doc(uid));

      // 2. Storage의 사용자 파일 전체 삭제 (SNS 썸네일 사본 users/{uid}/thumbs/)
      //    Firestore만 지우면 이미지가 고아로 남아 "모든 데이터 삭제"가 아니다.
      await admin
        .storage()
        .bucket(STORAGE_BUCKET)
        .deleteFiles({ prefix: `users/${uid}/` });

      // 3. Firebase Auth 계정 삭제
      await admin.auth().deleteUser(uid);

      console.log(`계정 삭제 완료: ${uid}`);
      return { success: true };
    } catch (e) {
      console.error("deleteUserAccount error:", e.message, e.stack);
      throw new HttpsError("internal", `계정 삭제 오류: ${e.message}`);
    }
  }
);
