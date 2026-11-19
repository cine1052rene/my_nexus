import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_turn.dart';
import 'byok/byok_provider.dart';
import 'byok/gemini_byok.dart';

/// 앱 전체가 쓰는 AI 단일 입구. **화면 코드는 이 클래스만 부를 것.**
///
/// - 개인 키 없음: 서버 함수 경유 (무료 한도 적용). 어느 회사·모델인지는
///   서버가 Firestore `config/ai`로 정하므로 앱은 모른다 → 회사를 바꿔도 앱 업데이트 불필요.
/// - 개인 키 있음: [ByokProviders.current]로 직접 호출 (앱 한도 없음,
///   해당 회사의 무료 등급 한도·본인 요금 적용).
///
/// 전환 절차·설정 형식은 functions/ai/README.md.
class AiService {
  AiService._();

  static const _keyPref = 'gemini_api_key';

  /// 챗봇 지시문. 서버(functions/index.js CHAT_SYSTEM_INSTRUCTION)와 같은 내용.
  /// 말풍선이 일반 Text라 마크다운 기호가 그대로 보이므로 금지한다.
  static const chatSystemInstruction =
      '당신은 간결하고 친절한 한국어 챗봇입니다. '
      '답변은 마크다운 없이 일반 문장으로 쓰세요. **, #, * 같은 기호를 쓰지 말고, '
      '목록이 필요하면 줄 앞에 "• "를 붙이세요.';

  // 함수 이름은 구버전 앱 호환을 위해 그대로 둔다 (실제로는 회사 무관).
  static final _callable =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3').httpsCallable(
    'callGemini',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );

  static Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref) ?? '';
    return key.isNotEmpty ? key : null;
  }

  static ByokProvider get _byok => ByokProviders.current;

  static List<Map<String, String>> _wire(List<AiTurn> history) =>
      [for (final t in history) t.toJson()];

  /// 일반 텍스트 생성 (큐레이션·이메일·요약 등)
  static Future<String> generate(String prompt) async {
    final apiKey = await _getApiKey();
    if (apiKey != null) {
      return _byok.generate(apiKey: apiKey, prompt: prompt, isChat: false);
    }
    final result = await _callable.call({'prompt': prompt, 'mode': 'generate'});
    return result.data['text'] as String;
  }

  /// 채팅 스트리밍 — 지금까지 받은 **누적 텍스트**를 계속 내보낸다.
  ///
  /// 서버 경로는 callable `stream()`으로 조각을 받아 바로 화면에 반영한다.
  /// BYOK 경로는 완성된 답변을 한 번에 내보낸다.
  static Stream<String> chatStream({
    required String prompt,
    required List<AiTurn> history,
  }) async* {
    final apiKey = await _getApiKey();
    if (apiKey != null) {
      yield await _byok.generate(
        apiKey: apiKey,
        prompt: prompt,
        isChat: true,
        system: chatSystemInstruction,
        history: history,
      );
      return;
    }

    final buffer = StringBuffer();
    await for (final event in _callable.stream<dynamic, dynamic>({
      'prompt': prompt,
      'history': _wire(history),
      'mode': 'chat',
    })) {
      switch (event) {
        case Chunk(:final partialData):
          final piece = partialData is Map ? partialData['text'] : null;
          if (piece is String && piece.isNotEmpty) {
            buffer.write(piece);
            yield buffer.toString();
          }
        case Result(:final result):
          // 최종 결과가 기준이다 — 조각이 일부 유실됐더라도 완성본으로 맞춘다.
          final data = result.data;
          final text = data is Map ? data['text'] : null;
          if (text is String && text != buffer.toString()) yield text;
      }
    }
  }

  /// 개인 키 유효성 검사 (짧은 테스트 호출)
  static Future<bool> validateApiKey(String apiKey) async {
    try {
      await _byok.generate(apiKey: apiKey, prompt: 'hi', isChat: false);
      return true;
    } catch (_) {
      return false;
    }
  }
}
