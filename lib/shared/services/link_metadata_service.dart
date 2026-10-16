import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../utils/youtube_utils.dart';

/// URL로 플랫폼 카테고리(HubCategory.id)를 판별한다.
String detectLinkCategory(String url) {
  if (isYoutubeUrl(url)) return 'youtube';
  if (url.contains('instagram.com')) return 'instagram';
  if (url.contains('threads.net') || url.contains('threads.com')) return 'threads';
  if (url.contains('tiktok.com')) return 'tiktok';
  if (url.contains('facebook.com') || url.contains('fb.com') ||
      url.contains('fb.watch')) {
    return 'facebook';
  }
  if (url.contains('twitter.com') || url.contains('x.com') ||
      url.contains('t.co')) {
    return 'twitter';
  }
  if (url.contains('naver.com') || url.contains('naver.me')) return 'naver';
  return 'etc';
}

/// 링크 하나에서 가져온 제목·썸네일.
class LinkMetadata {
  final String? title;
  final String? thumbnailUrl;
  const LinkMetadata({this.title, this.thumbnailUrl});

  static const empty = LinkMetadata();
  bool get isEmpty => title == null && thumbnailUrl == null;
}

/// 플랫폼별 제목·썸네일 수집.
///
/// 2026-10-14 실측으로 정한 경로:
///   유튜브(쇼츠 포함)  공식 oEmbed — 0.1~0.3초, 키 불필요
///   틱톡              단축링크(vt./vm.) 해석 → 공식 oEmbed — 0.6~1초
///                     (단축링크를 그대로 넣으면 400. Microlink는 하루 50회
///                      제한·시간초과·"TikTok - Make Your Day" 같은 무의미한 제목)
///   페이스북·인스타·스레드  링크 미리보기 봇 UA로 OG 태그 — 0.6~4.4초
///                     (일반 앱 UA로 페이스북은 "Error Facebook" 400.
///                      공식 oEmbed는 Meta 앱 심사+토큰이 필요해 쓰지 않음.
///                      메타가 이 방식을 막으면 Microlink로 내려간다)
///   X(트위터)          Microlink
///   그 외             페이지 OG 태그
///
/// 실패해도 예외를 던지지 않고 [LinkMetadata.empty]를 돌려준다
/// (링크는 기본 제목으로 이미 저장된 뒤라 메타데이터는 보너스다).
class LinkMetadataService {
  LinkMetadataService._();

  static const _timeout = Duration(seconds: 8);
  static const _fbCrawlerUa =
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';

  /// 로그인 유도·서비스 기본 제목 — 제목으로 쓰지 않는다.
  static const _genericTitles = {
    'Instagram', 'Threads • Log in', 'Log in • Instagram', 'Threads',
    'TikTok', 'Log in | TikTok', 'TikTok - Make Your Day',
    'Facebook', 'Error Facebook', 'Log in or sign up to view',
  };

  static Future<LinkMetadata> fetch(String url, String category) async {
    try {
      switch (category) {
        case 'youtube':
          return await _youtube(url);
        case 'tiktok':
          return await _tiktok(url);
        case 'facebook':
        case 'instagram':
        case 'threads':
          // 메타 계열은 미리보기 봇 방식이 먼저 (실측 인스타·스레드·페이스북
          // 각 4/4 성공). 막히면 Microlink로 내려간다 — Microlink는 하루
          // 50회 제한이라 주 경로로 쓰면 저장이 많은 날 썸네일이 빈다.
          LinkMetadata meta;
          try {
            meta = await _metaCrawler(url, facebookTitle: category == 'facebook');
          } catch (_) {
            meta = LinkMetadata.empty;
          }
          return meta.isEmpty ? await _microlink(url) : meta;
        case 'twitter':
          return await _microlink(url);
        default:
          return await _openGraph(url);
      }
    } catch (_) {
      return LinkMetadata.empty;
    }
  }

  // ── 유튜브 ────────────────────────────────────────────────
  static Future<LinkMetadata> _youtube(String url) async {
    final vid = extractYoutubeId(url);
    if (vid == null) return LinkMetadata.empty;
    final thumb = youtubeThumbnail(vid);
    final watch = Uri.encodeQueryComponent('https://www.youtube.com/watch?v=$vid');
    final res = await http
        .get(Uri.parse('https://www.youtube.com/oembed?format=json&url=$watch'))
        .timeout(_timeout);
    if (res.statusCode != 200) return LinkMetadata(thumbnailUrl: thumb);
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return LinkMetadata(title: _clean(j['title'] as String?), thumbnailUrl: thumb);
  }

