/// 대화 한 턴 — 특정 AI 회사 형식이 아닌 중립 형식.
///
/// 앱 → 서버로 보낼 때 `{role: 'user'|'assistant', text}`로 직렬화한다.
/// 회사별 형식(Gemini의 `model`/`parts` 등) 변환은 서버 provider와
/// BYOK provider가 각자 맡는다. 그래서 모델 회사가 바뀌어도 이 형식은 그대로다.
class AiTurn {
  final bool isUser;
  final String text;

  const AiTurn.user(this.text) : isUser = true;
  const AiTurn.assistant(this.text) : isUser = false;

  Map<String, String> toJson() => {
        'role': isUser ? 'user' : 'assistant',
        'text': text,
      };
}
