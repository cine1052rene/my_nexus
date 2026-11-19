// Server-Sent Events 응답을 한 이벤트씩 읽는다 (OpenAI·Anthropic 공통).
// 이벤트는 빈 줄로 구분되고, 각 줄은 "event: ..." 또는 "data: ..." 형태다.

async function* readSse(body) {
  const decoder = new TextDecoder();
  let buf = "";
  for await (const chunk of body) {
    buf += decoder.decode(chunk, { stream: true });
    let idx;
    while ((idx = buf.search(/\r?\n\r?\n/)) !== -1) {
      const raw = buf.slice(0, idx);
      buf = buf.slice(idx).replace(/^\r?\n\r?\n/, "");
      const ev = parseEvent(raw);
      if (ev) yield ev;
    }
  }
  const tail = parseEvent(buf);
  if (tail) yield tail;
}

function parseEvent(raw) {
  let event = "message";
  const data = [];
  for (const line of raw.split(/\r?\n/)) {
    if (line.startsWith("event:")) event = line.slice(6).trim();
    else if (line.startsWith("data:")) data.push(line.slice(5).replace(/^ /, ""));
  }
  if (!data.length) return null;
  return { event, data: data.join("\n") };
}

/** HTTP 오류를 원인이 보이는 메시지로 바꾼다 (키 값은 절대 포함하지 않음). */
async function httpError(provider, res) {
  let detail = "";
  try {
    detail = (await res.text()).slice(0, 300);
  } catch (_) {
    /* 본문을 못 읽어도 상태 코드는 남긴다 */
  }
  return new Error(`${provider} HTTP ${res.status}: ${detail}`);
}

module.exports = { readSse, httpError };
