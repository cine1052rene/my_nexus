import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/shared/utils/tag_utils.dart';

void main() {
  group('parseTags — 저장 형식은 # 없는 순수 문자열', () {
    test('쉼표 구분 (기존 방식) 유지', () {
      expect(parseTags('뜨개질, 초보, 겨울'), ['뜨개질', '초보', '겨울']);
    });

    test('# 접두사는 제거된다', () {
      // 값에 #이 남으면 화면에 '##태그'로 나오고, 같은 이름의 기존 태그와
      // 다른 태그로 취급돼 필터가 갈라진다.
      expect(parseTags('#뜨개질 #초보'), ['뜨개질', '초보']);
    });

    test('# 방식과 쉼표 방식을 섞어 써도 된다', () {
      expect(parseTags('#뜨개질, 초보 #겨울'), ['뜨개질', '초보', '겨울']);
    });

    test('# 만 남은 입력은 버려진다', () {
      // '#' 버튼만 누르고 안 쓴 경우. 예전 데이터에 이런 태그가 63건 있었다.
      expect(parseTags('#'), isEmpty);
      expect(parseTags('뜨개질 # 초보'), ['뜨개질', '초보']);
    });

    test('중복 태그는 하나로 합쳐지고 순서는 유지된다', () {
      expect(parseTags('뜨개질, #뜨개질, 초보'), ['뜨개질', '초보']);
    });

    test('빈 입력·공백만 있는 입력', () {
      expect(parseTags(''), isEmpty);
      expect(parseTags('   ,  , '), isEmpty);
    });
  });

  group('extractHashtags — 마크다운 제목을 태그로 오인하지 않는다', () {
    test('일반 해시태그는 정상 추출', () {
      expect(extractHashtags('#뜨개질 #초보 재밌다'), ['뜨개질', '초보']);
    });

    test('마크다운 제목에서 태그 "#" 가 생기지 않는다', () {
      // 예전 정규식 #(\S+) 은 '## 📌 개요' 의 두 번째 #을 잡아 태그 "#" 를
      // 만들었다. 큐레이션할 때마다 쓰레기 태그가 쌓이던 원인.
      const md = '## 📌 개요\n내용\n### 세부\n## 🔖 태그\n#요리 #레시피';
      expect(extractHashtags(md), ['요리', '레시피']);
    });

    test('# 뒤에 공백만 있으면 추출하지 않는다', () {
      expect(extractHashtags('# '), isEmpty);
      expect(extractHashtags('제목 # 본문'), isEmpty);
    });

    test('중복 제거', () {
      expect(extractHashtags('#요리 #요리 #레시피'), ['요리', '레시피']);
    });
  });
}
