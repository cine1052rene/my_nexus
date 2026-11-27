import 'youtube_utils.dart';

/// 같은 콘텐츠를 가리키는 링크를 같은 값으로 만드는 "중복 판별 키".
///
/// 같은 영상·게시물이라도 공유할 때마다 주소가 조금씩 다르다
/// (`?si=`, `?igsh=`, `utm_*`, `m.`/`www.`, 쇼츠 vs watch 주소 등).
/// 그대로 비교하면 같은 걸 또 저장해도 모른다 — 그래서 플랫폼별 콘텐츠 ID로 줄인다.
///
/// 틱톡 단축링크(vt./vm.)는 공유할 때마다 코드가 달라서 여기서는 못 줄인다.
/// 호출하는 쪽에서 먼저 실제 주소로 풀어서 넘겨야 한다.
///
/// ⚠️ 백필 스크립트(`tool/backfill_v110.js`)에 같은 규칙이 JS로 복제돼 있다.
/// 규칙을 바꾸면 양쪽을 함께 고칠 것.
String canonicalLinkKey(String raw) {
  final url = raw.trim();
  final yt = extractYoutubeId(url);
  if (yt != null) return 'yt:$yt';

  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return url.toLowerCase();

  final host = uri.host
      .toLowerCase()
      .replaceFirst(RegExp(r'^(www|m|mobile)\.'), '');
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  String? after(String marker) {
    final i = segs.indexOf(marker);
    return (i >= 0 && i + 1 < segs.length) ? segs[i + 1] : null;
  }

  if (host.endsWith('tiktok.com')) {
    final id = after('video') ?? after('photo');
    if (id != null) return 'tt:$id';
  }
  if (host.endsWith('instagram.com')) {
    final id = after('p') ?? after('reel') ?? after('reels') ?? after('tv');
    if (id != null) return 'ig:$id';
  }
  if (host.startsWith('threads.')) {
    final id = after('post');
    if (id != null) return 'th:$id';
  }
  if (host == 'x.com' || host == 'twitter.com') {
    final id = after('status');
    if (id != null) return 'x:$id';
  }

  // 그 외: 추적용 파라미터만 지우고 나머지는 유지 (검색 결과 페이지 등은 쿼리가 본체)
  final kept = Map.of(uri.queryParameters)
    ..removeWhere((k, _) => _trackingParams.contains(k) || k.startsWith('utm_'));
  final query = kept.isEmpty
      ? ''
      : '?${(kept.keys.toList()..sort()).map((k) => '$k=${kept[k]}').join('&')}';
  final path = segs.join('/');
  return '$host/$path$query'.toLowerCase();
}

const _trackingParams = {
  'si', 'igsh', 'igshid', 'fbclid', 'gclid', 'feature', 'ref', 'ref_src',
  's', 't', 'mibextid', 'rdid', 'share_url', 'is_from_webapp', 'sender_device',
  'web_id', '_r', '_t', 'xmt', 'slof',
};
