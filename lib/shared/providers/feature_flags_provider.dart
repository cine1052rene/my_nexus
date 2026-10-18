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

  const FeatureFlags({required this.captureInbox});

  static const off = FeatureFlags(captureInbox: false);
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
        return FeatureFlags(captureInbox: d?['captureInbox'] == true);
      })
      .handleError((_) => FeatureFlags.off);
});

/// 화면에서 바로 쓰는 값 (로딩 중·오류는 꺼짐으로 취급)
final captureInboxEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagsProvider).valueOrNull?.captureInbox ?? false;
});
