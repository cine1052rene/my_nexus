import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _channel = MethodChannel('com.personal.nexus.my_nexus/share');

// 공유된 URL을 담는 StateProvider
final sharedUrlProvider = StateProvider<String?>((ref) => null);

class ShareIntentService {
  /// 앱 시작 시 Android로부터 공유된 텍스트 가져오기 (cold start)
  static Future<String?> getSharedText() async {
    try {
      final text = await _channel.invokeMethod<String?>('getSharedText');
      return _extractUrl(text);
    } catch (_) {
      return null;
    }
  }

  /// 앱 실행 중 공유 인텐트 수신 리스너 등록 (warm start)
  static void listenForSharedText(void Function(String url) onReceived) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText' && call.arguments != null) {
        final url = _extractUrl(call.arguments as String);
        if (url != null) onReceived(url);
      }
    });
  }

  /// 텍스트에서 URL 추출 (카카오톡은 텍스트+URL 같이 옴)
  static String? _extractUrl(String? text) {
    if (text == null || text.isEmpty) return null;
    final urlRegex = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    return match?.group(0) ?? (text.startsWith('http') ? text : null);
  }
}
