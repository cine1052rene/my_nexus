import '../../../core/constants/app_constants.dart';
import 'chat_date_range.dart';
import 'chat_query.dart';
import 'chat_query_vocab.dart';

/// 자연어 질문 → [ChatQuery] 변환기.
///
/// 규칙 기반(패턴 매칭)이라 네트워크 호출도, 비용도 없다.
/// **오탐이 정탐보다 나쁘다**는 원칙으로 설계했다 — 애매하면
/// [QueryAction.unknown]을 반환해 LLM에게 넘긴다. 일반 대화
/// ("파이썬 공부하는 법 알려줘")를 링크 조회로 오인하면 안 되기 때문.
class ChatQueryParser {
  ChatQueryParser._();

  // ── 카테고리 별칭 ──────────────────────────────────────────
  static const Map<String, List<String>> _categoryAliases = {
    'youtube': ['유튜브', '유툽', '윺튜브', '유트브', 'youtube', 'yt'],
    'instagram': ['인스타그램', '인스타', 'instagram', 'insta', 'ig'],
    'threads': ['쓰레드', '스레드', 'threads', 'thread'],
    'tiktok': ['틱톡', 'tiktok', 'tik tok'],
    'facebook': ['페이스북', '페북', 'facebook', 'fb'],
    'twitter': ['트위터', '트윗', 'twitter'],
    'naver': ['네이버', 'naver'],
    'etc': ['기타', '그 외', '그외'],
  };

  /// "링크에 관한 질문"임을 알리는 신호어.
  /// 이게 없고 카테고리도 없으면 로컬 처리하지 않는다.
  static const List<String> _linkNouns = [
    '링크',
    '저장',
    '북마크',
    '자료',
    '콘텐츠',
    '컨텐츠',
    '영상',
    '동영상',
    '글',
    '포스트',
    '게시물',
    'db허브',
    '디비허브',
    '허브',
    'url',
    '주소',
  ];

  // ── 동작 신호어 ────────────────────────────────────────────
  static const List<String> _countWords = [
    '몇 개',
    '몇개',
    '몇건',
    '몇 건',
    '개수',
    '갯수',
    '얼마나',
    '총 몇',
  ];
  static const List<String> _summaryWords = [
    '요약',
    '정리해',
    '정리 해',
    '설명해',
    '간추려',
    '브리핑',
    '알기 쉽게',
  ];
  static const List<String> _recentWords = [
    '최근',
    '최신',
    '요즘',
    '마지막',
    '근래',
    '새로 저장',
  ];
  static const List<String> _searchWords = [
    '찾아',
    '검색',
    '관련',
    '관한',
    '에 대한',
    '대해',
    '추천',
  ];
  static const List<String> _listWords = [
    '목록',
    '리스트',
    '보여',
    '알려',
    '나열',
    '뭐 있',
    '뭐있',
    '무엇이 있',
    '어떤 게',
    '어떤게',
    '다 보여',
    '전부',
  ];

  /// 그 자체로 "나열해달라"는 뜻이 분명한 표현.
  /// 카테고리·주제 필터가 없어도 로컬 목록 조회로 인정한다.
  static const List<String> _strongListWords = [
    '목록',
    '리스트',
    '나열',
    '전부',
    '다 보여',
    '뭐 있',
    '뭐있',
    '무엇이 있',
  ];

  /// 키워드 추출 시 제거할 조사·어미
  static const List<String> _particles = [
    '은',
    '는',
    '이',
    '가',
    '을',
    '를',
    '의',
    '에',
    '도',
    '만',
    '과',
    '와',
    '랑',
    '으로',
    '로',
    '에서',
    '한테',
    '까지',
    '부터',
  ];

  /// 키워드로 쓸모없는 일반어
  static const List<String> _stopWords = [
    '내가',
    '나의',
    '우리',
    '거기',
    '그거',
    '이거',
    '저거',
    '것',
    '거',
    '좀',
    '한번',
    '다시',
    '그리고',
    '근데',
    '그럼',
    '해줘',
    '해 줘',
    '주세요',
    '알려줘',
    '보여줘',
    '뭐야',
    '뭐가',
    '있어',
    '있나',
    '있는',
    '해봐',
    '해',
    '줘',
    '중에',
    '중',
    '그중',
    '정도',
    '개만',
    '개',
    '뭐',
    '어떤',
    '어떻게',
    '있는지',
    '했는지',
    '한거',
    '한 거',
  ];

  /// 토큰 끝의 활용 어미. 이걸 떼지 않으면 "몇 개 저장했어?"의 '했어'가
  /// 검색 키워드로 잡혀 결과가 0건이 된다.
  static const List<String> _verbEndings = [
    '했는지',
    '하는지',
    '인지',
    '일까',
    '인가',
    '건가',
    '거야',
    '나요',
    '했어',
    '했나',
    '했지',
    '했음',
    '있어',
    '있나',
    '없어',
    '없나',
    '하는',
    '이야',
    '예요',
    '에요',
    '세요',
    '봐줘',
    '했',
    '한',
    '해',
    '야',
    '봐',
    '줘',
  ];

