# AI 회사·모델 전환 안내

챗봇·요약 등 모든 AI 호출은 `callGemini` 함수 하나를 거친다 (이름은 구버전 앱 호환용, 실제로는 회사 무관).
어느 회사·모델을 쓸지는 **Firestore `config/ai` 문서**가 정한다. 앱은 회사를 모른다.

| 바꾸려는 것 | 필요한 작업 | 앱 업데이트 |
|---|---|---|
| 같은 회사 안에서 모델만 (예: Gemini 3.1 → 3.6) | `config/ai.model` 수정 (1분 내 반영) | 불필요 |
| 이미 구현된 다른 회사 (OpenAI·Anthropic) | 시크릿 등록 → 배포 1회 → `config/ai` 수정 | 불필요 |
| 새 회사 추가 | `providers/새회사.js` 1개 작성 + `ai/index.js` 등록 → 배포 | 불필요 |
| 개인 키(BYOK) 사용자의 모델 | `config/ai.byokModel` 수정 | 불필요 (Gemini 키인 동안) |

## config/ai 문서 형식

```
provider:        "vertex-gemini" | "openai" | "anthropic"
model:           "gemini-3.1-flash-lite"
baseUrl:         (선택) OpenAI 호환 API 주소, https만 허용
sendTemperature: (선택) false — temperature를 거부하는 모델일 때
byokModel:       (선택) 개인 Gemini 키 사용자가 쓸 모델. 없으면 앱 기본값
```

- 문서가 없거나 값이 이상하면 기본값(`vertex-gemini` / `gemini-3.1-flash-lite`)으로 동작한다.
- 회사만 바꾸고 `model`을 비우면 기본값으로 돌아간다 (다른 회사에 Gemini 모델명을 보내지 않도록).
- 선택한 회사 호출이 실패하면 기본 모델로 자동 재시도하고 로그에 `event: "ai_fallback"`을 남긴다.
- ⚠️ `config/*`는 로그인 사용자 누구나 읽을 수 있다. **API 키를 여기에 넣지 말 것.**

## 다른 회사로 바꾸는 순서 (예: OpenAI)

1. 키 등록: `npx firebase functions:secrets:set OPENAI_API_KEY`
2. `functions/index.js`의 `ENABLED_AI_SECRETS`에 `"OPENAI_API_KEY"` 추가 → `npx firebase deploy --only functions:callGemini`
3. **전환 전 실측** (아래) — 실제 호출이 되는지, 한국어 답이 괜찮은지, 응답 속도
4. 콘솔에서 `config/ai`를 `{provider:"openai", model:"..."}`로 수정 → 1분 내 전 사용자 반영
5. Cloud Logging에서 `jsonPayload.event="callGemini_timing"`의 `provider`·`fellBack` 확인
   (`fellBack: true`가 보이면 새 회사 호출이 실패해 Gemini로 대체 중이라는 뜻)
6. 개인정보처리방침의 AI 위탁처(5항)에 새 회사 추가 — **전환 전에** 배포할 것

되돌리기: `config/ai` 문서를 지우거나 provider를 `vertex-gemini`로.

## 전환 전 실측

OpenAI·Anthropic 코드는 2026-11-19 작성 시 **실제 키로 호출해 보지 않았다** (요청·스트리밍 파싱은 `npm test`로 검증).
켜기 전에 함수 E2E 테스트 방법(MEMORY.md "함수 E2E 테스트 방법")으로 테스트 계정에서
config를 잠깐 바꿔 일반·스트리밍 호출을 각각 1번씩 해 볼 것.

## 새 회사 추가

`providers/openai.js`를 본떠 `generate(req)`를 구현한다.
- 입력: `{model, system, messages:[{role:"user"|"assistant", text}], temperature, maxTokens, onChunk?}`
- `onChunk`가 있으면 조각마다 `await onChunk(piece)` 호출, 반환값은 전체 텍스트
- `module.exports = { id, secret: "키_시크릿_이름" | null, generate }`
- `ai/index.js`의 `PROVIDERS`에 등록, `test/ai.test.js`에 파싱 테스트 추가

## 앱 쪽 (lib/shared/services/ai/)

- `ai_service.dart` — 앱 전체가 쓰는 단일 입구 (`AiService.generate/chat/chatStream`)
- `byok/` — 개인 키 직접 호출. 지금은 Gemini 키만 지원 (`gemini_byok.dart`).
  다른 회사 개인 키를 받으려면 `ByokProvider`를 구현하고 설정 화면에 선택지를 추가 (앱 업데이트 필요)
- 앱 → 서버 대화 형식은 회사 중립 `{role:"user"|"assistant", text}`
