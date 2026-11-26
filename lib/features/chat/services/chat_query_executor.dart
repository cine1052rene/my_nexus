import '../../../core/constants/app_constants.dart';
import '../../hub/models/link_item.dart';
import 'chat_interest_report.dart';
import 'chat_query.dart';

/// [ChatQuery]를 실제 링크 목록에 적용하는 실행기.
///
/// 전부 메모리 상에서 처리한다 — 네트워크 호출 없음, 비용 0원,
/// 응답 지연 없음. 개수를 세거나 필터링하는 일은 LLM보다
/// 정확하기까지 하다(환각 불가).
class ChatQueryExecutor {
  ChatQueryExecutor._();

  static const int _defaultLimit = 10;
  static const int _recentLimit = 5;

  /// 기간을 지정한 목록은 그 기간 것을 넉넉히 보여준다
  static const int _rangeLimit = 30;

  /// AI 정리에 넘기는 최대 개수 (토큰·비용 상한)
  static const int _summarizeLimit = 20;

  /// 플랫폼을 '주제'로 물었을 때 찾을 말 — 운영·제작 쪽 용어 포함.
  /// 영문 이름은 같은 플랫폼 링크의 OG 문구("… on Instagram", "- YouTube")에
  /// 늘 들어 있으므로, 같은 플랫폼 링크에서는 한글 용어만 본다.
  static const Map<String, List<String>> subjectTerms = {
    'youtube': ['유튜브', '유튜버', '구독자', '조회수', '크리에이터', 'youtube', 'youtuber'],
    'instagram': ['인스타', '릴스', '팔로워', '인플루언서', 'instagram'],
    'threads': ['스레드', '쓰레드', 'threads'],
    'tiktok': ['틱톡', 'tiktok'],
    'facebook': ['페이스북', '페북', 'facebook'],
    'twitter': ['트위터', 'twitter'],
    'naver': ['네이버', '블로그', 'naver'],
  };

  static ChatQueryResult run(ChatQuery q, List<LinkItem> all, {DateTime? now}) {
    if (all.isEmpty) {
      return const ChatQueryResult(
        text: 'DB허브에 저장된 링크가 아직 없어요.\n링크를 먼저 저장해보세요!',
      );
    }

    if (q.action == QueryAction.interests) {
      final range = q.range ??
          ChatInterestReport.defaultRange(now ?? DateTime.now());
      final scoped = all
          .where((l) => range.contains(l.createdAt))
          .where((l) => q.categoryId == null || l.category == q.categoryId)
          .toList();
      return ChatInterestReport.build(scoped, range);
    }

    // 카테고리·주제·기간으로 1차 필터
    var items = all.where((l) => _matchesScope(l, q)).toList();

    switch (q.action) {
      case QueryAction.count:
        return _count(q, items, all);
      case QueryAction.search:
        return _search(q, items);
      case QueryAction.recent:
        return _recent(q, _applyKeywords(items, q.keywords));
      case QueryAction.list:
      case QueryAction.summarize:
        return _list(q, _applyKeywords(items, q.keywords));
      case QueryAction.interests:
      case QueryAction.unknown:
        return const ChatQueryResult(text: '');
    }
  }

  // ── 필터 ───────────────────────────────────────────────────
  static bool _matchesScope(LinkItem l, ChatQuery q) {
    if (q.categoryId != null && l.category != q.categoryId) return false;
    if (q.topicId != null && !linkMatchesTopic(l, q.topicId!)) return false;
    if (q.range != null && !q.range!.contains(l.createdAt)) return false;
    if (q.subjectId != null && !matchesSubject(l, q.subjectId!)) return false;
    return true;
  }

  /// 링크 내용이 그 플랫폼(운영·제작 등)에 관한 것인가 — URL은 보지 않는다
  static bool matchesSubject(LinkItem l, String platformId) {
    final terms = subjectTerms[platformId];
    if (terms == null) return false;
    final text = [
      l.title,
      l.tags.join(' '),
      l.summary ?? '',
      l.notes ?? '',
      l.description ?? '',
    ].join(' ').toLowerCase();
    final samePlatform = l.category == platformId;
    return terms.any((t) {
      if (samePlatform && RegExp(r'^[a-z]').hasMatch(t)) return false;
      return text.contains(t);
    });
  }

  static List<LinkItem> _applyKeywords(List<LinkItem> items, List<String> kws) {
    if (kws.isEmpty) return items;
    return items.where((l) {
      final h = _haystack(l);
      return kws.every((k) => h.contains(k.toLowerCase()));
    }).toList();
  }

  static String _haystack(LinkItem l) => linkHaystack(l);

  /// 지정 개수 > 요약(20) > 기간 목록(30) > 기본(10)
  static int _limitFor(ChatQuery q) {
    if (q.limit != null) return q.limit!;
    if (q.action == QueryAction.summarize) return _summarizeLimit;
    if (q.range != null) return _rangeLimit;
    return _defaultLimit;
  }

