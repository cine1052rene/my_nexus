import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/shared/services/thumbnail_store.dart';

void main() {
  group('ThumbnailStore.needsCopy', () {
    test('메타·틱톡 CDN의 만료 주소는 복사 대상', () {
      expect(ThumbnailStore.needsCopy(
          'https://scontent-gmp1-1.xx.fbcdn.net/v/t51.71878-15/1.jpg?oe=6720ABCD'), isTrue);
      expect(ThumbnailStore.needsCopy(
          'https://scontent.cdninstagram.com/v/t51/2.jpg?oe=6720ABCD'), isTrue);
      expect(ThumbnailStore.needsCopy(
          'https://p16-sign-sg.tiktokcdn.com/obj/x.jpeg?x-expires=1760000000'), isTrue);
    });
    test('유튜브·이미 복사한 주소·빈 값은 대상 아님', () {
      expect(ThumbnailStore.needsCopy(
          'https://img.youtube.com/vi/abc/maxresdefault.jpg'), isFalse);
      expect(ThumbnailStore.needsCopy(
          'https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fu%2Fthumbs%2F1?alt=media&token=t'), isFalse);
      expect(ThumbnailStore.needsCopy(null), isFalse);
      expect(ThumbnailStore.needsCopy('data:image/png;base64,AAA'), isFalse);
    });
  });
}
