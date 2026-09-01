import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/tab_defs.dart';
import '../../../shared/services/ai/gemini_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final tabFeatures = ref.watch(tabFeaturesProvider);
    final isPremium   = ref.watch(isPremiumProvider).valueOrNull ?? false;
    final apiKey      = ref.watch(geminiApiKeyProvider).valueOrNull ?? '';
    final featureMap  = tabFeatures.valueOrNull ?? {};

    // 키가 있으면 GeminiService가 서버를 거치지 않고 그 키로 직접 호출한다.
    // 프리미엄 여부와 무관하게 이게 실제 사용 경로를 결정한다.
    final usingOwnKey = apiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── 탭 기능 설정 ──────────────────────────────────────
          _SectionTitle('📱 탭 기능 설정'),
          Text(
            '사용하지 않는 탭을 숨길 수 있어요 (설정 탭은 항상 표시)',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Card(
            child: tabFeatures.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: kToggleableTabs.asMap().entries.map((entry) {
                      final i   = entry.key;
                      final tab = entry.value;
                      final enabled = featureMap[tab.id] ?? tab.defaultEnabled;
                      return Column(
                        children: [
                          SwitchListTile(
                            secondary: Text(tab.emoji,
                                style: const TextStyle(fontSize: 22)),
                            title: Text(tab.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: _tabSubtitle(tab.id),
                            value: enabled,
                            onChanged: (_) => ref
                                .read(tabFeaturesProvider.notifier)
                                .toggle(tab.id),
                          ),
                          if (i < kToggleableTabs.length - 1)
                            const Divider(height: 1, indent: 56),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // ── AI 플랜 ────────────────────────────────────────────
          _SectionTitle('🤖 AI 플랜'),
          Card(
            child: Column(
              children: [
                // 현재 플랜 상태
                //
                // 실제 분기 기준은 '프리미엄 여부'가 아니라 **어느 쿼터를 쓰는가**다.
                // GeminiService는 저장된 키가 있으면 무조건 그 키로 직접 호출하고,
                // 없을 때만 서버(Functions)를 탄다. 그래서 키가 있으면
                // 프리미엄이든 무료든 한도와 무관하게 무제한이다.
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: usingOwnKey
                          ? const Color(0xFFE8F5E9)
                          : isPremium
                              ? const Color(0xFFFFF8E1)
                              : const Color(0xFFEDE9FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        usingOwnKey ? '🔑' : (isPremium ? '⭐' : '✨'),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  title: Text(
                    usingOwnKey ? '내 API 키' : (isPremium ? '프리미엄' : '무료'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    usingOwnKey
                        ? '내 Gemini 키로 무제한 사용 중'
                        : isPremium
                            ? '일일 한도 없이 사용'
                            : '일 30회 AI 무료 사용',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      // 내 키 사용 중이거나 무료면 초록, 프리미엄만 앰버
                      color: (isPremium && !usingOwnKey)
                          ? Colors.amber.withOpacity(0.15)
                          : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      usingOwnKey
                          ? '무제한 ✓'
                          : (isPremium ? '프리미엄 ✓' : '활성 ✓'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: usingOwnKey
                            ? Colors.green[700]
                            : isPremium
                                ? Colors.amber[800]
                                : Colors.green[700],
                      ),
                    ),
                  ),
                ),

                // 서버 쿼터를 쓰는 동안만 무료 한도 안내를 보여준다
                if (!usingOwnKey && !isPremium) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Text(
                      '별도 설정 없이 큐레이션·챗봇·이메일 AI를 바로 사용할 수 있어요.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ],

                // API 키 연동 — 모든 사용자에게 노출한다.
                //
                // 이전에는 isPremium일 때만 보여줬는데, BYOK는 애초에
                // "사용자가 자기 키로 자기 비용을 부담"하는 장치라
                // 한도에 걸리는 무료 사용자에게 가장 필요하다.
                // 정작 그들에게 숨겨져 있어서 우회 수단이 없었다.
                ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: apiKey.isNotEmpty
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        apiKey.isNotEmpty ? Icons.key : Icons.key_outlined,
                        size: 18,
                        color: apiKey.isNotEmpty
                            ? Colors.green[700]
                            : Colors.grey[500],
                      ),
                    ),
                    // ListTile trailing에 뱃지+화살표가 있어 제목 폭이 좁다.
                    // 길면 두 줄로 깨지므로 짧게 유지할 것.
                    title: const Text('내 API 키 사용',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      apiKey.isNotEmpty
                          ? _maskKey(apiKey)
                          : 'Google AI Studio 키를 입력하세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: apiKey.isNotEmpty
                            ? Colors.green[700]
                            : Colors.grey[500],
                        fontFamily: apiKey.isNotEmpty ? 'monospace' : null,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (apiKey.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('연동됨',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w700)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('미연동',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600)),
                          ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: Colors.grey),
                      ],
                    ),
                    onTap: () => _showApiKeyDialog(context, apiKey),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      apiKey.isNotEmpty
                          ? '✓ 내 키로 호출 중이라 일일 한도가 적용되지 않아요'
                          : '내 키를 연동하면 일일 30회 한도 없이 사용할 수 있어요 (사용료는 본인 Google 계정에 청구)',
                      style: TextStyle(
                        fontSize: 11,
                        color: apiKey.isNotEmpty
                            ? Colors.green[600]
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 계정 ──────────────────────────────────────────────
          _SectionTitle('👤 계정'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        ref.watch(currentUserProvider)?.photoURL != null
                            ? NetworkImage(
                                ref.watch(currentUserProvider)!.photoURL!)
                            : null,
                    child: ref.watch(currentUserProvider)?.photoURL == null
                        ? const Text('👤')
                        : null,
                  ),
                  title: Text(
                      ref.watch(currentUserProvider)?.displayName ?? '사용자'),
                  subtitle:
                      Text(ref.watch(currentUserProvider)?.email ?? ''),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading:
                      const Icon(Icons.logout, color: Colors.red, size: 20),
                  title: const Text('로그아웃',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      // ⚠️ 반드시 다이얼로그 자신의 context로 pop해야 한다.
                      // 바깥 화면의 context를 쓰면 showDialog(useRootNavigator:true)가
                      // 띄운 루트 네비게이터의 다이얼로그가 아니라 go_router 쉘의
                      // 현재 페이지가 pop돼서, 화면이 검게 비고 await은 영원히 안 끝난다.
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('로그아웃'),
                        content: const Text('로그아웃 할까요?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: const Text('취소')),
                          TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              child: const Text('로그아웃',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(authNotifierProvider.notifier)
                          .signOut();
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_forever,
                      color: Color(0xFFB00020), size: 20),
                  title: const Text('계정 및 데이터 삭제',
                      style: TextStyle(
                          color: Color(0xFFB00020),
                          fontWeight: FontWeight.w600)),
                  subtitle: const Text('모든 데이터가 영구 삭제됩니다',
                      style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    final step1 = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('⚠️ 계정 삭제'),
                        content: const Text(
                          '계정을 삭제하면 모든 저장 데이터가 영구적으로 삭제되며 복구할 수 없습니다.\n\n정말 삭제하시겠습니까?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: const Text('계속',
                                style: TextStyle(color: Color(0xFFB00020))),
                          ),
                        ],
                      ),
                    );
                    if (step1 != true || !context.mounted) return;

                    final step2 = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('🗑️ 최종 확인'),
                        content: const Text(
                          '이 작업은 되돌릴 수 없습니다.\n계정과 모든 데이터를 영구 삭제합니다.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text('취소'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB00020)),
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: const Text('삭제',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (step2 != true || !context.mounted) return;

                    final err = await ref
                        .read(authNotifierProvider.notifier)
                        .deleteAccount();

                    if (!context.mounted) return;
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('오류: $err'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 앱 정보 ────────────────────────────────────────────
          _SectionTitle('ℹ️ 앱 정보'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Text('🤖', style: TextStyle(fontSize: 20)),
                  title: Text('MyNexus'),
                  subtitle: Text('나만의 비서 앱 v1.0.0'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// API 키를 앞 8자 + 뒤 4자만 남기고 가린다.
  /// 짧은 문자열이 들어와도 substring이 터지지 않도록 길이를 먼저 확인한다.
  static String _maskKey(String key) {
    if (key.length <= 12) return '••••';
    return '${key.substring(0, 8)}••••${key.substring(key.length - 4)}';
  }

  // ── API 키 연동 다이얼로그 ─────────────────────────────────────
  Future<void> _showApiKeyDialog(BuildContext context, String currentKey) async {
    final ctrl = TextEditingController(text: currentKey);
    bool obscure = true;
    bool validating = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('🔑 Gemini API 키 연동'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Google AI Studio (aistudio.google.com)에서 발급받은 API 키를 입력하세요.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              // 2026년 9월부터 Gemini API가 구형 Standard 키를 전부 거부한다.
              // 예전에 만든 키를 그대로 넣으면 원인을 모른 채 실패하므로 미리 안내한다.
              Text(
                '오래전에 발급한 키는 더 이상 동작하지 않을 수 있어요. '
                '실패하면 AI Studio에서 키를 새로 발급받아 주세요.',
                style: TextStyle(fontSize: 11, color: Colors.orange[800]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'AIza...',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                        size: 18),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Text(
                '키는 이 기기에만 저장되며 서버로 전송되지 않습니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              if (validating) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('키 유효성 확인 중...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            // 삭제 버튼 (키가 있을 때)
            if (currentKey.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await ref.read(geminiApiKeyProvider.notifier).clear();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API 키가 삭제됐어요')),
                    );
                  }
                },
                child: const Text('키 삭제',
                    style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: validating
                  ? null
                  : () async {
                      final key = ctrl.text.trim();
                      if (key.isEmpty) return;

                      setDlgState(() => validating = true);
                      final valid = await GeminiService.validateApiKey(key);
                      if (!ctx.mounted) return;

                      if (!valid) {
                        setDlgState(() => validating = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('❌ 유효하지 않은 API 키예요'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      await ref.read(geminiApiKeyProvider.notifier).save(key);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ API 키 연동 완료!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child: const Text('연동',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  Widget? _tabSubtitle(String tabId) {
    if (tabId == 'email') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('메일 확인 및 AI 관리',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.info_outline, size: 11, color: Colors.orange[700]),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  'Google CASA 검토 후 활성화 권장',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      );
    }
    final desc = switch (tabId) {
      'hub'      => '링크·자료 저장 및 분류',
      'calendar' => '일정 관리 달력',
      'chat'     => 'Gemini AI 챗봇',
      'myroom'   => 'YouTube·TikTok·Reels 영상 큐레이션',
      _          => null,
    };
    return desc != null
        ? Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[500]))
        : null;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF6C63FF))),
      );
}