  /// 질문을 파싱한다. 로컬 처리가 부적절하면 [ChatQuery.unknown] 반환.
  /// [now]는 "지난주" 같은 날짜 해석 기준(테스트용).
  static ChatQuery parse(String raw, {DateTime? now}) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return ChatQuery.unknown;

    // 날짜 표현은 기간으로 떼어내고, 나머지 문장(body)으로 키워드를 뽑는다
    final dateMatch = ChatDateParser.parse(text, now: now);
    final range = dateMatch?.range;
    final body = dateMatch?.rest ?? text;

    final platform = _findCategory(body);
    final hasLinkNoun = _linkNouns.any((n) => text.contains(n));
    final wantsInterests = _containsAny(text, kInterestWords);

    // ── 게이트: 링크 문맥이 확인되지 않으면 LLM에게 넘긴다 ──
    // "요리 잘하는 법 알려줘" 같은 일반 질문을 가로채지 않기 위함.
    if (platform == null && !hasLinkNoun && !wantsInterests) {
      return ChatQuery.unknown;
    }

    // ── 관심 분포 리포트 (기간 없으면 최근 7일) ──
    if (wantsInterests) {
      return ChatQuery(
        action: QueryAction.interests,
        categoryId: platform?.id,
        range: range,
      );
    }

    var action = _detectAction(text);
    // "최근 7일"처럼 기간이 있으면 5개만 보여주는 '최근'이 아니라 기간 내 전체 목록
    if (range != null && action == QueryAction.recent) {
      action = QueryAction.list;
    }

    // ── 플랫폼 이름 = 저장 출처인가, 내용의 주제인가 ──
    // "유튜브 관련 링크 정리해줘" → 유튜브 운영·제작에 관한 링크(주제)
    // "지난주 유튜브에서 저장한 링크" → 유튜브 카테고리(출처)
    String? categoryId;
    String? subjectId;
    if (platform != null) {
      final after = body.substring(platform.end);
      final subjectAfter = kSubjectWords.any(
        (w) => after.trimLeft().startsWith(w),
      );
      final canBeSubject = platform.id != 'etc';
      if (canBeSubject && subjectAfter) {
        subjectId = platform.id;
      } else if (kSourceAfter.hasMatch(after) || range != null) {
        categoryId = platform.id;
      } else if (canBeSubject &&
          (action == QueryAction.summarize || action == QueryAction.search)) {
        subjectId = platform.id;
      } else {
        categoryId = platform.id;
      }
    }

