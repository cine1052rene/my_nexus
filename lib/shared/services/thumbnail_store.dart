import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

/// 만료되는 SNS 썸네일을 Firebase Storage에 복사해 두는 저장소.
///
/// 인스타·스레드·페이스북·틱톡 CDN 이미지 주소에는 서명 만료(`oe=`,
/// `x-expires=`)가 들어 있어 저장 며칠 뒤 403이 된다.
/// 2026-10-14 확인: 저장된 메타 계열 썸네일 41개 중 39개가 이미 만료.
/// 그래서 링크를 저장한 직후 이미지를 받아 `users/{uid}/thumbs/{linkId}`에
/// 올리고, 링크의 thumbnailUrl을 Storage 주소로 바꾼다.
///
/// - 계정 삭제 시 서버(deleteUserAccount)가 `users/{uid}/` 전체를 지운다.
/// - 링크 삭제 시 [delete]로 함께 지운다.
/// - 실패해도 예외를 던지지 않는다 (원래 주소가 그대로 남을 뿐).
class ThumbnailStore {
  ThumbnailStore._();

  static const bucket = 'gs://my-nexus-hub.firebasestorage.app';

  /// storage.rules의 상한(2MB)보다 작게 잡는다.
  static const _maxBytes = 1500 * 1024;

  static FirebaseStorage get _storage =>
      FirebaseStorage.instanceFor(bucket: bucket);

  /// 만료되는 CDN 주소인지.
  static bool needsCopy(String? url) {
    if (url == null || !url.startsWith('http')) return false;
    if (url.contains('firebasestorage')) return false; // 이미 사본
    final host = Uri.tryParse(url)?.host ?? '';
    return host.contains('fbcdn.net') ||
        host.contains('cdninstagram.com') ||
        host.contains('tiktokcdn') ||
        url.contains('oe=') ||
        url.contains('x-expires=');
  }

  static Reference? _ref(String linkId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _storage.ref('users/$uid/thumbs/$linkId');
  }

  /// [sourceUrl] 이미지를 받아 Storage에 올리고 다운로드 주소를 돌려준다.
  /// 복사가 필요 없거나 실패하면 null.
  static Future<String?> copy(String linkId, String? sourceUrl) async {
    if (!needsCopy(sourceUrl)) return null;
    final ref = _ref(linkId);
    if (ref == null) return null;
    try {
      final res = await http
          .get(Uri.parse(sourceUrl!))
          .timeout(const Duration(seconds: 10));
      final type = res.headers['content-type'] ?? '';
      if (res.statusCode != 200 ||
          !type.startsWith('image/') ||
          res.bodyBytes.isEmpty ||
          res.bodyBytes.length > _maxBytes) {
        return null;
      }
      await ref.putData(res.bodyBytes, SettableMetadata(contentType: type));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// 링크 삭제 시 사본도 지운다 (없으면 조용히 넘어감).
  static Future<void> delete(String linkId) async {
    try {
      await _ref(linkId)?.delete();
    } catch (_) {}
  }
}
