import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/core/utils/lunar_converter.dart';

/// 공표된 설날·추석·윤달로 음력표를 검증한다 (천문연구원 기준 날짜).
void main() {
  String l(int y, int m, int d) => LunarConverter.toSolar(DateTime(y, m, d)).toString();

  test('설날 = 음력 1월 1일', () {
    for (final d in [
      DateTime(2024, 2, 10), DateTime(2025, 1, 29), DateTime(2026, 2, 17),
      DateTime(2027, 2, 7), DateTime(2028, 1, 27), DateTime(2029, 2, 13),
      DateTime(2030, 2, 3), DateTime(2031, 1, 23), DateTime(2032, 2, 11),
      DateTime(2033, 1, 31), DateTime(2034, 2, 19),
    ]) {
      expect(l(d.year, d.month, d.day), '음력 1월 1일', reason: '$d');
    }
  });

  test('추석 = 음력 8월 15일', () {
    for (final d in [
      DateTime(2024, 9, 17), DateTime(2025, 10, 6), DateTime(2026, 9, 25),
      DateTime(2027, 9, 15), DateTime(2028, 10, 3), DateTime(2029, 9, 22),
      DateTime(2030, 9, 12),
    ]) {
      expect(l(d.year, d.month, d.day), '음력 8월 15일', reason: '$d');
    }
  });

  test('윤달', () {
    expect(l(2025, 7, 25), '음력 윤6월 1일');
    expect(l(2028, 6, 23), '음력 윤5월 1일');
  });

  test('발견된 버그 날짜 — 시각이 있어도 같은 날로 계산', () {
    expect(l(2026, 11, 19), '음력 10월 11일');
    expect(LunarConverter.toSolar(DateTime(2026, 11, 19, 23, 59)).toString(), '음력 10월 11일');
    expect(l(2026, 11, 20), '음력 10월 12일');
  });

  test('표 범위 밖은 null (틀린 값 대신 숨김)', () {
    expect(LunarConverter.toSolar(DateTime(2023, 1, 1)), isNull);
    expect(LunarConverter.toSolar(DateTime(2036, 1, 1)), isNull);
  });
}
