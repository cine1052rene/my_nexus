import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../.././../core/constants/tab_defs.dart';

// ── Gemini API 키 ─────────────────────────────────────────────
const _keyGeminiApiKey = 'gemini_api_key';

class GeminiApiKeyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGeminiApiKey) ?? '';
  }

  Future<void> save(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGeminiApiKey, key.trim());
    state = AsyncValue.data(key.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGeminiApiKey);
    state = const AsyncValue.data('');
  }
}

final geminiApiKeyProvider =
    AsyncNotifierProvider<GeminiApiKeyNotifier, String>(GeminiApiKeyNotifier.new);

// ── 탭 기능 온오프 ─────────────────────────────────────────────
String _prefKey(String tabId) => 'tab_enabled_$tabId';

class TabFeaturesNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final tab in kToggleableTabs)
        tab.id: prefs.getBool(_prefKey(tab.id)) ?? tab.defaultEnabled,
    };
  }

  Future<void> toggle(String tabId) async {
    final current = state.valueOrNull ?? {};
    final newVal = !(current[tabId] ?? true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(tabId), newVal);
    state = AsyncData({...current, tabId: newVal});
  }

  bool isEnabled(String tabId) {
    final map = state.valueOrNull;
    if (map == null) {
      // 로딩 중엔 기본값 사용
      return kAllTabs
          .firstWhere((t) => t.id == tabId,
              orElse: () => kAllTabs.first)
          .defaultEnabled;
    }
    return map[tabId] ?? true;
  }
}

final tabFeaturesProvider =
    AsyncNotifierProvider<TabFeaturesNotifier, Map<String, bool>>(
  TabFeaturesNotifier.new,
);
