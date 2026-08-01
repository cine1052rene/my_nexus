import 'package:google_sign_in/google_sign_in.dart';

/// 앱 전역 단일 GoogleSignIn 인스턴스
/// - Firebase Auth 로그인 + Calendar + Gmail 모두 이 인스턴스 사용
/// - 스코프는 필요한 시점에 requestScopes()로 증분 요청
final appGoogleSignIn = GoogleSignIn(
  serverClientId:
      '397552928960-1kg2b02o541nof3s0ct06kbiaseb53oh.apps.googleusercontent.com',
  scopes: ['email'],
);

const _calendarScope = 'https://www.googleapis.com/auth/calendar.readonly';
const _gmailReadScope = 'https://www.googleapis.com/auth/gmail.readonly';
const _gmailSendScope = 'https://www.googleapis.com/auth/gmail.send';
const _gmailModifyScope = 'https://www.googleapis.com/auth/gmail.modify';

/// 현재 로그인된 Google 유저의 AccessToken 반환
/// [promptSignIn] = true 면 로그인 다이얼로그까지 띄움
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

/// Calendar 전용 — 스코프가 없으면 요청 후 토큰 반환
Future<String?> getCalendarAccessToken() async {
  try {
    var user = appGoogleSignIn.currentUser;
    user ??= await appGoogleSignIn.signInSilently();
    user ??= await appGoogleSignIn.signIn();
    if (user == null) return null;

    // Calendar 스코프 없으면 증분 요청
    final hasScope =
        await appGoogleSignIn.requestScopes([_calendarScope]);
    if (!hasScope) return null;

    // 스코프 승인 후 토큰 갱신
    user = await appGoogleSignIn.signInSilently(suppressErrors: true) ??
        appGoogleSignIn.currentUser;
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.accessToken;
  } catch (_) {
    return null;
  }
}

/// Gmail 전용 — 스코프가 없으면 요청 후 토큰 반환
Future<String?> getGmailAccessToken() async {
  try {
    var user = appGoogleSignIn.currentUser;
    user ??= await appGoogleSignIn.signInSilently();
    user ??= await appGoogleSignIn.signIn();
    if (user == null) return null;

    final hasScope = await appGoogleSignIn.requestScopes([
      _gmailReadScope,
      _gmailSendScope,
      _gmailModifyScope,
    ]);
    if (!hasScope) return null;

    user = await appGoogleSignIn.signInSilently(suppressErrors: true) ??
        appGoogleSignIn.currentUser;
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.accessToken;
  } catch (_) {
    return null;
  }
}