  // ── 개수 ───────────────────────────────────────────────────
  static ChatQueryResult _count(
    ChatQuery q,
    List<LinkItem> scoped,
    List<LinkItem> all,
  ) {
    final filtered = _applyKeywords(scoped, q.keywords);
    final label = _scopeLabel(q);

    // 조건이 전혀 없으면 카테고리별 분포까지 보여준다
    if (!q.hasFilter) {
      final byCat = <String, int>{};
      for (final l in all) {
        byCat[l.category] = (byCat[l.category] ?? 0) + 1;
      }
      final breakdown = byCat.entries
          .map(
            (e) =>
                '${HubCategory.fromId(e.key).emoji} ${HubCategory.fromId(e.key).label} ${e.value}개',
          )
          .join('\n');
      return ChatQueryResult(
        text: '저장된 링크는 총 ${all.length}개예요.\n\n$breakdown',
        totalMatched: all.length,
      );
    }

    if (filtered.isEmpty) {
      return ChatQueryResult(text: '$label는 아직 없어요.', totalMatched: 0);
    }
    return ChatQueryResult(
      text: '$label는 ${filtered.length}개예요.',
      links: filtered.take(3).toList(),
      totalMatched: filtered.length,
    );
  }

  // ── 목록 ───────────────────────────────────────────────────
  static ChatQueryResult _list(ChatQuery q, List<LinkItem> items) {
    final label = _scopeLabel(q);
    if (items.isEmpty) {
      return ChatQueryResult(text: '$label를 찾지 못했어요.', totalMatched: 0);
    }
    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limit = _limitFor(q);
    final shown = sorted.take(limit).toList();

    final more = sorted.length > shown.length
        ? ' (전체 ${sorted.length}개 중 ${shown.length}개)'
        : '';
    return ChatQueryResult(
      text: '$label ${sorted.length}개를 찾았어요.$more',
      links: shown,
      totalMatched: sorted.length,
    );
  }

  // ── 최근 ───────────────────────────────────────────────────
  static ChatQueryResult _recent(ChatQuery q, List<LinkItem> items) {
    final label = _scopeLabel(q);
    if (items.isEmpty) {
      return ChatQueryResult(text: '$label를 찾지 못했어요.', totalMatched: 0);
    }
    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limit = q.limit ?? _recentLimit;
    final shown = sorted.take(limit).toList();
    return ChatQueryResult(
      text: '최근에 저장한 $label ${shown.length}개예요.',
      links: shown,
      totalMatched: sorted.length,
    );
  }

  // ── 검색 (관련도 스코어링) ─────────────────────────────────
  static ChatQueryResult _search(ChatQuery q, List<LinkItem> scoped) {
    final label = _scopeLabel(q);

    // 키워드가 없으면 스코어링할 게 없으므로 목록과 동일하게 처리
    if (q.keywords.isEmpty) return _list(q, scoped);

    final scored = <MapEntry<LinkItem, int>>[];
    for (final l in scoped) {
      final s = _score(l, q.keywords);
      if (s > 0) scored.add(MapEntry(l, s));
    }

    if (scored.isEmpty) {
      return ChatQueryResult(
        text: '"${q.keywords.join(' ')}" 관련 $label를 찾지 못했어요.',
        totalMatched: 0,
      );
    }

    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      return b.key.createdAt.compareTo(a.key.createdAt);
    });

    final limit = _limitFor(q);
    final shown = scored.take(limit).map((e) => e.key).toList();
    return ChatQueryResult(
      text: '"${q.keywords.join(' ')}" 관련 $label ${scored.length}개를 찾았어요.',
      links: shown,
      totalMatched: scored.length,
    );
  }

  /// 필드별 가중치 — 제목 > 태그 > 메모 > URL
  static int _score(LinkItem l, List<String> keywords) {
    var score = 0;
    final title = l.title.toLowerCase();
    final tags = l.tags.map((t) => t.toLowerCase()).toList();
    final memo = '${l.summary ?? ''} ${l.notes ?? ''} ${l.description ?? ''}'
        .toLowerCase();
    final url = l.url.toLowerCase();

    for (final raw in keywords) {
      final k = raw.toLowerCase();
      if (title.contains(k)) score += 10;
      if (tags.any((t) => t == k)) {
        score += 8;
      } else if (tags.any((t) => t.contains(k))) {
        score += 5;
      }
      if (memo.contains(k)) score += 3;
      if (url.contains(k)) score += 1;
    }
    return score;
  }

  // ── 사람이 읽을 조건 설명 ("유튜브 요리 링크") ─────────────
  static String _scopeLabel(ChatQuery q) {
    // "지난주(11/16~11/22) 유튜브 요리 링크", "유튜브 관련 링크"
    final parts = <String>[];
    if (q.range != null) parts.add(q.range!.label);
    if (q.categoryId != null) {
      parts.add(HubCategory.fromId(q.categoryId!).label);
    }
    if (q.subjectId != null) {
      parts.add('${HubCategory.fromId(q.subjectId!).label} 관련');
    }
    if (q.topicId != null) {
      final kw = YoutubeKeyword.all_list.where((k) => k.id == q.topicId);
      if (kw.isNotEmpty) parts.add(kw.first.label);
    }
    if (parts.isEmpty) return '링크';
    return '${parts.join(' ')} 링크';
  }
}
