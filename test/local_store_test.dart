import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_nexus/shared/services/local_store.dart';

/// 로그아웃·계정 삭제 시 기기에 남는 사용자 데이터 정리 검증.
///
/// 여기서 뭔가 새면 그건 단순 잔류가 아니라 자격증명 유출이다.
/// (BYOK Gemini 키 → 남의 쿼터 사용, IMAP 비밀번호 → 평문 메일 계정 탈취)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'gemini_api_key': 'AIzaSy-SECRET-BYOK-KEY',
      'email_accounts': '["{\\"id\\":\\"imap_a\\"}"]',
      'email_pw_imap_a': 'plaintext-password-a',
      'email_pw_imap_b': 'plaintext-password-b',
      'tab_enabled_mail': false,
      'tab_enabled_hub': true,
    });
  });

  test('BYOK 키와 메일 계정 목록이 삭제된다', () async {
    await LocalStore.clearUserScopedData();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('gemini_api_key'), isNull,
        reason: 'BYOK 키가 남으면 다음 사용자가 남의 쿼터로 Gemini를 호출한다');
    expect(prefs.getString('email_accounts'), isNull,
        reason: '메일 주소는 개인정보다');
  });

  test('IMAP 비밀번호가 접두사 스캔으로 전부 삭제된다', () async {
    await LocalStore.clearUserScopedData();
    final prefs = await SharedPreferences.getInstance();

    // 계정 목록에 없는(=고아가 된) 비밀번호까지 지워져야 한다.
    // 목록에서 키 이름을 역산하는 방식이면 email_pw_imap_b가 그대로 남는다.
    expect(prefs.getString('email_pw_imap_a'), isNull);
    expect(prefs.getString('email_pw_imap_b'), isNull);
    expect(prefs.getKeys().where((k) => k.startsWith('email_pw_')), isEmpty);
  });

  test('기기 설정(탭 표시 여부)은 유지된다', () async {
    await LocalStore.clearUserScopedData();
    final prefs = await SharedPreferences.getInstance();

    // 계정이 아니라 기기에 귀속되는 값이고 개인정보도 아니다.
    expect(prefs.getBool('tab_enabled_mail'), false);
    expect(prefs.getBool('tab_enabled_hub'), true);
  });

  test('두 번 호출해도 안전하다', () async {
    await LocalStore.clearUserScopedData();
    await LocalStore.clearUserScopedData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('gemini_api_key'), isNull);
  });

  test('지울 게 없어도 예외가 나지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.clearUserScopedData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
