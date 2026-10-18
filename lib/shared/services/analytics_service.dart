import 'package:firebase_analytics/firebase_analytics.dart';

/// 베타 검증용 사용 통계 (Google Analytics for Firebase).
///
/// 외부 검증 리포트의 핵심 미확인 가정 — "사람들이 계속 쓰는가,
/// 저장한 걸 실제로 다시 찾는가"를 숫자로 재기 위한 최소 이벤트만 남긴다.
/// 저장한 내용(URL·제목·메모·글자)은 **절대 보내지 않는다**. 종류와 횟수만.
///
/// 재방문(리텐션)은 Analytics가 기본 수집하는 first_open·session_start로 본다.
class AnalyticsService {
  AnalyticsService._();

  static final _a = FirebaseAnalytics.instance;

  static Future<void> _log(String name, Map<String, Object> params) async {
    try {
      await _a.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  /// 저장: type = link | memo | capture, via = share | manual
  static Future<void> itemSaved({required String type, required String via}) =>
      _log('item_saved', {'type': type, 'via': via});

  /// 항목 열기. fromSearch = 검색어가 있는 상태에서 열었는지 (= 다시 찾기 성공)
  static Future<void> itemOpened({
    required String type,
    required bool fromSearch,
  }) =>
      _log('item_opened', {'type': type, 'from_search': fromSearch ? 1 : 0});

  /// 챗봇 질문. local = 기기에서 처리됐는지
  static Future<void> chatQuery({required bool local, required int results}) =>
      _log('chat_query', {'local': local ? 1 : 0, 'results': results});
}
