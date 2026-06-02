/// 간이 음력 변환기 (한국 음력)
/// 실제 정밀도는 한국천문연구원 API를 사용하는 것이 좋으나
/// 오프라인 사용을 위한 근사 계산 구현
class LunarConverter {
  /// 양력 날짜를 음력으로 변환 (근사값)
  static LunarDate toSolar(DateTime solar) {
    // 2025-01-29 = 음력 2025년 1월 1일 (을사년)
    // 2026-02-17 = 음력 2026년 1월 1일 (병오년)
    // 기준점 기반 근사 계산
    final referencePoints = [
      _LunarRef(DateTime.utc(2024, 2, 10), 2024, 1, 1),
      _LunarRef(DateTime.utc(2025, 1, 29), 2025, 1, 1),
      _LunarRef(DateTime.utc(2026, 2, 17), 2026, 1, 1),
      _LunarRef(DateTime.utc(2027, 2, 7), 2027, 1, 1),
    ];

    // 가장 가까운 기준점 찾기
    _LunarRef ref = referencePoints[0];
    for (final r in referencePoints) {
      if (!solar.isBefore(r.solar)) ref = r;
    }

    final daysDiff = solar.difference(ref.solar).inDays;
    int totalDays = daysDiff;
    int year = ref.year;
    int month = ref.month;
    int day = ref.day + totalDays;

    // 월 조정
    while (day > 30) {
      day -= (month % 2 == 1) ? 30 : 29;
      month++;
      if (month > 12) { month = 1; year++; }
    }
    while (day < 1) {
      month--;
      if (month < 1) { month = 12; year--; }
      day += (month % 2 == 1) ? 30 : 29;
    }

    return LunarDate(year: year, month: month, day: day);
  }

  /// 천간지지 (간지) 계산
  static String getGanJi(int year) {
    const gan = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
    const ji = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];
    const animals = ['쥐', '소', '호랑이', '토끼', '용', '뱀', '말', '양', '원숭이', '닭', '개', '돼지'];
    final g = gan[(year - 4) % 10];
    final j = ji[(year - 4) % 12];
    final a = animals[(year - 4) % 12];
    return '$g$j년($a)';
  }

  /// 음력 월 이름
  static String monthName(int month, bool isLeap) {
    const names = ['', '정월', '이월', '삼월', '사월', '오월', '유월',
                       '칠월', '팔월', '구월', '시월', '동짓달', '섣달'];
    return '${isLeap ? '윤' : ''}${names[month]}';
  }
}

class LunarDate {
  final int year;
  final int month;
  final int day;
  final bool isLeap;

  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    this.isLeap = false,
  });

  @override
  String toString() => '음력 $month월 $day일';

  String toFullString() {
    final ganji = LunarConverter.getGanJi(year);
    return '$ganji $month월 $day일';
  }
}

class _LunarRef {
  final DateTime solar;
  final int year;
  final int month;
  final int day;

  const _LunarRef(this.solar, this.year, this.month, this.day);
}
