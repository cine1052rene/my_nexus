/// AI 답변의 마크다운 기호를 걷어내 읽기 좋은 일반 문장으로 바꾼다.
///
/// 말풍선은 Text 위젯이라 `**굵게**`, `# 제목`, `* 목록`이 기호째 보였다
/// (2026-11-19 스토어 스크린샷 촬영 중 발견). 서버 지시문에도 "마크다운 금지"를
/// 넣었지만, 모델이 어길 수 있으니 화면에서도 한 번 더 거른다.
/// 스트리밍 중 반쯤 도착한 기호(`**` 한쪽)도 지워지도록 짝을 따지지 않는다.
String stripMarkdown(String input) {
  var s = input;

  // 링크 [글자](주소) → 글자 (주소)
  s = s.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\((https?://[^)\s]+)\)'),
    (m) => '${m[1]} (${m[2]})',
  );

  // 줄 단위: 제목(#), 인용(>), 목록(*, -, +)
  s = s.split('\n').map((line) {
    var l = line;
    l = l.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
    l = l.replaceFirst(RegExp(r'^\s{0,3}>\s?'), '');
    final bullet = RegExp(r'^(\s*)[*+-]\s+').firstMatch(l);
    if (bullet != null) {
      l = '${bullet[1]}• ${l.substring(bullet.end)}';
    }
    return l;
  }).join('\n');

  // 강조·코드 기호
  s = s.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
  // 줄 안의 *기울임* (목록 기호는 위에서 이미 • 로 바뀜)
  s = s.replaceAllMapped(RegExp(r'(^|[^*\w])\*([^*\n]+)\*'), (m) => '${m[1]}${m[2]}');

  // 빈 줄이 3줄 이상 이어지면 2줄로
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trimRight();
}
