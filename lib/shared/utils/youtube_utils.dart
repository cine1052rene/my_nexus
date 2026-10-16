/// 유튜브 URL에서 11자리 영상 ID를 꺼낸다.
///
/// 지원 형태:
///   youtu.be/ID · youtube.com/watch?v=ID · youtube.com/shorts/ID
///   youtube.com/embed/ID · youtube.com/live/ID · youtube.com/v/ID
///   (m. · music. · www. 서브도메인, 뒤에 붙는 ?si= 등 쿼리 포함)
///
/// 예전에는 같은 정규식이 화면마다 따로 복사돼 있었고 전부 `/shorts/`를
/// 몰랐다. 그 결과 쇼츠 링크 173개가 썸네일·제목 없이 저장됐다
/// (2026-10-14 확인). ID 추출은 반드시 이 함수 하나만 쓸 것.
final _youtubeIdRe = RegExp(
  r'(?:youtu\.be\/|youtube\.com\/(?:shorts\/|embed\/|live\/|v\/|\S*?[?&]v=))([A-Za-z0-9_-]{11})',
);

String? extractYoutubeId(String url) => _youtubeIdRe.firstMatch(url)?.group(1);

bool isYoutubeUrl(String url) =>
    url.contains('youtube.com') || url.contains('youtu.be');

/// 썸네일은 HTTP 요청 없이 ID만으로 만든다.
String youtubeThumbnail(String videoId) =>
    'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
