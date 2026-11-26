import '../../../core/constants/app_constants.dart';
import '../../hub/models/link_item.dart';
import 'chat_query.dart';

/// 링크 검색용 전체 텍스트 (제목·태그·요약·메모·설명[OCR 포함]·URL)
String linkHaystack(LinkItem l) => [
      l.title,
      l.tags.join(' '),
      l.summary ?? '',
      l.notes ?? '',
      l.description ?? '',
      l.url,
    ].join(' ').toLowerCase();

/// 주제(YoutubeKeyword) 판정 — 실행기와 분포 리포트가 같은 기준을 쓴다
bool linkMatchesTopic(LinkItem l, String topicId) {
  final kw = YoutubeKeyword.all_list.where((k) => k.id == topicId);
  if (kw.isEmpty) return true;
  final h = linkHaystack(l);
  return kw.first.patterns.any((p) => h.contains(p.toLowerCase()));
}

/// "이번 주 관심 분포·키워드 정리" — 기기 안에서만 집계(LLM·한도 사용 없음).
///
/// 주제(요리·운동…) / 저장 출처(유튜브·인스타…) / 자주 나온 키워드(태그 +
/// 제목에서 2번 이상 나온 단어)를 센다. 주 1회 돌아보기 용도.
class ChatInterestReport {
  ChatInterestReport._();

  /// 기간을 말하지 않으면 최근 7일
  static DateRange defaultRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final from = DateTime(today.year, today.month, today.day - 6);
    final to = DateTime(today.year, today.month, today.day + 1);
    return DateRange(from, to, '최근 7일(${from.month}/${from.day}~${today.month}/${today.day})');
  }

  /// 제목 단어 중 키워드로 의미 없는 것
  static const _noise = {
    '영상', '방법', '진짜', '정말', '이렇게', '하는', '하는법', '하기', '모음',
    '추천', '공유', '오늘', '이번', '그냥', '완벽', '정리', '최고', '꿀팁', '필수',
    'shorts', 'short', 'youtube', 'instagram', 'threads', 'tiktok', 'facebook',
    'on', 'the', 'and', 'for', 'with', 'you', 'how', 'to', 'of', 'in', 'is',
    'www', 'http', 'https', 'com', 'reel', 'reels', 'video', '게시물', '님',
  };

  static ChatQueryResult build(List<LinkItem> items, DateRange range) {
    if (items.isEmpty) {
      return ChatQueryResult(text: '${range.label}에 저장한 링크가 없어요.');
    }

    // ── 주제 ──
    final topics = <String, int>{};
    var noTopic = 0;
    for (final l in items) {
      final hit = YoutubeKeyword.all_list.where((k) => linkMatchesTopic(l, k.id));
      if (hit.isEmpty) {
        noTopic++;
      } else {
        final k = hit.first;
        final key = '${k.emoji} ${k.label}';
        topics[key] = (topics[key] ?? 0) + 1;
      }
    }

    // ── 출처 ──
    final sources = <String, int>{};
    for (final l in items) {
      final c = HubCategory.fromId(l.category);
      final key = '${c.emoji} ${c.label}';
      sources[key] = (sources[key] ?? 0) + 1;
    }

    // ── 키워드: 태그는 1번만 나와도, 제목 단어는 2번 이상 나와야 인정 ──
    final tagCount = <String, int>{};
    final wordCount = <String, int>{};
    for (final l in items) {
      final tags = <String>{
        ...l.tags.map((t) => t.toLowerCase().replaceAll('#', '').trim()),
        ...RegExp(r'#([^\s#]+)')
            .allMatches(l.title)
            .map((m) => m.group(1)!.toLowerCase()),
      }..removeWhere((t) => t.isEmpty);
      for (final t in tags) {
        tagCount[t] = (tagCount[t] ?? 0) + 1;
      }
      final words = l.title
          .toLowerCase()
          .replaceAll(RegExp(r'#[^\s#]+'), ' ')
          .split(RegExp(r'[^0-9a-z가-힣]+'))
          .where((w) =>
              w.length >= 2 &&
              !_noise.contains(w) &&
              !RegExp(r'^\d+$').hasMatch(w) &&
              !tags.contains(w))
          .toSet();
      for (final w in words) {
        wordCount[w] = (wordCount[w] ?? 0) + 1;
      }
    }
    final keywords = <String, int>{
      for (final e in tagCount.entries) '#${e.key}': e.value,
      for (final e in wordCount.entries)
        if (e.value >= 2) e.key: e.value,
    };

    final buf = StringBuffer()
      ..writeln('📊 ${range.label} 관심 분포 — 링크 ${items.length}개')
      ..writeln()
      ..writeln('[주제]')
      ..writeln(_line({...topics, if (noTopic > 0) '기타': noTopic}))
      ..writeln()
      ..writeln('[저장 출처]')
      ..writeln(_line(sources));
    if (keywords.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('[자주 나온 키워드]')
        ..writeln(_line(keywords, max: 10));
    } else {
      buf
        ..writeln()
        ..writeln('태그를 달아두면 키워드 분포도 보여드릴게요.');
    }

    final recent = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ChatQueryResult(
      text: buf.toString().trimRight(),
      links: recent.take(5).toList(),
      totalMatched: items.length,
    );
  }

  /// 많은 순 정렬 후 "요리 5 · 운동 3" 한 줄
  static String _line(Map<String, int> m, {int max = 8}) {
    final sorted = m.entries.toList()
      ..sort((a, b) {
        // '기타'는 항상 맨 뒤 (Dart sort는 안정 정렬이 아니라 비교 한 번에 처리)
        final etc = (a.key == '기타' ? 1 : 0) - (b.key == '기타' ? 1 : 0);
        if (etc != 0) return etc;
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return sorted.take(max).map((e) => '${e.key} ${e.value}').join(' · ');
  }
}
