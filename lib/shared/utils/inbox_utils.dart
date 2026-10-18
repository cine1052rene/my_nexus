/// 메모·캡처 저장에 쓰는 순수 함수들 (테스트 대상).

/// 본문 첫 줄을 제목으로 쓴다. 의미 있는 글자가 없으면 [fallback].
String titleFromText(String text, {required String fallback, int maxLen = 40}) {
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    // 숫자·기호만 있는 줄(시계, 배터리 표시 등 캡처 상단 잡음)은 건너뛴다.
    if (line.isEmpty || !RegExp(r'[가-힣A-Za-z]').hasMatch(line)) continue;
    return line.length > maxLen ? '${line.substring(0, maxLen)}…' : line;
  }
  return fallback;
}

/// "캡처 10/18 14:05" 같은 기본 제목.
String defaultCaptureTitle(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '캡처 ${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
}

/// 글자 인식 결과는 검색용이라 너무 길면 자른다 (Firestore 문서 크기 보호).
String clampOcrText(String text, {int max = 5000}) =>
    text.length > max ? text.substring(0, max) : text;
