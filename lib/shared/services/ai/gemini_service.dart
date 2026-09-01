import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Gemini AI 중앙 서비스
/// - API 키 미설정: Firebase Functions (서버 Vertex AI, 무료 한도 적용)
///   한도 값은 Firestore `config/limits` 문서가 기준 — 여기 적지 말 것
/// - API 키 설정됨: Google AI Studio 직접 호출 (사용자 자체 쿼터, 무제한)
class GeminiService {
  static const _keyPref = 'gemini_api_key';

  /// 서버(Functions)의 Vertex AI 모델과 동일하게 유지할 것.
  /// 달라지면 BYOK 사용자만 다른 모델로 다른 품질의 답변을 받게 된다.
  static const _model = 'gemini-2.5-flash';
  static const _directUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static final _callable =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3').httpsCallable(
    'callGemini',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );

  /// 저장된 API 키 조회
  static Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref) ?? '';
    return key.isNotEmpty ? key : null;
  }

  /// Google AI Studio 직접 호출 (BYOK 경로)
  static Future<String> _directCall({
    required String prompt,
    required String mode,
    required String apiKey,
    List<Map<String, dynamic>>? history,
  }) async {
    final contents = <Map<String, dynamic>>[
      ...?history,
      {
        'role': 'user',
        'parts': [
          {'text': prompt}
        ],
      },
    ];

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': mode == 'chat' ? 0.7 : 0.9,
        'maxOutputTokens': mode == 'chat' ? 2048 : 4096,
      },
    };
    if (mode == 'chat') {
      body['systemInstruction'] = {
        'parts': [
          {'text': '당신은 간결하고 친절한 한국어 챗봇입니다.'}
        ],
      };
    }

    // 키는 URL 쿼리(?key=)가 아니라 헤더로 보낸다.
    // ① Google 공식 문서가 auth key에 대해 안내하는 방식이 x-goog-api-key다.
    //    2026-09부터 Gemini API가 구형 Standard 키를 전부 거부하므로,
    //    쿼리 파라미터 방식에 의존하면 조용히 깨질 수 있다.
    // ② URL은 로그·프록시·크래시 리포트에 그대로 남는다. 자격증명을
    //    쿼리스트링에 싣는 것 자체가 유출 경로다.
    final res = await http
        .post(
          Uri.parse(_directUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('Gemini API 오류 (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  /// 일반 텍스트 생성 (큐레이션·이메일·요약 등)
  static Future<String> generate(String prompt) async {
    final apiKey = await _getApiKey();
    if (apiKey != null) {
      return _directCall(prompt: prompt, mode: 'generate', apiKey: apiKey);
    }
    final result = await _callable.call({'prompt': prompt, 'mode': 'generate'});
    return result.data['text'] as String;
  }

  /// 채팅 메시지 전송 (이전 대화 히스토리 포함)
  /// [history] 형식: [{'role':'user','parts':[{'text':'...'}]}, ...]
  static Future<String> chat({
    required String prompt,
    required List<Map<String, dynamic>> history,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey != null) {
      return _directCall(
          prompt: prompt, mode: 'chat', apiKey: apiKey, history: history);
    }
    final result = await _callable.call({
      'prompt': prompt,
      'history': history,
      'mode': 'chat',
    });
    return result.data['text'] as String;
  }

  /// API 키 유효성 검사 (간단한 테스트 호출)
  static Future<bool> validateApiKey(String apiKey) async {
    try {
      await _directCall(
          prompt: 'hi', mode: 'generate', apiKey: apiKey);
      return true;
    } catch (_) {
      return false;
    }
  }
}
