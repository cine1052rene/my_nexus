// Anthropic Claude Messages API
//
// 키: Secret Manager의 ANTHROPIC_API_KEY (활성화 절차는 functions/ai/README.md)
// ⚠️ 2026-11-19 작성 시점에 실제 키로 호출해 보지 않았다. 켜기 전에
//    README의 "전환 전 실측" 절차로 반드시 한 번 호출해 볼 것.

const { readSse, httpError } = require("./sse");

const BASE_URL = "https://api.anthropic.com/v1";
const API_VERSION = "2023-06-01";

// Claude는 대화가 user로 시작하고 user/assistant가 번갈아야 한다.
// 같은 역할이 연속되면 하나로 합친다.
function toMessages(messages) {
  const out = [];
  for (const m of messages) {
    const last = out[out.length - 1];
    if (last && last.role === m.role) {
      last.content += "\n\n" + m.text;
    } else {
      out.push({ role: m.role, content: m.text });
    }
  }
  while (out.length && out[0].role !== "user") out.shift();
  return out;
}

async function generate(req) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY 시크릿이 연결되지 않았습니다");

  const body = {
    model: req.model,
    max_tokens: req.maxTokens,
    temperature: req.temperature,
    messages: toMessages(req.messages),
    stream: Boolean(req.onChunk),
  };
  if (req.system) body.system = req.system;

  const res = await fetch(`${BASE_URL}/messages`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": API_VERSION,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw await httpError("anthropic", res);

  if (!req.onChunk) {
    const data = await res.json();
    return (data?.content || [])
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join("");
  }

  let text = "";
  for await (const ev of readSse(res.body)) {
    if (ev.event === "error") throw new Error(`anthropic stream: ${ev.data}`);
    if (ev.event !== "content_block_delta") continue;
    let json;
    try {
      json = JSON.parse(ev.data);
    } catch (_) {
      continue;
    }
    const piece = json?.delta?.type === "text_delta" ? json.delta.text : null;
    if (!piece) continue;
    text += piece;
    await req.onChunk(piece);
  }
  return text;
}

module.exports = {
  id: "anthropic",
  secret: "ANTHROPIC_API_KEY",
  generate,
  toMessages,
};
