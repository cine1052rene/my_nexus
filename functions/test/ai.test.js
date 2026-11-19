// 실행: cd functions && node --test test/
// 실제 회사 API는 호출하지 않는다 (fetch·provider를 가짜로 바꿔 끼움).

const test = require("node:test");
const assert = require("node:assert");
const { normalizeHistory } = require("../ai/messages");
const ai = require("../ai");
const openai = require("../ai/providers/openai");
const anthropic = require("../ai/providers/anthropic");

function sseBody(text) {
  const enc = new TextEncoder();
  // 경계가 이벤트 중간에 걸리도록 일부러 잘게 쪼갠다.
  const bytes = enc.encode(text);
  const parts = [];
  for (let i = 0; i < bytes.length; i += 7) parts.push(bytes.slice(i, i + 7));
  return (async function* () {
    for (const p of parts) yield p;
  })();
}

function fakeDb(data) {
  return {
    doc: () => ({
      get: async () => ({ exists: data != null, data: () => data }),
    }),
  };
}

test("구 Gemini 형식과 중립 형식 히스토리를 모두 받는다", () => {
  const out = normalizeHistory([
    { role: "user", parts: [{ text: "안녕" }] },
    { role: "model", parts: [{ text: "네" }, { text: "!" }] },
    { role: "assistant", text: "중립" },
    { role: "user", text: "" },
    null,
  ]);
  assert.deepStrictEqual(out, [
    { role: "user", text: "안녕" },
    { role: "assistant", text: "네!" },
    { role: "assistant", text: "중립" },
  ]);
});

test("config/ai 검증 — 잘못된 값은 기본값으로", () => {
  assert.deepStrictEqual(ai.sanitize(null), ai.DEFAULT);
  assert.deepStrictEqual(ai.sanitize({ provider: "없는회사", model: "x" }), ai.DEFAULT);
  // 회사만 바꾸고 모델을 비우면 Gemini 모델명이 다른 회사로 가므로 기본값
  assert.deepStrictEqual(ai.sanitize({ provider: "openai" }), ai.DEFAULT);
  assert.deepStrictEqual(ai.sanitize({ provider: "openai", model: " gpt-x " }), {
    provider: "openai",
    model: "gpt-x",
  });
  assert.strictEqual(
    ai.sanitize({ provider: "openai", model: "m", baseUrl: "http://평문" }).baseUrl,
    undefined
  );
});

test("OpenAI 스트리밍 파싱", async () => {
  process.env.OPENAI_API_KEY = "test";
  let sentBody;
  global.fetch = async (url, init) => {
    sentBody = JSON.parse(init.body);
    return {
      ok: true,
      body: sseBody(
        'data: {"choices":[{"delta":{"content":"안"}}]}\n\n' +
          'data: {"choices":[{"delta":{}}]}\n\n' +
          'data: {"choices":[{"delta":{"content":"녕"}}]}\n\n' +
          "data: [DONE]\n\n"
      ),
    };
  };
  const pieces = [];
  const text = await openai.generate({
    model: "m",
    system: "sys",
    messages: [{ role: "user", text: "hi" }],
    temperature: 0.7,
    maxTokens: 10,
    onChunk: async (p) => pieces.push(p),
  });
  assert.strictEqual(text, "안녕");
  assert.deepStrictEqual(pieces, ["안", "녕"]);
  assert.deepStrictEqual(sentBody.messages[0], { role: "system", content: "sys" });
  assert.strictEqual(sentBody.stream, true);
});

test("Anthropic 스트리밍 파싱 + 역할 정리", async () => {
  process.env.ANTHROPIC_API_KEY = "test";
  let sentBody;
  global.fetch = async (url, init) => {
    sentBody = JSON.parse(init.body);
    return {
      ok: true,
      body: sseBody(
        'event: message_start\ndata: {"type":"message_start"}\n\n' +
          'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"하"}}\n\n' +
          'event: ping\ndata: {"type":"ping"}\n\n' +
          'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"이"}}\n\n' +
          'event: message_stop\ndata: {"type":"message_stop"}\n\n'
      ),
    };
  };
  const text = await anthropic.generate({
    model: "m",
    system: "sys",
    messages: [
      { role: "assistant", text: "앞에 온 봇 말" },
      { role: "user", text: "a" },
      { role: "user", text: "b" },
    ],
    maxTokens: 10,
    onChunk: async () => {},
  });
  assert.strictEqual(text, "하이");
  assert.strictEqual(sentBody.system, "sys");
  assert.deepStrictEqual(sentBody.messages, [{ role: "user", content: "a\n\nb" }]);
  assert.strictEqual("temperature" in sentBody, false); // undefined는 안 보냄
});

test("선택한 회사가 첫 조각 전에 실패하면 기본 모델로 재시도", async () => {
  ai._resetCacheForTest();
  const realOpenai = ai.PROVIDERS.openai.generate;
  const realGemini = ai.PROVIDERS["vertex-gemini"].generate;
  const calls = [];
  ai.PROVIDERS.openai.generate = async (r) => {
    calls.push(["openai", r.model]);
    throw new Error("키 없음");
  };
  ai.PROVIDERS["vertex-gemini"].generate = async (r) => {
    calls.push(["gemini", r.model, r.messages.length]);
    return "대체 답변";
  };
  try {
    const out = await ai.generate({
      db: fakeDb({ provider: "openai", model: "gpt-x" }),
      mode: "chat",
      prompt: "질문",
      history: [{ role: "model", parts: [{ text: "이전" }] }],
    });
    assert.strictEqual(out.text, "대체 답변");
    assert.strictEqual(out.fellBack, true);
    assert.deepStrictEqual(calls, [
      ["openai", "gpt-x"],
      ["gemini", ai.DEFAULT.model, 2],
    ]);
  } finally {
    ai.PROVIDERS.openai.generate = realOpenai;
    ai.PROVIDERS["vertex-gemini"].generate = realGemini;
    ai._resetCacheForTest();
  }
});

test("조각을 이미 보냈으면 재시도하지 않는다 (답변 섞임 방지)", async () => {
  ai._resetCacheForTest();
  const realOpenai = ai.PROVIDERS.openai.generate;
  ai.PROVIDERS.openai.generate = async (r) => {
    await r.onChunk("일부");
    throw new Error("중간 끊김");
  };
  try {
    await assert.rejects(
      ai.generate({
        db: fakeDb({ provider: "openai", model: "gpt-x" }),
        mode: "chat",
        prompt: "q",
        onChunk: async () => {},
      }),
      /중간 끊김/
    );
  } finally {
    ai.PROVIDERS.openai.generate = realOpenai;
    ai._resetCacheForTest();
  }
});

test("generate 모드는 히스토리를 무시한다", async () => {
  ai._resetCacheForTest();
  const real = ai.PROVIDERS["vertex-gemini"].generate;
  let got;
  ai.PROVIDERS["vertex-gemini"].generate = async (r) => {
    got = r;
    return "ok";
  };
  try {
    await ai.generate({
      db: fakeDb(null),
      mode: "generate",
      prompt: "p",
      history: [{ role: "user", text: "무시" }],
    });
    assert.deepStrictEqual(got.messages, [{ role: "user", text: "p" }]);
    assert.strictEqual(got.maxTokens, 4096);
  } finally {
    ai.PROVIDERS["vertex-gemini"].generate = real;
    ai._resetCacheForTest();
  }
});
