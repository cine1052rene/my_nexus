import '../ai_turn.dart';

/// 개인 API 키(BYOK)로 AI 회사에 직접 호출하는 방법.
///
/// 지금은 Gemini 키만 받는다([GeminiByok]). 다른 회사의 개인 키를 받으려면
/// 이 인터페이스를 구현한 클래스를 하나 추가하고 [ByokProviders]에 등록한 뒤,
/// 설정 화면에서 어느 회사 키인지 고르게 하면 된다.
abstract class ByokProvider {
  /// 저장값으로 쓰는 식별자 (예: 'gemini')
  String get id;

  /// 설정 화면에 보일 이름
  String get displayName;

  Future<String> generate({
    required String apiKey,
    required String prompt,
    required bool isChat,
    String? system,
    List<AiTurn> history = const [],
  });
}
