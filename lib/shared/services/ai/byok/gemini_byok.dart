import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_config.dart';
import '../ai_turn.dart';
import 'byok_provider.dart';

/// 사용자의 Google AI Studio(Gemini API) 키로 직접 호출.
/// 모델명은 `config/ai.byokModel`(없으면 [AiConfig.fallbackByokModel]).
class GeminiByok implements ByokProvider {
  const GeminiByok({http.Client? client}) : _client = client;
  final http.Client? _client;

  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  /// 요청 본문 — 테스트에서 형식을 확인할 수 있게 분리했다.
  static Map<String, dynamic> buildBody({
    required String prompt,
    required bool isChat,
    String? system,
    List<AiTurn> history = const [],
  }) {
    final body = <String, dynamic>{
      'contents': [
        for (final t in history)
          {
            'role': t.isUser ? 'user' : 'model',
            'parts': [
              {'text': t.text}
            ],
          },
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ],
        },
      ],
      'generationConfig': {
        'temperature': isChat ? 0.7 : 0.9,
        'maxOutputTokens': isChat ? 2048 : 4096,
        // 서버 경로와 동일하게 thinking 토큰을 끈다 (출력 단가로 과금됨).
        'thinkingConfig': {'thinkingBudget': 0},
      },
    };
    if (system != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': system}
        ],
      };
    }
    return body;
  }

  /// 응답에서 텍스트만 꺼낸다. 여러 조각이면 이어 붙인다.
  static String parseText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Gemini 응답에 답변이 없어요');
    }
    final parts = (candidates.first as Map)['content']?['parts'];
    if (parts is! List) return '';
    return parts
        .map((p) => p is Map && p['text'] is String ? p['text'] as String : '')
        .join();
  }

  @override
  Future<String> generate({
    required String apiKey,
    required String prompt,
    required bool isChat,
    String? system,
    List<AiTurn> history = const [],
  }) async {
    final model = await AiConfig.byokModel();
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final body = buildBody(
        prompt: prompt, isChat: isChat, system: system, history: history);

    // 키는 URL 쿼리(?key=)가 아니라 헤더로 보낸다.
    // ① Google 공식 문서가 안내하는 방식이 x-goog-api-key다.
    // ② URL은 로그·프록시·크래시 리포트에 그대로 남는다.
    final post = _client?.post ?? http.post;
    final res = await post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('Gemini API 오류 (${res.statusCode}): ${res.body}');
    }
    return parseText(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

/// 등록된 BYOK 회사 목록. 새 회사는 여기에 추가한다.
class ByokProviders {
  ByokProviders._();

  static const ByokProvider gemini = GeminiByok();

  /// 지금은 저장된 키가 전부 Gemini 키다 (설정 화면에 회사 선택이 없음).
  static ByokProvider get current => gemini;
}
