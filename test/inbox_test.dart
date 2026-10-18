import 'package:flutter_test/flutter_test.dart';
import 'package:my_nexus/shared/services/share_intent_service.dart';
import 'package:my_nexus/shared/utils/inbox_utils.dart';

void main() {
  group('SharedPayload 분류', () {
    test('URL이 있으면 링크 (카톡식 "제목 + URL" 포함)', () {
      final p = SharedPayload.fromText('이거 봐봐 https://youtu.be/abc?si=1 대박');
      expect(p!.kind, SharedKind.link);
      expect(p.value, 'https://youtu.be/abc?si=1');
    });
    test('URL이 없으면 메모', () {
      final p = SharedPayload.fromText('  모공 축소 기초 — 토너 먼저  ');
      expect(p!.kind, SharedKind.memo);
      expect(p.value, '모공 축소 기초 — 토너 먼저');
    });
    test('빈 텍스트는 무시', () {
      expect(SharedPayload.fromText('   '), isNull);
    });
    test('네이티브 맵: 이미지 경로', () {
      final p = SharedPayload.fromMap({'imagePath': '/cache/share_1'});
      expect(p!.kind, SharedKind.image);
    });
    test('네이티브 맵: 잘못된 값', () {
      expect(SharedPayload.fromMap(null), isNull);
      expect(SharedPayload.fromMap({'imagePath': ''}), isNull);
    });
  });

  group('titleFromText', () {
    test('캡처 상단의 시계·배터리 줄은 건너뛴다', () {
      expect(
        titleFromText('8:08\n83%\n원팬 잡채 레시피\n재료: 당면', fallback: 'x'),
        '원팬 잡채 레시피',
      );
    });
    test('글자가 없으면 기본 제목', () {
      expect(titleFromText('12:30\n100%', fallback: '캡처'), '캡처');
      expect(titleFromText('', fallback: '메모'), '메모');
    });
    test('40자 초과는 자른다', () {
      final t = titleFromText('가' * 60, fallback: 'x');
      expect(t.length, 41);
      expect(t.endsWith('…'), isTrue);
    });
  });

  test('defaultCaptureTitle', () {
    expect(defaultCaptureTitle(DateTime(2026, 10, 18, 9, 5)), '캡처 10/18 09:05');
  });

  test('clampOcrText', () {
    expect(clampOcrText('a' * 6000).length, 5000);
    expect(clampOcrText('짧음'), '짧음');
  });
}