  // ── 틱톡 ──────────────────────────────────────────────────
  static Future<LinkMetadata> _tiktok(String url) async {
    final full = await _resolveTikTok(url);
    // 틱톡 oEmbed는 간헐적으로 시간초과·429가 나서 한 번 재시도한다.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(Uri.parse(
                'https://www.tiktok.com/oembed?url=${Uri.encodeQueryComponent(full)}'))
            .timeout(_timeout);
        if (res.statusCode == 200) {
          final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          return LinkMetadata(
            title: _clean(j['title'] as String?) ??
                _clean(j['author_name'] as String?),
            thumbnailUrl: j['thumbnail_url'] as String?,
          );
        }
        if (res.statusCode != 429 && res.statusCode < 500) break;
      } on TimeoutException {
        // 재시도
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    return LinkMetadata.empty;
  }

  /// vt.tiktok.com/xxx · vm.tiktok.com/xxx · tiktok.com/t/xxx 단축링크를
  /// 원래 영상 주소로 푼다 (oEmbed가 단축링크를 거부하기 때문).
  static Future<String> _resolveTikTok(String url) async {
    final uri = Uri.parse(url);
    final isShort = uri.host.startsWith('vt.') ||
        uri.host.startsWith('vm.') ||
        uri.path.startsWith('/t/');
    if (!isShort) return url.split('?').first;

    final client = http.Client();
    try {
      final req = http.Request('GET', uri)..followRedirects = false;
      final res = await client.send(req).timeout(_timeout);
      final loc = res.headers['location'];
      return (loc == null || loc.isEmpty) ? url : loc.split('?').first;
    } catch (_) {
      return url;
    } finally {
      client.close();
    }
  }

  // ── 페이스북·인스타·스레드 (메타 미리보기 봇 방식) ────────────
  static Future<LinkMetadata> _metaCrawler(String url,
      {required bool facebookTitle}) async {
    final res = await http.get(Uri.parse(url), headers: {
      'User-Agent': _fbCrawlerUa,
      'Accept-Language': 'ko-KR,ko;q=0.9',
    }).timeout(const Duration(seconds: 10)); // 스레드는 3.5~4.4초 걸린다
    if (res.statusCode != 200) return LinkMetadata.empty;
    final og = _parseOg(utf8.decode(res.bodyBytes, allowMalformed: true));
    return LinkMetadata(
      title: facebookTitle ? LinkMetadataService.facebookTitle(og.title) : og.title,
      thumbnailUrl: og.thumbnailUrl,
    );
  }

  /// 페이스북 OG 제목은 "조회 3.7만회 · 공감 131개 | 본문 | 작성자" 형태다.
  /// 조회수 부분은 금방 낡는 숫자라 버리고 본문을 제목으로 쓴다.
  @visibleForTesting
  static String? facebookTitle(String? raw) {
    if (raw == null) return null;
    var parts = raw.split(' | ').map((s) => s.trim()).toList();
    if (parts.length > 1 &&
        RegExp(r'(조회|공감|views|reactions)').hasMatch(parts.first)) {
      parts = parts.sublist(1);
    }
    final body = parts.first.split('\n').first.trim();
    if (body.isEmpty) return null;
    return body.length > 100 ? '${body.substring(0, 100)}…' : body;
  }

  // ── Microlink (인스타·스레드·X, 페이스북 예비) ───────────────
  // 클라이언트 IP 기준 하루 50회 무료 — 기기마다 따로 적용된다.
  static Future<LinkMetadata> _microlink(String url) async {
    final res = await http
        .get(Uri.parse(
            'https://api.microlink.io?url=${Uri.encodeQueryComponent(url)}'))
        .timeout(_timeout);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['status'] != 'success') return LinkMetadata.empty;
    final d = j['data'] as Map<String, dynamic>;
    final img = (d['image'] as Map<String, dynamic>?)?['url'] as String?;
    return LinkMetadata(
      title: _clean(d['title'] as String?),
      // data: URL(base64 로고)은 썸네일이 아니다
      thumbnailUrl: (img != null && !img.startsWith('data:')) ? img : null,
    );
  }

  // ── 일반 사이트 ───────────────────────────────────────────
  static Future<LinkMetadata> _openGraph(String url) async {
    final res = await http.get(Uri.parse(url)).timeout(_timeout);
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    final og = _parseOg(body);
    final pageTitle = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(body)
        ?.group(1);
    return LinkMetadata(
      title: og.title ?? _clean(pageTitle),
      thumbnailUrl: og.thumbnailUrl,
    );
  }

  // ── 공통 ──────────────────────────────────────────────────

  /// og:title / og:image — 속성 순서(property·content)와 따옴표 종류가
  /// 사이트마다 달라 양쪽 순서를 모두 본다.
  static LinkMetadata _parseOg(String html) {
    String? meta(String prop) {
      final a = RegExp(
        '<meta[^>]+property=["\']$prop["\'][^>]*content=["\']([^"\']*)["\']',
        caseSensitive: false,
      ).firstMatch(html);
      final b = a ??
          RegExp(
            '<meta[^>]+content=["\']([^"\']*)["\'][^>]*property=["\']$prop["\']',
            caseSensitive: false,
          ).firstMatch(html);
      return b?.group(1);
    }

    final img = meta('og:image');
    return LinkMetadata(
      title: _clean(meta('og:title')),
      thumbnailUrl: img == null || img.isEmpty ? null : decodeHtmlEntities(img),
    );
  }

  static String? _clean(String? s) {
    if (s == null) return null;
    final t = decodeHtmlEntities(s).trim();
    if (t.isEmpty || _genericTitles.contains(t)) return null;
    return t;
  }

  /// `&#xc870;` `&#50864;` `&amp;` 등 HTML 엔티티를 문자로 되돌린다.
  /// (페이스북 OG는 한글을 전부 16진 엔티티로 내려준다)
  static String decodeHtmlEntities(String s) {
    const named = {
      'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'",
      '#39': "'", 'nbsp': ' ',
    };
    return s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+|#39);'),
        (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x') || e.startsWith('#X')) {
        final code = int.tryParse(e.substring(2), radix: 16);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      }
      if (e.startsWith('#')) {
        final code = int.tryParse(e.substring(1));
        return code == null ? m.group(0)! : String.fromCharCode(code);
      }
      return named[e] ?? m.group(0)!;
    });
  }
}
