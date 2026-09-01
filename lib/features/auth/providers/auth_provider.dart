import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../shared/services/auth/google_auth_service.dart';

// 현재 로그인 상태 스트림
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 현재 유저 (편의용)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

class AuthNotifier extends AsyncNotifier<void> {
  final _auth = FirebaseAuth.instance;
  // appGoogleSignIn — google_auth_service.dart의 전역 단일 인스턴스 사용
  final _db = FirebaseFirestore.instance;

  @override
  Future<void> build() async {}

  /// Google 로그인
  Future<String?> signInWithGoogle() async {
    try {
      state = const AsyncLoading();

      final googleUser = await appGoogleSignIn.signIn();
      if (googleUser == null) {
        state = const AsyncData(null);
        return '로그인이 취소됐어요.';
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      await _createUserDocIfNeeded(userCred.user!);

      state = const AsyncData(null);
      return null; // 성공
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return '로그인 오류: ${e.toString()}';
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await appGoogleSignIn.signOut();
    await _auth.signOut();
  }

  /// 계정 및 모든 데이터 영구 삭제 (Google Play 정책 필수)
  /// 반환값: null = 성공, String = 오류 메시지
  Future<String?> deleteAccount() async {
    try {
      state = const AsyncLoading();

      // Cloud Function 호출 (서버에서 users 문서 + Auth 삭제)
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      await functions.httpsCallable('deleteUserAccount').call();

      // 클라이언트 로그아웃
      await appGoogleSignIn.signOut();
      await _auth.signOut();

      state = const AsyncData(null);
      return null; // 성공
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return '계정 삭제 오류: ${e.toString()}';
    }
  }

  /// 첫 로그인 시 Firestore에 유저 문서 생성
  ///
  /// 실패해도 로그인 자체는 성공 처리한다. 프로필 문서는 편의용이고,
  /// 사용량 카운터는 서버(callGemini)가 없으면 만들어서 쓰기 때문에
  /// 여기서 던지면 멀쩡히 인증된 사용자를 로그인 실패로 되돌리게 된다.
  Future<void> _createUserDocIfNeeded(User user) async {
    try {
      final ref = _db.collection('users').doc(user.uid);
      final doc = await ref.get();
      if (!doc.exists) {
        // dailyUsage / lastUsageDate 는 보안 규칙상 생성 시 기본값만 허용된다.
        // (이후 수정은 서버 Admin SDK만 가능 — 한도 우회 차단)
        await ref.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'dailyUsage': 0,
          'lastUsageDate': '',
          'plan': 'free', // free | byok
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('유저 문서 생성 실패(로그인은 계속 진행): $e');
    }
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