    // 주제 모드에서는 '운영·관리' 같은 표지어를 검색 조건으로 쓰지 않는다
    var work = body;
    if (subjectId != null) {
      final sorted = [...kSubjectWords]
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final w in sorted) {
        work = work.replaceAll(w, ' ');
      }
    }

    final topicId = _detectTopic(work);
    final limit = _detectLimit(work);
    final keywords = _extractKeywords(work, platform?.id, topicId);
    final hasFilter =
        categoryId != null ||
        subjectId != null ||
        topicId != null ||
        keywords.isNotEmpty ||
        range != null;

    // ── 2차 게이트: 조건 없는 약한 매칭은 LLM에게 넘긴다 ──
    // "링크 저장하는 법 알려줘"의 '알려'가 목록 요청으로 오인되면 안 된다.
    if (action == QueryAction.list &&
        !hasFilter &&
        !_containsAny(text, _strongListWords)) {
      return ChatQuery.unknown;
    }
    // 검색은 무엇을 찾을지가 있어야 성립한다
    if (action == QueryAction.search && !hasFilter) return ChatQuery.unknown;

    return ChatQuery(
      action: action,
      categoryId: categoryId,
      topicId: topicId,
      keywords: keywords,
      limit: limit,
      range: range,
      subjectId: subjectId,
    );
  }

  // ── 동작 판별 ──────────────────────────────────────────────
  // 우선순위: 개수 → 요약 → 최근 → 검색 → 목록
  // (필터는 executor가 동작과 무관하게 적용하므로 겹쳐도 무해)
  static QueryAction _detectAction(String text) {
    if (_containsAny(text, _countWords)) return QueryAction.count;
    if (_containsAny(text, _summaryWords)) return QueryAction.summarize;
    if (_containsAny(text, _recentWords)) return QueryAction.recent;
    if (_containsAny(text, _searchWords)) return QueryAction.search;
    if (_containsAny(text, _listWords)) return QueryAction.list;

    // 신호어가 없어도 "유튜브 링크" 처럼 명사구만 던진 경우는 목록으로 본다
    return QueryAction.list;
  }

  // ── 카테고리 감지 ──────────────────────────────────────────
  /// '전체/모든'이 붙어도 특정 카테고리가 언급됐으면 그쪽이 우선이고,
  /// 아니면 null(= 전체)이 되므로 별도 분기가 필요 없다.
  static ({String id, int end})? _findCategory(String text) {
    // 긴 별칭부터 검사해야 '인스타그램'이 '인스타'로 잘리지 않음
    for (final e in _categoryAliases.entries) {
      final aliases = [...e.value]
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final alias in aliases) {
        final end = _tokenEnd(text, alias);
        if (end != null) return (id: e.key, end: end);
      }
    }
    return null;
  }

  /// [_matchToken]과 같은 규칙으로 찾고, 찾은 위치의 끝 인덱스를 돌려준다
  static int? _tokenEnd(String text, String token) {
    if (!_matchToken(text, token)) return null;
    final isShortAscii =
        token.length <= 3 && RegExp(r'^[a-z0-9 ]+$').hasMatch(token);
    if (!isShortAscii) return text.indexOf(token) + token.length;
    final m = RegExp(
      '(^|[^a-z0-9])${RegExp.escape(token)}(?=[^a-z0-9]|\$)',
    ).firstMatch(text)!;
    return m.end;
  }

  // ── 주제 감지 (YoutubeKeyword 패턴 재사용) ─────────────────
  static String? _detectTopic(String text) {
    for (final kw in YoutubeKeyword.all_list) {
      if (_matchToken(text, kw.label.toLowerCase())) return kw.id;
      for (final p in kw.patterns) {
        if (_matchToken(text, p.toLowerCase())) return kw.id;
      }
    }
    return null;
  }

  /// 짧은 알파벳 패턴('ai', 'yt', 'mv')은 단어 경계를 요구한다.
  /// 그냥 contains로 하면 'email'이 'ai'에, 'python'이 'yt'에 걸린다.
  static bool _matchToken(String text, String token) {
    if (token.isEmpty) return false;
    final isShortAscii =
        token.length <= 3 && RegExp(r'^[a-z0-9 ]+$').hasMatch(token);
    if (!isShortAscii) return text.contains(token);
    final escaped = RegExp.escape(token);
    return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)').hasMatch(text);
  }

  static bool _containsAny(String text, List<String> words) =>
      words.any((w) => text.contains(w));

  // ── 개수 지정 감지 ("5개만", "3개 보여줘") ──────────────────
  static int? _detectLimit(String text) {
    final m = RegExp(r'(\d+)\s*(개|건)').firstMatch(text);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    if (n == null || n <= 0) return null;
    return n.clamp(1, 50);
  }

  // ── 자유 키워드 추출 ───────────────────────────────────────
  static List<String> _extractKeywords(
    String text,
    String? categoryId,
    String? topicId,
  ) {
    var work = text;

    // 이미 구조화된 정보(카테고리/주제/동작어)는 키워드에서 제거
    if (categoryId != null) {
      for (final a in _categoryAliases[categoryId] ?? const <String>[]) {
        work = work.replaceAll(a, ' ');
      }
    }
    if (topicId != null) {
      final kw = YoutubeKeyword.all_list.firstWhere((k) => k.id == topicId);
      work = work.replaceAll(kw.label.toLowerCase(), ' ');
      for (final p in kw.patterns) {
        work = work.replaceAll(p.toLowerCase(), ' ');
      }
    }
    for (final w in [
      ..._countWords,
      ..._summaryWords,
      ..._recentWords,
      ..._searchWords,
      ..._listWords,
      ..._linkNouns,
      ..._stopWords,
    ]) {
      work = work.replaceAll(w, ' ');
    }
    work = work.replaceAll(
      RegExp(
        r'[?!.,~\-_/\\()\[\]{}"'
        "'"
        r']',
      ),
      ' ',
    );
    work = work.replaceAll(RegExp(r'\d+'), ' ');

    final tokens = work
        .split(RegExp(r'\s+'))
        .map(_stripParticle)
        .map(_stripVerbEnding)
        .where((t) => t.length >= 2)
        // "유튜브에서 수집한" → 별칭을 지우면 '에서', '수집'이 남는다 — 조건이 아님
        .where((t) => !_particles.contains(t) && !kSaveVerbs.contains(t))
        .toSet()
        .toList();

    // 너무 많으면 상위 3개만 (오탐 방지)
    return tokens.take(3).toList();
  }

  /// 토큰 끝의 활용 어미를 떼어낸다.
  /// 떼고 나서 2자 미만이면 내용어가 아니므로 빈 문자열로 만들어 버린다.
  /// ('했어' → '', '공부해' → '공부', '파이썬' → '파이썬')
  static String _stripVerbEnding(String token) {
    var t = token.trim();
    if (t.isEmpty) return t;
    final sorted = [..._verbEndings]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final e in sorted) {
      if (t.endsWith(e)) {
        final stem = t.substring(0, t.length - e.length);
        return stem.length >= 2 ? stem : '';
      }
    }
    return t;
  }

  /// 토큰 끝의 조사를 떼어낸다. ('파이썬을' → '파이썬')
  static String _stripParticle(String token) {
    var t = token.trim();
    if (t.length <= 2) return t;
    // 긴 조사부터 검사
    final sorted = [..._particles]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final p in sorted) {
      if (t.endsWith(p) && t.length - p.length >= 2) {
        return t.substring(0, t.length - p.length);
      }
    }
    return t;
  }
}
