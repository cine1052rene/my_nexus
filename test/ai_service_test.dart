import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/shared/services/ai/ai_turn.dart';
import 'package:my_nexus/shared/services/ai/byok/gemini_byok.dart';

void main() {
  test('서버로 보내는 히스토리는 회사 중립 형식', () {
    expect(const AiTurn.user('a').toJson(), {'role': 'user', 'text': 'a'});
    expect(const AiTurn.assistant('b').toJson(),
        {'role': 'assistant', 'text': 'b'});
  });

  test('Gemini BYOK 요청 본문 — 히스토리 변환·지시문·thinking 끔', () {
    final body = GeminiByok.buildBody(
      prompt: '질문',
      isChat: true,
      system: '지시',
      history: const [AiTurn.user('안녕'), AiTurn.assistant('네')],
    );
    final contents = body['contents'] as List;
    expect(contents.map((c) => c['role']), ['user', 'model', 'user']);
    expect(contents.last['parts'][0]['text'], '질문');
    expect(body['systemInstruction']['parts'][0]['text'], '지시');
    expect(body['generationConfig']['thinkingConfig']['thinkingBudget'], 0);
    expect(body['generationConfig']['maxOutputTokens'], 2048);
  });

  test('생성 모드는 지시문 없음', () {
    final body = GeminiByok.buildBody(prompt: 'p', isChat: false);
    expect(body.containsKey('systemInstruction'), false);
    expect(body['generationConfig']['maxOutputTokens'], 4096);
  });

  test('Gemini 응답 파싱 — 여러 조각 이어 붙이기, 빈 응답은 오류', () {
    expect(
      GeminiByok.parseText({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '안'},
                {'text': '녕'}
              ]
            }
          }
        ]
      }),
      '안녕',
    );
    expect(() => GeminiByok.parseText({'candidates': []}), throwsException);
  });
}
