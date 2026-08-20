import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/features/chat/services/chat_query.dart';
import 'package:my_nexus/features/chat/services/chat_query_parser.dart';
import 'package:my_nexus/features/chat/services/chat_query_executor.dart';
import 'package:my_nexus/features/hub/models/link_item.dart';

LinkItem _link({
  required String id,
  required String title,
  String category = 'youtube',
  List<String> tags = const [],
  String? notes,
  int daysAgo = 0,
}) => LinkItem(
  id: id,
  url: 'https://example.com/$id',
  title: title,
  category: category,
  tags: tags,
  notes: notes,
  createdAt: DateTime(2026, 8, 20).subtract(Duration(days: daysAgo)),
);

void main() {
  // ── 파서 ─────────────────────────────────────────────────
  group('ChatQueryParser — 로컬 처리 대상', () {
    test('카테고리 + 목록', () {
      final q = ChatQueryParser.parse('유튜브 링크 목록 보여줘');
      expect(q.action, QueryAction.list);
      expect(q.categoryId, 'youtube');
      expect(q.isLocal, isTrue);
    });

    test('카테고리 + 개수', () {
      final q = ChatQueryParser.parse('인스타 링크 몇 개야?');
      expect(q.action, QueryAction.count);
      expect(q.categoryId, 'instagram');
    });

    test('최근 저장', () {
      final q = ChatQueryParser.parse('최근 저장한 링크 알려줘');
      expect(q.action, QueryAction.recent);
    });

    test('주제 검색', () {
      final q = ChatQueryParser.parse('요리 관련 링크 찾아줘');
      expect(q.action, QueryAction.search);
      expect(q.topicId, 'yt_cooking');
    });

    test('IT 주제어 인식', () {
      final q = ChatQueryParser.parse('개발 관련 영상 보여줘');
      expect(q.topicId, 'yt_tech');
      expect(q.isLocal, isTrue);
    });

    test('개수 지정 파싱', () {
      final q = ChatQueryParser.parse('최근 링크 3개만 보여줘');
      expect(q.limit, 3);
    });

    test('인스타그램 전체 별칭이 인스타보다 우선', () {
      final q = ChatQueryParser.parse('인스타그램 링크 몇개야');
      expect(q.categoryId, 'instagram');
    });

    test('요약 요청은 LLM 폴백 대상', () {
      final q = ChatQueryParser.parse('최근 저장한 링크 요약해줘');
      expect(q.action, QueryAction.summarize);
      expect(q.needsLlm, isTrue);
      expect(q.isLocal, isFalse);
    });
  });

  group('ChatQueryParser — 일반 대화는 가로채지 않음', () {
    test('링크 문맥 없는 일반 질문', () {
      // '공부'는 주제어지만 링크 명사가 없으므로 LLM에게 넘겨야 한다
      final q = ChatQueryParser.parse('파이썬 공부하는 법 알려줘');
      expect(q.action, QueryAction.unknown);
    });

    test('요리 질문도 링크 문맥 없으면 통과', () {
      final q = ChatQueryParser.parse('김치찌개 맛있게 끓이는 법');
      expect(q.action, QueryAction.unknown);
    });

    test('빈 문자열', () {
      expect(ChatQueryParser.parse('   ').action, QueryAction.unknown);
    });

    test('링크 명사가 있어도 조건 없는 약한 매칭은 LLM으로', () {
      // '알려'가 목록 신호어지만 무엇을 나열할지가 없다 → 사용법 질문
      final q = ChatQueryParser.parse('링크 저장하는 법 알려줘');
      expect(q.action, QueryAction.unknown);
    });

    test('명시적 나열 표현은 조건 없어도 로컬 처리', () {
      final q = ChatQueryParser.parse('저장한 링크 목록');
      expect(q.action, QueryAction.list);
      expect(q.isLocal, isTrue);
    });

    test('카테고리가 있으면 약한 신호어로도 로컬 처리', () {
      final q = ChatQueryParser.parse('유튜브 링크 보여줘');
      expect(q.action, QueryAction.list);
      expect(q.categoryId, 'youtube');
    });

    test('짧은 영문 패턴이 부분일치로 오탐되지 않음', () {
      // 'ai'(IT 패턴)가 'email' 안에 들어있다고 IT 주제로 잡히면 안 됨
      final q = ChatQueryParser.parse('email 정리하는 법');
      expect(q.action, QueryAction.unknown);
      expect(q.topicId, isNull);
    });
  });

  // ── 실행기 ───────────────────────────────────────────────
  group('ChatQueryExecutor', () {
    final links = [
      _link(id: '1', title: '파이썬 기초 강의', tags: ['공부'], daysAgo: 0),
      _link(id: '2', title: '김치찌개 레시피', tags: ['요리'], daysAgo: 1),
      _link(
        id: '3',
        title: '홈트 루틴',
        category: 'instagram',
        tags: ['운동'],
        daysAgo: 2,
      ),
      _link(id: '4', title: 'Flutter 상태관리', tags: ['개발'], daysAgo: 3),
      _link(
        id: '5',
        title: '파스타 만들기',
        category: 'instagram',
        tags: ['요리'],
        daysAgo: 4,
      ),
    ];

    test('카테고리 개수 정확히 셈', () {
      final q = ChatQueryParser.parse('인스타 링크 몇 개야?');
      final r = ChatQueryExecutor.run(q, links);
      expect(r.totalMatched, 2);
      expect(r.text, contains('2개'));
    });

    test('카테고리 목록 필터링', () {
      final q = ChatQueryParser.parse('유튜브 링크 보여줘');
      final r = ChatQueryExecutor.run(q, links);
      expect(r.links.length, 3);
      expect(r.links.every((l) => l.category == 'youtube'), isTrue);
    });

    test('최근순 정렬', () {
      final q = ChatQueryParser.parse('최근 저장한 링크 보여줘');
      final r = ChatQueryExecutor.run(q, links);
      expect(r.links.first.id, '1');
    });

    test('주제 필터 — 요리', () {
      final q = ChatQueryParser.parse('요리 관련 링크 찾아줘');
      final r = ChatQueryExecutor.run(q, links);
      expect(r.links.map((l) => l.id), containsAll(['2', '5']));
      expect(r.links.map((l) => l.id), isNot(contains('4')));
    });

    test('결과 없으면 지어내지 않고 없다고 답함', () {
      final q = ChatQueryParser.parse('틱톡 링크 보여줘');
      final r = ChatQueryExecutor.run(q, links);
      expect(r.links, isEmpty);
      expect(r.totalMatched, 0);
      expect(r.text, contains('찾지 못했어요'));
    });

    test('빈 DB허브 처리', () {
      final q = ChatQueryParser.parse('유튜브 링크 보여줘');
      final r = ChatQueryExecutor.run(q, const []);
      expect(r.links, isEmpty);
      expect(r.text, contains('저장된 링크가 아직 없어요'));
    });

    test('조건 없는 개수 질문은 카테고리 분포 제공', () {
      final q = ChatQueryParser.parse('링크 몇 개 저장했어?');
      final r = ChatQueryExecutor.run(q, links);
      expect(r.totalMatched, 5);
      expect(r.text, contains('총 5개'));
      expect(r.text, contains('유튜브'));
    });

    test('limit 지정 반영', () {
      final q = ChatQueryParser.parse('유튜브 링크 2개만 보여줘');
      final r = ChatQueryExecutor.run(q, links);
      expect(r.links.length, 2);
      expect(r.totalMatched, 3);
    });
  });
}
