import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 무료 사용 한도.
///
/// 실제 기준은 Firestore `config/limits` 문서이고 서버(callGemini)도 같은
/// 문서를 본다. 콘솔에서 값을 바꾸면 앱 업데이트 없이 서버·앱에 함께 반영된다.
///
/// ⚠️ 화면에 한도 숫자를 쓸 때는 반드시 이 값을 쓸 것.
/// 문구에 '30회'처럼 숫자를 박아두면 설정을 바꿔도 그 문구만 옛날 값으로
/// 남아, 표시와 실제 차단이 어긋난다(실제로 그렇게 어긋난 적이 있다).
class UsageLimits {
  final int daily;
  final int monthly;
  const UsageLimits({required this.daily, required this.monthly});

  /// 문서를 아직 못 읽었을 때만 쓰는 임시값.
  /// **서버의 DEFAULT_LIMITS와 같게 유지할 것.**
  static const fallback = UsageLimits(daily: 10, monthly: 100);
}

/// 한도 설정 구독 — 콘솔에서 숫자를 바꾸면 즉시 반영된다.
final usageLimitsProvider = StreamProvider<UsageLimits>((ref) {
  return FirebaseFirestore.instance.doc('config/limits').snapshots().map((doc) {
    final d = doc.data();
    if (d == null) return UsageLimits.fallback;
    return UsageLimits(
      daily: (d['dailyFree'] as num?)?.toInt() ?? UsageLimits.fallback.daily,
      monthly:
          (d['monthlyFree'] as num?)?.toInt() ?? UsageLimits.fallback.monthly,
    );
  });
});
