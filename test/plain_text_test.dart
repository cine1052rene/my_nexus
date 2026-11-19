import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/shared/utils/plain_text.dart';
import 'package:my_nexus/features/calendar/models/schedule_event.dart';

void main() {
  test('굵게·제목·목록 기호 제거', () {
    const src = '## 요약\n*   **제목:** 제주 여행\n- **태그:** 여행, 제주\n\n\n\n끝';
    expect(stripMarkdown(src), '요약\n• 제목: 제주 여행\n• 태그: 여행, 제주\n\n끝');
  });
  test('링크와 코드', () {
    expect(stripMarkdown('[영상](https://youtu.be/x) `코드`'), '영상 (https://youtu.be/x) 코드');
  });
  test('곱셈·URL의 별표는 과하게 지우지 않음', () {
    expect(stripMarkdown('3 * 4 = 12'), '3 * 4 = 12');
  });
  test('일정 정렬: 종일 → 시간순 → 제목', () {
    final d = DateTime(2026, 11, 20);
    ScheduleEvent e(String t, int? h) => ScheduleEvent(
        id: t, title: t, date: d, allDay: h == null,
        startTime: h == null ? null : DateTime(2026, 11, 20, h));
    final list = [e('점심', 12), e('회의', 10), e('생일', null), e('PT', 19)]
      ..sort(ScheduleEvent.compareForDay);
    expect(list.map((x) => x.title).toList(), ['생일', '회의', '점심', 'PT']);
  });
}
