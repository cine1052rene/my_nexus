// 회사 중립 대화 형식.
//
// 앱·서버 사이에는 특정 회사 형식을 쓰지 않는다.
//   { role: "user" | "assistant", text: "..." }
// 각 provider가 이 형식을 자기 API 형식으로 바꾼다.
// 그래야 모델 회사를 바꿔도 앱을 고칠 필요가 없다.
//
// 단, v3 이하 앱은 Gemini 형식({role:"user"|"model", parts:[{text}]})으로
// 보내므로 둘 다 받아서 중립 형식으로 맞춘다.

const MAX_TURNS = 40; // 비정상적으로 긴 히스토리 방어 (앱은 최근 10턴만 보냄)

function textOf(turn) {
  if (typeof turn.text === "string") return turn.text;
  if (Array.isArray(turn.parts)) {
    return turn.parts
      .map((p) => (p && typeof p.text === "string" ? p.text : ""))
      .join("");
  }
  return "";
}

function normalizeHistory(history) {
  if (!Array.isArray(history)) return [];
  const out = [];
  for (const turn of history) {
    if (!turn || typeof turn !== "object") continue;
    const role =
      turn.role === "model" || turn.role === "assistant" ? "assistant" : "user";
    const text = textOf(turn);
    if (!text) continue;
    out.push({ role, text });
  }
  return out.slice(-MAX_TURNS);
}

module.exports = { normalizeHistory };
