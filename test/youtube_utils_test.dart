import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/shared/utils/youtube_utils.dart';

void main() {
  group('extractYoutubeId', () {
    const id = 'H2LIuTaZtPw';
    final cases = {
      'https://youtube.com/shorts/$id?si=GAt7fY5-upT23pwZ': id,
      'https://www.youtube.com/shorts/$id': id,
      'https://m.youtube.com/shorts/$id': id,
      'https://www.youtube.com/watch?v=$id': id,
      'https://www.youtube.com/watch?feature=share&v=$id': id,
      'https://m.youtube.com/watch?v=$id&t=30s': id,
      'https://music.youtube.com/watch?v=$id&list=RD': id,
      'https://youtu.be/$id?si=abc': id,
      'https://www.youtube.com/embed/$id': id,
      'https://www.youtube.com/live/$id?feature=shared': id,
    };
    cases.forEach((url, expected) {
      test(url, () => expect(extractYoutubeId(url), expected));
    });

    test('채널·재생목록 주소는 null', () {
      expect(extractYoutubeId('https://www.youtube.com/@channel'), isNull);
      expect(
        extractYoutubeId('https://www.youtube.com/playlist?list=PL123'),
        isNull,
      );
    });
  });
}
