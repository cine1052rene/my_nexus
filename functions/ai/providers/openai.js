// OpenAI Chat Completions — 그리고 같은 형식을 쓰는 호환 API
// (예: 다른 회사의 "OpenAI 호환" 엔드포인트는 config/ai.baseUrl로 바꿔 끼운다)
//
// 키: Secret Manager의 OPENAI_API_KEY (활성화 절차는 functions/ai/README.md)
// ⚠️ 2026-11-19 작성 시점에 실제 키로 호출해 보지 않았다. 켜기 전에
//    README의 "전환 전 실측" 절차로 반드시 한 번 호출해 볼 것.

const { readSse, httpError } = require("./sse");

const DEFAULT_BASE_URL = "https://api.openai.com/v1";

function toMessages(system, messages) {
  const out = [];
  if (system) out.push({ role: "system", content: system });
  for (const m of messages) out.push({ role: m.role, content: m.text });
  return out;
}

async function generate(req) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("OPENAI_API_KEY 시크릿이 연결되지 않았습니다");
  const baseUrl = (req.baseUrl || DEFAULT_BASE_URL).replace(/\/$/, "");

  const body = {
    model: req.model,
    messages: toMessages(req.system, req.messages),
    temperature: req.temperature,
    max_completion_tokens: req.maxTokens,
    stream: Boolean(req.onChunk),
  };

  const res = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw await httpError("openai", res);

  if (!req.onChunk) {
    const data = await res.json();
    return data?.choices?.[0]?.message?.content || "";
  }

  let text = "";
  for await (const ev of readSse(res.body)) {
    if (ev.data === "[DONE]") break;
    let json;
    try {
      json = JSON.parse(ev.data);
    } catch (_) {
      continue;
    }
    const piece = json?.choices?.[0]?.delta?.content;
    if (!piece) continue;
    text += piece;
    await req.onChunk(piece);
  }
  return text;
}

module.exports = { id: "openai", secret: "OPENAI_API_KEY", generate, toMessages };
