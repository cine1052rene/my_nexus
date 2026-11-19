// AI 호출 라우터 — 어느 회사·모델을 쓸지는 Firestore `config/ai` 문서가 정한다.
//
//   config/ai = {
//     provider: "vertex-gemini" | "openai" | "anthropic",
//     model:    "gemini-3.1-flash-lite",
//     baseUrl:  (openai 호환 API일 때만, 선택)
//     sendTemperature: false  (temperature를 받지 않는 모델일 때만, 선택)
//   }
//
// 문서가 없거나 값이 잘못됐으면 DEFAULT로 동작한다.
// 선택한 회사 호출이 **첫 조각을 보내기 전에** 실패하면 DEFAULT로 한 번 더
// 시도한다. 새 회사로 바꿨다가 키 설정을 빠뜨려도 챗봇이 죽지 않게 하기 위해서다.
// (조각을 이미 보냈으면 답변이 섞이므로 재시도하지 않는다)
//
// ⚠️ config/{doc}은 로그인 사용자 누구나 읽을 수 있다 (firestore.rules).
//    여기에는 회사·모델 이름만 둔다. API 키는 절대 넣지 말 것 → Secret Manager.

const { normalizeHistory } = require("./messages");

const PROVIDERS = {
  "vertex-gemini": require("./providers/vertex-gemini"),
  openai: require("./providers/openai"),
  anthropic: require("./providers/anthropic"),
};

// 바꿀 때 lib/shared/services/ai/ai_config.dart 의 fallback 과 같이 맞출 것.
const DEFAULT = { provider: "vertex-gemini", model: "gemini-3.1-flash-lite" };

const CACHE_MS = 60 * 1000;
let _cache = null;
let _cachedAt = 0;

function sanitize(d) {
  const provider = PROVIDERS[d?.provider] ? d.provider : DEFAULT.provider;
  const model =
    typeof d?.model === "string" && d.model.trim() && provider === d?.provider
      ? d.model.trim()
      : DEFAULT.model;
  // provider만 바뀌고 model이 비어 있으면 다른 회사에 Gemini 모델명을 보내게 되므로
  // 그런 경우 통째로 DEFAULT로 돌린다.
  if (provider !== DEFAULT.provider && model === DEFAULT.model) {
    return { ...DEFAULT };
  }
  const cfg = { provider, model };
  if (typeof d?.baseUrl === "string" && d.baseUrl.startsWith("https://")) {
    cfg.baseUrl = d.baseUrl;
  }
  if (d?.sendTemperature === false) cfg.sendTemperature = false;
  return cfg;
}

async function getAiConfig(db) {
  const now = Date.now();
  if (_cache && now - _cachedAt < CACHE_MS) return _cache;
  try {
    const snap = await db.doc("config/ai").get();
    _cache = sanitize(snap.exists ? snap.data() : null);
  } catch (e) {
    console.error("config/ai 읽기 실패, 기본값 사용:", e.message);
    _cache = { ...DEFAULT };
  }
  _cachedAt = now;
  return _cache;
}

/**
 * @param {object} p
 * @param {FirebaseFirestore.Firestore} p.db
 * @param {"chat"|"generate"} p.mode
 * @param {string} p.prompt
 * @param {any[]} [p.history] 중립 형식 또는 구 Gemini 형식
 * @param {string} [p.system]
 * @param {(piece:string)=>Promise<void>} [p.onChunk]
 * @returns {Promise<{text:string, provider:string, model:string, fellBack:boolean}>}
 */
async function generate(p) {
  const cfg = await getAiConfig(p.db);
  const messages = [
    ...(p.mode === "chat" ? normalizeHistory(p.history) : []),
    { role: "user", text: p.prompt },
  ];
  const base = {
    system: p.system,
    messages,
    temperature: p.mode === "chat" ? 0.7 : 0.9,
    maxTokens: p.mode === "chat" ? 2048 : 4096,
  };

  let sent = false;
  const onChunk = p.onChunk
    ? async (piece) => {
        sent = true;
        await p.onChunk(piece);
      }
    : undefined;

  const run = (c) =>
    PROVIDERS[c.provider].generate({
      ...base,
      model: c.model,
      baseUrl: c.baseUrl,
      temperature: c.sendTemperature === false ? undefined : base.temperature,
      onChunk,
    });

  try {
    const text = await run(cfg);
    return { text, provider: cfg.provider, model: cfg.model, fellBack: false };
  } catch (e) {
    const isDefault =
      cfg.provider === DEFAULT.provider && cfg.model === DEFAULT.model;
    if (isDefault || sent) throw e;
    console.error(
      JSON.stringify({
        event: "ai_fallback",
        provider: cfg.provider,
        model: cfg.model,
        error: String(e.message).slice(0, 300),
      })
    );
    const text = await run(DEFAULT);
    return { text, provider: DEFAULT.provider, model: DEFAULT.model, fellBack: true };
  }
}

/** Secret Manager 키가 필요한 회사 목록 (README의 활성화 절차 참고). */
const SECRET_NAMES = Object.values(PROVIDERS)
  .map((pr) => pr.secret)
  .filter(Boolean);

module.exports = {
  generate,
  getAiConfig,
  sanitize,
  DEFAULT,
  PROVIDERS,
  SECRET_NAMES,
  _resetCacheForTest: () => {
    _cache = null;
    _cachedAt = 0;
  },
};
