/// 질문 속 날짜 표현("지난주", "어제", "11월 3일부터 10일까지")을 기간으로 바꾼다.
///
/// 규칙 기반이라 네트워크·비용이 없다. 기준 시각([now])을 주입할 수 있어
/// 테스트에서 날짜가 흔들리지 않는다. 주의 시작은 월요일(한국 달력 관행).
library;

/// 저장일(createdAt) 필터용 기간. [from] 포함, [to] 미포함(자정 기준).
class DateRange {
  final DateTime from;
  final DateTime to;

  /// 말풍선에 쓸 설명 — "지난주(11/16~11/22)"
  final String label;

  const DateRange(this.from, this.to, this.label);

  bool contains(DateTime t) => !t.isBefore(from) && t.isBefore(to);

  @override
  String toString() => 'DateRange($label, $from ~ $to)';
}

/// 파싱 결과: 기간 + 날짜 표현을 지운 나머지 문장(키워드 추출용)
class DateMatch {
  final DateRange range;
  final String rest;
  const DateMatch(this.range, this.rest);
}

class ChatDateParser {
  ChatDateParser._();

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
  static DateTime _add(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static String _md(DateTime d) => '${d.month}/${d.day}';

  /// [from, to) 를 사람이 읽는 꼴로: 하루면 "11/26", 아니면 "11/16~11/22"
  static String _span(DateTime from, DateTime to) {
    final last = _add(to, -1);
    if (!last.isAfter(from)) return _md(from);
    return '${_md(from)}~${_md(last)}';
  }

  static DateRange _range(String name, DateTime from, DateTime to) {
    final span = _span(from, to);
    return DateRange(from, to, name.isEmpty ? span : '$name($span)');
  }

  /// 날짜 표현이 없으면 null.
  static DateMatch? parse(String text, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final tomorrow = _add(today, 1);
    final monday = _add(today, -(today.weekday - 1));

    for (final rule in _rules(today, tomorrow, monday)) {
      final m = rule.pattern.firstMatch(text);
      if (m == null) continue;
      final range = rule.build(m);
      if (range == null) continue;
      final rest = text.replaceRange(m.start, m.end, ' ');
      return DateMatch(range, rest);
    }
    return null;
  }

  /// 연도 없는 월·일 → 오늘 이후면 작년으로 본다("12월 20일"을 11월에 물으면 작년 12월)
  static DateTime? _date(DateTime today, int month, int day, {int? year}) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    var y = year ?? today.year;
    var d = DateTime(y, month, day);
    if (d.month != month) return null; // 2월 30일 같은 날짜
    if (year == null && d.isAfter(today)) d = DateTime(y - 1, month, day);
    return d;
  }

