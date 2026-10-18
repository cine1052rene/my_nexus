import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _channel = MethodChannel('com.personal.nexus.my_nexus/share');

// 공유된 URL을 담는 StateProvider
final sharedUrlProvider = StateProvider<String?>((ref) => null);

enum SharedKind { link, memo, image }

/// 다른 앱에서 공유로 받은 내용.
///
/// 예전에는 텍스트에서 URL만 뽑고 URL이 없으면 버렸다. 설문(n=22)에서
/// 사람들이 실제로 저장하는 곳은 카톡 나와의 채팅(17)·화면 캡처(15)였고,
/// 그걸 받으려고 메모(텍스트)와 이미지도 받는다.
class SharedPayload {
  final SharedKind kind;
  final String value; // link: URL / memo: 원문 / image: 캐시 파일 경로

  const SharedPayload._(this.kind, this.value);

  /// 네이티브가 보낸 맵 {text} 또는 {imagePath}를 분류한다.
  static SharedPayload? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final imagePath = raw['imagePath'];
    if (imagePath is String && imagePath.isNotEmpty) {
      return SharedPayload._(SharedKind.image, imagePath);
    }
    final text = raw['text'];
    if (text is String) return fromText(text);
    return null;
  }

  /// 텍스트 공유: URL이 있으면 링크, 없으면 메모.
  /// (카카오톡은 "제목 + URL"을 같이 보내므로 URL이 있으면 링크로 본다)
  static SharedPayload? fromText(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final url = extractUrl(t);
    if (url != null) return SharedPayload._(SharedKind.link, url);
    return SharedPayload._(SharedKind.memo, t);
  }

  static String? extractUrl(String text) {
    final match = RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(text);
    return match?.group(0);
  }
}

class ShareIntentService {
  /// 앱 시작 시 공유된 내용 가져오기 (cold start)
  static Future<SharedPayload?> getSharedPayload() async {
    try {
      return SharedPayload.fromMap(await _channel.invokeMethod('getSharedPayload'));
    } catch (_) {
      return null;
    }
  }

  /// 앱 실행 중 공유 수신 리스너 (warm start)
  static void listen(void Function(SharedPayload payload) onReceived) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedPayload') {
        final p = SharedPayload.fromMap(call.arguments);
        if (p != null) onReceived(p);
      }
    });
  }
}
