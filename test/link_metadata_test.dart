import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/shared/services/link_metadata_service.dart';

void main() {
  group('decodeHtmlEntities', () {
    test('16진 엔티티 한글', () {
      expect(
        LinkMetadataService.decodeHtmlEntities('&#xc870;&#xd68c; 3.7&#xb9cc;'),
        '조회 3.7만',
      );
    });
    test('BMP 밖 이모지', () {
      expect(LinkMetadataService.decodeHtmlEntities('&#x1f9b5;'), '🦵');
    });
    test('이름·10진 엔티티', () {
      expect(
        LinkMetadataService.decodeHtmlEntities('A &amp; B &#39;x&#39; &quot;y&quot;'),
        'A & B \'x\' "y"',
      );
    });
  });

  group('facebookTitle', () {
    test('조회수 접두부를 버리고 본문을 쓴다', () {
      expect(
        LinkMetadataService.facebookTitle(
            '조회 3.7만회 · 공감 131개 | ✅영상 저장해두고 허리 펴기 | 작성자'),
        '✅영상 저장해두고 허리 펴기',
      );
    });
    test('영문 조회수 접두부', () {
      expect(
        LinkMetadataService.facebookTitle(
            "223K views · 17K reactions | Your knees aren't the problem.\n\nMore"),
        "Your knees aren't the problem.",
      );
    });
    test('긴 본문은 100자로 자른다', () {
      final t = LinkMetadataService.facebookTitle('조회 1회 | ${'가' * 150}')!;
      expect(t.length, 101);
    });
  });
}
