import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

/// 원격 기능 스위치 — Firestore `config/features` 문서.
///
/// 새 기능을 앱 업데이트 없이 켜고 끄기 위한 장치다. 콘솔에서 값을
/// false로 바꾸면 이미 설치된 앱도 즉시 이전 동작으로 돌아간다.
/// 문서가 없거나 읽지 못하면 **꺼진 쪽**으로 동작한다(검증 전 기능이
/// 의도치 않게 켜지지 않도록).
class FeatureFlags {
  /// 메모·캡처(이미지+글자 인식) 저장. 2026-10-18 도입, 베타 검증용.
  final bool captureInbox;

  /// 구글 캘린더 연동 버튼. calendar.readonly는 구글 OAuth 심사 대상(민감 스코프)이라
  /// 심사 전에는 일반 사용자에게 "확인되지 않은 앱" 경고가 뜨거나 차단된다.
  /// 심사 통과 후 콘솔에서 true로 켜면 앱 업데이트 없이 버튼이 나타난다. (2026-11-19)
  final bool googleCalendar;

  const FeatureFlags({required this.captureInbox, required this.googleCalendar});

  static const off = FeatureFlags(captureInbox: false, googleCalendar: false);
}

final featureFlagsProvider = StreamProvider<FeatureFlags>((ref) {
  // config 문서는 로그인 사용자만 읽을 수 있다. 계정이 바뀌면 다시 구독.
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(FeatureFlags.off);
  return FirebaseFirestore.instance
      .doc('config/features')
      .snapshots()
      .map((doc) {
        final d = doc.data();
        return FeatureFlags(
          captureInbox: d?['captureInbox'] == true,
          googleCalendar: d?['googleCalendar'] == true,
        );
      })
      .handleError((_) => FeatureFlags.off);
});

/// 구글 캘린더 연동 버튼 표시 여부 (기능 스위치 config/features.googleCalendar)
final googleCalendarFeatureProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagsProvider).valueOrNull?.googleCalendar ?? false;
});

/// 화면에서 바로 쓰는 값 (로딩 중·오류는 꺼짐으로 취급)
final captureInboxEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagsProvider).valueOrNull?.captureInbox ?? false;
});
