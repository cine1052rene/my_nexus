import 'package:cloud_firestore/cloud_firestore.dart';

/// AI 원격 설정 — Firestore `config/ai` 문서.
///
/// 서버 경로의 회사·모델은 서버가 같은 문서를 직접 읽으므로 앱은 몰라도 된다.
/// 앱이 읽는 건 **개인 키(BYOK) 경로의 모델명** 하나뿐이다.
/// 콘솔에서 `byokModel`을 바꾸면 앱 업데이트 없이 BYOK 사용자 모델이 바뀐다.
/// (예전엔 상수라, 구글이 모델을 종료하면 앱 업데이트 전까지 BYOK만 깨졌다)
class AiConfig {
  AiConfig._();

  /// 문서가 없거나 읽기에 실패했을 때 쓰는 값.
  /// functions/ai/index.js 의 DEFAULT.model 과 같게 유지할 것.
  static const fallbackByokModel = 'gemini-3.1-flash-lite';

  static const _cacheTtl = Duration(minutes: 10);
  static String? _byokModel;
  static DateTime? _cachedAt;

  static Future<String> byokModel() async {
    final now = DateTime.now();
    if (_byokModel != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheTtl) {
      return _byokModel!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .doc('config/ai')
          .get()
          .timeout(const Duration(seconds: 3));
      final v = doc.data()?['byokModel'];
      _byokModel =
          (v is String && _validModelName(v)) ? v.trim() : fallbackByokModel;
    } catch (_) {
      // 설정을 못 읽었다고 AI를 막을 이유는 없다 — 기본 모델로 진행.
      _byokModel ??= fallbackByokModel;
    }
    _cachedAt = now;
    return _byokModel!;
  }

  /// 모델명은 URL 경로에 들어가므로 영숫자·점·하이픈·밑줄만 허용한다.
  static bool _validModelName(String v) =>
      RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(v.trim());
}
