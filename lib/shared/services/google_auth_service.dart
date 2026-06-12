import 'package:google_sign_in/google_sign_in.dart';

/// 앱 전역 GoogleSignIn 인스턴스 — Calendar + Gmail 스코프 통합
/// 여러 인스턴스를 만들면 충돌이 생기므로 반드시 이 인스턴스만 사용
final appGoogleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.modify',
  ],
);

/// 현재 로그인된 Google 유저의 AccessToken 반환
/// [promptSignIn] = true이면 로그인 다이얼로그까지 띄움
Future<String?> getGoogleAccessToken({bool promptSignIn = false}) async {
  try {
    var user = appGoogleSignIn.currentUser;
    user ??= await appGoogleSignIn.signInSilently();
    if (user == null && promptSignIn) {
      user = await appGoogleSignIn.signIn();
    }
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.accessToken;
  } catch (_) {
    return null;
  }
}
