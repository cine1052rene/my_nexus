import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/features/chat/services/chat_date_range.dart';
import 'package:my_nexus/features/chat/services/chat_query.dart';
import 'package:my_nexus/features/chat/services/chat_query_executor.dart';
import 'package:my_nexus/features/chat/services/chat_query_parser.dart';
import 'package:my_nexus/features/hub/models/link_item.dart';

// 기준: 2026-11-27 (금) 15:00 → 이번 주 월요일 11/23, 지난주 11/16~11/22
final _now = DateTime(2026, 11, 27, 15);

DateRange _r(String s) => ChatDateParser.parse(s, now: _now)!.range;

LinkItem _link(String id, String title, DateTime at,
        {String category = 'youtube', List<String> tags = const []}) =>
    LinkItem(
      id: id,
      url: 'https://example.com/$id',
      title: title,
      category: category,
      tags: tags,
      createdAt: at,
    );

void main() {
  group('ChatDateParser', () {
    test('오늘·어제', () {
      expect(_r('오늘 저장한 링크').from, DateTime(2026, 11, 27));
      final y = _r('어제 뭐 저장했지');
      expect(y.from, DateTime(2026, 11, 26));
      expect(y.to, DateTime(2026, 11, 27));
    });

    test('지난주·저번주 = 지난 월~일', () {
      for (final s in ['지난주', '저번주', '지난 주', '저번 주']) {
        final r = _r('$s 링크');
        expect(r.from, DateTime(2026, 11, 16), reason: s);
        expect(r.to, DateTime(2026, 11, 23), reason: s);
        expect(r.label, '지난주(11/16~11/22)');
      }
    });

    test('이번 주 = 월요일~오늘', () {
      final r = _r('이번 주 관심 분포');
      expect(r.from, DateTime(2026, 11, 23));
      expect(r.to, DateTime(2026, 11, 28));
    });

    test('지난달·이번 달', () {
      expect(_r('지난달 링크').from, DateTime(2026, 10, 1));
      expect(_r('지난달 링크').to, DateTime(2026, 11, 1));
      expect(_r('이번 달 링크').from, DateTime(2026, 11, 1));
    });

    test('최근 N일 / N주', () {
      final r = _r('최근 7일 저장한 링크');
      expect(r.from, DateTime(2026, 11, 21));
      expect(r.to, DateTime(2026, 11, 28));
      expect(_r('지난 2주 링크').from, DateTime(2026, 11, 14));
    });

    test('명시 범위: 11월 3일부터 10일까지', () {
      final r = _r('11월 3일부터 10일까지 저장한 링크');
      expect(r.from, DateTime(2026, 11, 3));
      expect(r.to, DateTime(2026, 11, 11));
      expect(r.label, '11/3~11/10');
    });

    test('명시 범위: 10월 28일~11월 2일, 슬래시 11/3~11/5', () {
      final a = _r('10월 28일~11월 2일 링크');
      expect(a.from, DateTime(2026, 10, 28));
      expect(a.to, DateTime(2026, 11, 3));
      final b = _r('11/3~11/5 링크');
      expect(b.from, DateTime(2026, 11, 3));
      expect(b.to, DateTime(2026, 11, 6));
    });

    test('미래 날짜는 작년으로', () {
      expect(_r('12월 20일 링크').from, DateTime(2025, 12, 20));
    });

    test('월 전체: 10월', () {
      final r = _r('10월에 저장한 링크');
      expect(r.from, DateTime(2026, 10, 1));
      expect(r.to, DateTime(2026, 11, 1));
    });

    test('날짜 표현이 없으면 null', () {
      expect(ChatDateParser.parse('유튜브 링크 보여줘', now: _now), isNull);
      expect(ChatDateParser.parse('3개월 구독 링크', now: _now), isNull);
    });
  });

  group('플랫폼 = 주제 vs 출처', () {
    test('"유튜브 관련 링크 정리해줘" → 주제(운영·제작)', () {
      final q = ChatQueryParser.parse('유튜브 관련 링크 정리해줘', now: _now);
      expect(q.action, QueryAction.summarize);
      expect(q.subjectId, 'youtube');
      expect(q.categoryId, isNull);
      expect(q.keywords, isEmpty);
    });

    test('"유튜브 운영 링크 정리해줘" → 주제, \'운영\'은 조건 아님', () {
      final q = ChatQueryParser.parse('유튜브 운영 링크 정리해줘', now: _now);
      expect(q.subjectId, 'youtube');
      expect(q.keywords, isEmpty);
    });

    test('"저번주에 유튜브에서 수집한 링크 보여줘" → 출처 + 기간 목록', () {
      final q = ChatQueryParser.parse('저번주에 유튜브에서 수집한 링크 보여줘', now: _now);
      expect(q.action, QueryAction.list);
      expect(q.categoryId, 'youtube');
      expect(q.subjectId, isNull);
      expect(q.range!.from, DateTime(2026, 11, 16));
      expect(q.keywords, isEmpty);
    });

    test('"유튜브 링크 보여줘"는 그대로 출처(카테고리)', () {
      final q = ChatQueryParser.parse('유튜브 링크 보여줘', now: _now);
      expect(q.categoryId, 'youtube');
      expect(q.subjectId, isNull);
    });

    test('"최근 7일 저장한 링크"는 5개 제한 최근이 아니라 기간 목록', () {
      final q = ChatQueryParser.parse('최근 7일 저장한 링크 알려줘', now: _now);
      expect(q.action, QueryAction.list);
      expect(q.range, isNotNull);
    });

    test('기간만 있어도 로컬 목록 ("지난주 저장한 거 보여줘")', () {
      final q = ChatQueryParser.parse('지난주 저장한 거 보여줘', now: _now);
      expect(q.isLocal, isTrue);
      expect(q.range, isNotNull);
    });

    test('날짜만 있는 일반 대화는 가로채지 않음', () {
      expect(ChatQueryParser.parse('오늘 날씨 어때', now: _now).action,
          QueryAction.unknown);
    });
  });

  group('실행', () {
    final links = [
      _link('a', '유튜브 썸네일 잘 만드는 법', DateTime(2026, 11, 18),
          category: 'instagram'),
      _link('b', '김치찌개 레시피', DateTime(2026, 11, 17)),
      _link('c', '구독자 1만 채널 운영기', DateTime(2026, 11, 2),
          category: 'threads'),
      _link('d', '홈트 루틴 - YouTube', DateTime(2026, 11, 25)),
      _link('e', '편집 툴 비교', DateTime(2026, 11, 10),
          category: 'naver', tags: ['유튜브']),
    ];

    test('주제 모드: 유튜브 운영 관련만 (유튜브에서 저장한 요리 영상은 제외)', () {
      final q = ChatQueryParser.parse('유튜브 관련 링크 정리해줘', now: _now);
      final r = ChatQueryExecutor.run(q, links, now: _now);
      expect(r.links.map((l) => l.id), unorderedEquals(['a', 'c', 'e']));
    });

    test('출처 + 기간: 지난주 유튜브에서 저장한 것만', () {
      final q = ChatQueryParser.parse('지난주 유튜브에서 저장한 링크', now: _now);
      final r = ChatQueryExecutor.run(q, links, now: _now);
      expect(r.links.map((l) => l.id), ['b']);
      expect(r.text, contains('지난주(11/16~11/22) 유튜브'));
    });

    test('날짜 범위 목록', () {
      final q = ChatQueryParser.parse('11월 1일부터 10일까지 저장한 링크', now: _now);
      final r = ChatQueryExecutor.run(q, links, now: _now);
      expect(r.links.map((l) => l.id), ['e', 'c']);
    });

    test('관심 분포: 기본 최근 7일, 주제·출처 집계', () {
      final q = ChatQueryParser.parse('이번 주 관심 분포 정리해줘', now: _now);
      expect(q.action, QueryAction.interests);
      expect(q.isLocal, isTrue);
      final r = ChatQueryExecutor.run(q, links, now: _now);
      expect(r.totalMatched, 1); // 이번 주(11/23~) = d
      expect(r.text, contains('관심 분포'));
      expect(r.text, contains('운동'));

      final week = ChatQueryExecutor.run(
          ChatQueryParser.parse('관심 키워드 정리해줘', now: _now), links,
          now: _now);
      expect(week.totalMatched, 1); // 최근 7일(11/21~27) = d
      final last = ChatQueryExecutor.run(
          ChatQueryParser.parse('지난주 관심 분포', now: _now), links, now: _now);
      expect(last.totalMatched, 2);
      expect(last.text, contains('요리'));
    });
  });
}
