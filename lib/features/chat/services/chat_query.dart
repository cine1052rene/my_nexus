/// 챗봇 질문을 로컬에서 처리하기 위한 의도(intent) 모델.
///
/// 사용자의 DB허브 관련 질문 대부분은 "목록/개수/필터/최근"처럼
/// 단순 조회라 LLM이 필요 없다. 이 모델은 자연어 질문을
/// 로컬 Dart 쿼리로 변환하기 위한 중간 표현이다.
library;

import '../../hub/models/link_item.dart';

/// 질문이 요구하는 동작 유형
enum QueryAction {
  /// 조건에 맞는 링크 나열 — "유튜브 링크 보여줘"
  list,

  /// 개수만 응답 — "인스타 링크 몇 개야?"
  count,

  /// 최신순 나열 — "최근 저장한 거 뭐야?"
  recent,

  /// 키워드/주제 관련도 순 나열 — "요리 관련 링크 찾아줘"
  search,

  /// 요약·설명 요청 — 로컬로 링크를 추린 뒤 그 일부만 LLM에 전달
  summarize,

  /// 로컬 처리 불가 → 일반 LLM 대화로 폴백
  unknown,
}

/// 파싱된 질문
class ChatQuery {
  final QueryAction action;

  /// HubCategory.id (youtube/instagram/...) — null이면 전체
  final String? categoryId;

  /// YoutubeKeyword.id (yt_cooking/yt_tech/...) — null이면 주제 무관
  final String? topicId;

  /// 위 두 가지로 안 잡힌 자유 검색어
  final List<String> keywords;

  /// 사용자가 "5개만" 처럼 개수를 지정한 경우
  final int? limit;

  const ChatQuery({
    required this.action,
    this.categoryId,
    this.topicId,
    this.keywords = const [],
    this.limit,
  });

  static const unknown = ChatQuery(action: QueryAction.unknown);

  /// 네트워크 호출 없이 기기에서 완결 가능한가
  bool get isLocal =>
      action != QueryAction.unknown && action != QueryAction.summarize;

  /// LLM이 필요하지만, 전체가 아닌 추려진 링크만 넘기면 되는가
  bool get needsLlm => action == QueryAction.summarize;

  /// 카테고리·주제·키워드 중 하나라도 조건이 걸려 있는가
  bool get hasFilter =>
      categoryId != null || topicId != null || keywords.isNotEmpty;

  @override
  String toString() =>
      'ChatQuery(action: $action, category: $categoryId, topic: $topicId, '
      'keywords: $keywords, limit: $limit)';
}

/// 로컬 쿼리 실행 결과
class ChatQueryResult {
  /// 말풍선에 표시할 텍스트
  final String text;

  /// 텍스트 아래에 카드로 렌더링할 링크들
  final List<LinkItem> links;

  /// 조건에 맞는 전체 개수 (links는 limit으로 잘린 일부일 수 있음)
  final int totalMatched;

  const ChatQueryResult({
    required this.text,
    this.links = const [],
    this.totalMatched = 0,
  });

  bool get isEmpty => links.isEmpty;
}