  static List<_Rule> _rules(DateTime today, DateTime tomorrow, DateTime monday) {
    final thisMonth = DateTime(today.year, today.month, 1);
    return [
      // ── 명시적 범위: "11월 3일부터 10일까지", "11월 3일~11월 10일", "3일부터 10일" ──
      _Rule(
        RegExp(r'(?:(\d{1,2})\s*월\s*)?(\d{1,2})\s*일\s*(?:부터|~|-|에서)\s*'
            r'(?:(\d{1,2})\s*월\s*)?(\d{1,2})\s*일(?:\s*까지)?'),
        (m) {
          final m1 = int.tryParse(m.group(1) ?? '') ?? today.month;
          final from = _date(today, m1, int.parse(m.group(2)!));
          if (from == null) return null;
          final m2 = int.tryParse(m.group(3) ?? '') ?? m1;
          var end = _date(today, m2, int.parse(m.group(4)!), year: from.year);
          if (end == null) return null;
          if (end.isBefore(from)) {
            end = DateTime(end.year + 1, end.month, end.day); // 12/28~1/3
          }
          return _range('', from, _add(end, 1));
        },
      ),
      // ── 슬래시 범위: "11/3~11/10", "11/3~10" ──
      _Rule(
        RegExp(r'(?<!\d)(\d{1,2})/(\d{1,2})\s*(?:부터|~|-)\s*'
            r'(?:(\d{1,2})/)?(\d{1,2})(?!\d)(?:\s*일)?(?:\s*까지)?'),
        (m) {
          final m1 = int.parse(m.group(1)!);
          final from = _date(today, m1, int.parse(m.group(2)!));
          if (from == null) return null;
          final m2 = int.tryParse(m.group(3) ?? '') ?? m1;
          var end = _date(today, m2, int.parse(m.group(4)!), year: from.year);
          if (end == null) return null;
          if (end.isBefore(from)) end = DateTime(end.year + 1, end.month, end.day);
          return _range('', from, _add(end, 1));
        },
      ),
      // ── "최근 7일", "지난 2주", "최근 3개월", "10일간" ──
      _Rule(
        RegExp(r'(?:최근|지난)\s*(\d+)\s*(일|주|개월|달)(?:\s*(?:간|동안))?'),
        (m) => _lastN(today, tomorrow, int.parse(m.group(1)!), m.group(2)!),
      ),
      _Rule(
        RegExp(r'(?<!\d)(\d+)\s*일\s*(?:간|동안)'),
        (m) => _lastN(today, tomorrow, int.parse(m.group(1)!), '일'),
      ),
      // ── "최근 일주일", "최근 한 달" ──
      _Rule(
        RegExp(r'(?:최근|지난)?\s*(?:일주일|1주일|한\s*주간?)(?:\s*(?:간|동안))?'),
        (m) => _lastN(today, tomorrow, 7, '일', name: '최근 일주일'),
      ),
      _Rule(
        RegExp(r'(?:최근|지난)\s*한\s*달(?:\s*(?:간|동안))?'),
        (m) => _lastN(today, tomorrow, 1, '개월', name: '최근 한 달'),
      ),
      // ── "3일 전" ──
      _Rule(RegExp(r'(?<!\d)(\d+)\s*일\s*전'), (m) {
        final d = _add(today, -int.parse(m.group(1)!));
        return _range('${m.group(1)}일 전', d, _add(d, 1));
      }),
      // ── 단일 날짜: "11월 3일", "11/3" ──
      _Rule(RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일'), (m) {
        final d = _date(today, int.parse(m.group(1)!), int.parse(m.group(2)!));
        return d == null ? null : _range('', d, _add(d, 1));
      }),
      _Rule(RegExp(r'(?<![\d/])(\d{1,2})/(\d{1,2})(?![\d/])'), (m) {
        final d = _date(today, int.parse(m.group(1)!), int.parse(m.group(2)!));
        return d == null ? null : _range('', d, _add(d, 1));
      }),
      // ── 월 전체: "10월" ──
      _Rule(RegExp(r'(?<!\d)(\d{1,2})\s*월(?!\s*\d)'), (m) {
        final mo = int.parse(m.group(1)!);
        if (mo < 1 || mo > 12) return null;
        var start = DateTime(today.year, mo, 1);
        if (start.isAfter(today)) start = DateTime(today.year - 1, mo, 1);
        final end = DateTime(start.year, start.month + 1, 1);
        return _range('$mo월', start, end.isAfter(tomorrow) ? tomorrow : end);
      }),
      // ── 낱말 ── (주말을 주보다 먼저 검사)
      _Rule(RegExp(r'(?:지난|저번)\s*주말'), (m) {
        final sat = _add(monday, -2);
        return _range('지난 주말', sat, _add(sat, 2));
      }),
      _Rule(RegExp(r'이번\s*주말'), (m) {
        final sat = _add(monday, 5);
        return _range('이번 주말', sat, _add(sat, 2));
      }),
      _Rule(RegExp(r'(?:지난|저번)\s*주'), (m) {
        return _range('지난주', _add(monday, -7), monday);
      }),
      _Rule(RegExp(r'(?:이번\s*주|금주)'), (m) {
        return _range('이번 주', monday, tomorrow);
      }),
      _Rule(RegExp(r'(?:지난|저번)\s*달'), (m) {
        final start = DateTime(today.year, today.month - 1, 1);
        return _range('지난달', start, thisMonth);
      }),
      _Rule(RegExp(r'(?:이번\s*달|이달)'), (m) {
        return _range('이번 달', thisMonth, tomorrow);
      }),
      _Rule(RegExp(r'(?:작년|지난해)'), (m) {
        return _range(
            '작년', DateTime(today.year - 1, 1, 1), DateTime(today.year, 1, 1));
      }),
      _Rule(RegExp(r'올\s*해'), (m) {
        return _range('올해', DateTime(today.year, 1, 1), tomorrow);
      }),
      _Rule(RegExp(r'(?:그저께|그제)'), (m) {
        final d = _add(today, -2);
        return _range('그저께', d, _add(d, 1));
      }),
      _Rule(RegExp(r'어제'), (m) {
        return _range('어제', _add(today, -1), today);
      }),
      _Rule(RegExp(r'오늘'), (m) {
        return _range('오늘', today, tomorrow);
      }),
    ];
  }

  static DateRange? _lastN(DateTime today, DateTime tomorrow, int n, String unit,
      {String? name}) {
    if (n <= 0 || n > 3650) return null;
    final DateTime from;
    switch (unit) {
      case '일':
        from = _add(today, -(n - 1));
      case '주':
        from = _add(today, -(n * 7 - 1));
      default: // 개월·달
        from = DateTime(today.year, today.month - n, today.day + 1);
    }
    final label = name ?? '최근 $n${unit == '달' ? '개월' : unit}';
    return _range(label, from, tomorrow);
  }
}

class _Rule {
  final RegExp pattern;
  final DateRange? Function(RegExpMatch m) build;
  const _Rule(this.pattern, this.build);
}
