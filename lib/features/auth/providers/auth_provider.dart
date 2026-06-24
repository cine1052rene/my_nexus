import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  final _googleSignIn = GoogleSignIn(
    // google-services.json의 web client id (client_type: 3)
    serverClientId: '397552928960-1kg2b02o541nof3s0ct06kbiaseb53oh.apps.googleusercontent.com',
  );
  final _db = FirebaseFirestore.instance;

  @override
  Future<void> build() async {}

  /// Google 로그인
  Future<String?> signInWithGoogle() async {
    try {
      state = const AsyncLoading();

      final googleUser = await _googleSignIn.signIn();
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
    await _googleSignIn.signOut();
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
      await _googleSignIn.signOut();
      await _auth.signOut();

      state = const AsyncData(null);
      return null; // 성공
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return '계정 삭제 오류: ${e.toString()}';
    }
  }

  /// 첫 로그인 시 Firestore에 유저 문서 생성
  Future<void> _createUserDocIfNeeded(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
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
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
