import 'package:shared_preferences/shared_preferences.dart';

/// 기기에 저장된 **사용자 귀속 데이터** 정리 담당.
///
/// 로그아웃·계정 삭제 시 SharedPreferences를 그대로 두면, 같은 기기를
/// 쓰는 다음 사용자에게 이전 사용자의 것이 그대로 넘어간다.
/// 특히 아래 둘은 그냥 잔류가 아니라 **자격증명 유출**이다.
///   - `gemini_api_key`  : BYOK Gemini API 키 (다음 사용자가 남의 쿼터로 호출)
///   - `email_pw_*`      : IMAP 계정 비밀번호 (평문 저장)
///
/// Play 정책상 계정 삭제 시 사용자 데이터는 전부 지워져야 하는데,
/// 서버(recursiveDelete)만 지우고 기기 로컬을 안 지우면 요건 미충족이다.
class LocalStore {
  LocalStore._();

  /// 사용자 귀속 키 (로그아웃/탈퇴 시 삭제 대상)
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyEmailAccounts = 'email_accounts';
  static const _prefixEmailPassword = 'email_pw_';

  /// 기기 설정이라 유지하는 키의 접두사 (탭 표시 여부 등)
  /// 개인정보가 아니고 계정이 아니라 기기에 귀속되는 값이다.
  static const _prefixDeviceSetting = 'tab_enabled_';

  /// 로그아웃·계정 삭제 시 호출.
  ///
  /// 알려진 키를 지우는 데서 그치지 않고 `email_pw_` 접두사를 **훑어서**
  /// 지운다. 계정 목록(`email_accounts`)이 먼저 날아가거나 저장에 실패한
  /// 경우, 키 이름을 목록에서 역산하는 방식이면 비밀번호만 기기에 남는다.
  static Future<void> clearUserScopedData() async {
    final prefs = await SharedPreferences.getInstance();

    final toRemove = <String>{_keyGeminiApiKey, _keyEmailAccounts};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefixEmailPassword)) toRemove.add(key);
    }

    for (final key in toRemove) {
      if (key.startsWith(_prefixDeviceSetting)) continue;
      await prefs.remove(key);
    }
  }
}
