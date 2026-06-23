import 'package:cloud_functions/cloud_functions.dart';

/// Firebase Functions를 통한 Gemini AI 중앙 서비스
/// - 구글 로그인된 사용자는 API 키 없이 바로 사용
/// - Firestore users/{uid}.isPremium = true 이면 프리미엄 적용
class GeminiService {
  static final _callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
      .httpsCallable(
    'callGemini',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );

  /// 일반 텍스트 생성 (큐레이션·이메일·요약 등)
  static Future<String> generate(String prompt) async {
    final result = await _callable.call({
      'prompt': prompt,
      'mode': 'generate',
    });
    return result.data['text'] as String;
  }

  /// 채팅 메시지 전송 (이전 대화 히스토리 포함)
  /// [history] 형식: [{'role':'user','parts':[{'text':'...'}]}, ...]
  static Future<String> chat({
    required String prompt,
    required List<Map<String, dynamic>> history,
  }) async {
    final result = await _callable.call({
      'prompt': prompt,
      'history': history,
      'mode': 'chat',
    });
    return result.data['text'] as String;
  }
}
