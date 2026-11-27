import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/features/hub/widgets/save_feedback.dart';
import 'package:my_nexus/shared/utils/link_key.dart';

void main() {
  group('canonicalLinkKey — 같은 콘텐츠는 같은 키', () {
    test('유튜브: 쇼츠·watch·youtu.be·공유 파라미터', () {
      const k = 'yt:abcDEF12345';
      expect(canonicalLinkKey('https://youtube.com/shorts/abcDEF12345?si=xyz'), k);
      expect(canonicalLinkKey('https://www.youtube.com/watch?v=abcDEF12345&t=30'), k);
      expect(canonicalLinkKey('https://youtu.be/abcDEF12345?si=aaa'), k);
      expect(canonicalLinkKey('https://m.youtube.com/watch?v=abcDEF12345'), k);
    });

    test('인스타: p·reel·reels, igsh 무시', () {
      expect(canonicalLinkKey('https://www.instagram.com/reel/C1x2y3/?igsh=abc'),
          'ig:C1x2y3');
      expect(canonicalLinkKey('https://instagram.com/reels/C1x2y3'), 'ig:C1x2y3');
      expect(canonicalLinkKey('https://www.instagram.com/p/C1x2y3/'), 'ig:C1x2y3');
    });

    test('스레드 .net·.com 같은 게시물', () {
      expect(canonicalLinkKey('https://www.threads.net/@kim/post/DAbc12?xmt=1'),
          'th:DAbc12');
      expect(canonicalLinkKey('https://www.threads.com/@kim/post/DAbc12'),
          'th:DAbc12');
    });

    test('틱톡(풀린 주소)·X', () {
      expect(
          canonicalLinkKey(
              'https://www.tiktok.com/@a/video/7312345678901234567?is_from_webapp=1'),
          'tt:7312345678901234567');
      expect(canonicalLinkKey('https://x.com/a/status/123?s=20'), 'x:123');
      expect(canonicalLinkKey('https://twitter.com/a/status/123'), 'x:123');
    });

    test('일반 사이트: utm·fbclid만 지우고 의미 있는 쿼리는 유지', () {
      expect(
          canonicalLinkKey(
              'https://m.blog.naver.com/user/123?utm_source=kakao&fbclid=x'),
          canonicalLinkKey('https://blog.naver.com/user/123/'));
      expect(canonicalLinkKey('https://shop.com/item?id=1'),
          isNot(canonicalLinkKey('https://shop.com/item?id=2')));
    });

    test('다른 콘텐츠는 다른 키', () {
      expect(canonicalLinkKey('https://youtu.be/aaaaaaaaaaa'),
          isNot(canonicalLinkKey('https://youtu.be/bbbbbbbbbbb')));
    });
  });

  group('SaveFeedback.ago', () {
    final now = DateTime(2026, 11, 28, 10);
    test('오늘·어제·일·주·개월', () {
      expect(SaveFeedback.ago(DateTime(2026, 11, 28, 1), now: now), '오늘');
      expect(SaveFeedback.ago(DateTime(2026, 11, 27, 23), now: now), '어제');
      expect(SaveFeedback.ago(DateTime(2026, 11, 23), now: now), '5일 전');
      expect(SaveFeedback.ago(DateTime(2026, 11, 7), now: now), '3주 전');
      expect(SaveFeedback.ago(DateTime(2026, 8, 1), now: now), '3개월 전');
    });
  });
}
