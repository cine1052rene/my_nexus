import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/tab_defs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final tabFeatures = ref.watch(tabFeaturesProvider);
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;
    final featureMap = tabFeatures.valueOrNull ?? {};

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
                      final i = entry.key;
                      final tab = entry.value;
                      final enabled = featureMap[tab.id] ?? tab.defaultEnabled;
                      return Column(
                        children: [
                          SwitchListTile(
                            secondary: Text(tab.emoji,
                                style: const TextStyle(fontSize: 22)),
                            title: Text(
                              tab.label,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: _tabSubtitle(tab.id),
                            value: enabled,
                            onChanged: (_) =>
                                ref.read(tabFeaturesProvider.notifier).toggle(tab.id),
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
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isPremium
                          ? const Color(0xFFFFF8E1)
                          : const Color(0xFFEDE9FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        isPremium ? '⭐' : '✨',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  title: Text(
                    isPremium ? '프리미엄' : '무료',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    isPremium
                        ? 'Google 로그인으로 자동 연결됨'
                        : 'Google 로그인으로 AI 기능 사용 가능',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPremium
                          ? Colors.amber.withOpacity(0.15)
                          : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPremium ? '프리미엄 ✓' : '활성 ✓',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPremium
                            ? Colors.amber[800]
                            : Colors.green[700],
                      ),
                    ),
                  ),
                ),
                if (!isPremium) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Text(
                      '별도 설정 없이 큐레이션·챗봇·이메일 AI를 바로 사용할 수 있어요.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Firebase 사용량 ──────────────────────────────────
          _SectionTitle('☁️ Firebase 무료 사용량'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _UsageBar(
                    label: '읽기 (Reads)',
                    current: svc.reads,
                    max: FirebaseLimits.firestoreReadsPerDay,
                    color: const Color(0xFF6C63FF),
                  ),
                  const SizedBox(height: 12),
                  _UsageBar(
                    label: '쓰기 (Writes)',
                    current: svc.writes,
                    max: FirebaseLimits.firestoreWritesPerDay,
                    color: const Color(0xFF4CAF50),
                  ),
                  const SizedBox(height: 12),
                  _UsageBar(
                    label: '삭제 (Deletes)',
                    current: svc.deletes,
                    max: FirebaseLimits.firestoreDeletesPerDay,
                    color: const Color(0xFFFF6584),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '세션 기준 카운트 · 무료 한도: 읽기 50K / 쓰기 20K / 삭제 20K (일)',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      svc.resetCounters();
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('카운터 리셋'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

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
                  title:
                      Text(ref.watch(currentUserProvider)?.displayName ?? '사용자'),
                  subtitle:
                      Text(ref.watch(currentUserProvider)?.email ?? ''),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                  title: const Text('로그아웃',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('로그아웃'),
                        content: const Text('로그아웃 할까요?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
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
                    // 1단계: 경고 확인
                    final step1 = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('⚠️ 계정 삭제'),
                        content: const Text(
                          '계정을 삭제하면 모든 저장 데이터가 영구적으로 삭제되며 복구할 수 없습니다.\n\n정말 삭제하시겠습니까?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('계속',
                                style: TextStyle(color: Color(0xFFB00020))),
                          ),
                        ],
                      ),
                    );
                    if (step1 != true || !context.mounted) return;

                    // 2단계: 최종 확인
                    final step2 = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('🗑️ 최종 확인'),
                        content: const Text(
                          '이 작업은 되돌릴 수 없습니다.\n계정과 모든 데이터를 영구 삭제합니다.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB00020)),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('삭제',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (step2 != true || !context.mounted) return;

                    // 계정 삭제 실행
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
                Divider(height: 1, indent: 56),
                ListTile(
                  leading: Text('☁️', style: TextStyle(fontSize: 20)),
                  title: Text('Firebase 프로젝트'),
                  subtitle: Text('my-nexus-hub'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      'hub' => '링크·자료 저장 및 분류',
      'calendar' => '일정 관리 달력',
      'chat' => 'Gemini AI 챗봇',
      'myroom' => 'YouTube·TikTok·Reels 영상 큐레이션',
      _ => null,
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

class _UsageBar extends StatelessWidget {
  final String label;
  final int current;
  final int max;
  final Color color;

  const _UsageBar({
    required this.label,
    required this.current,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (current / max).clamp(0.0, 1.0);
    final isHigh = ratio > 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              '$current / $max',
              style: TextStyle(
                fontSize: 12,
                color: isHigh ? Colors.red : Colors.grey[600],
                fontWeight: isHigh ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.grey[200],
            valueColor:
                AlwaysStoppedAnimation(isHigh ? Colors.red : color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${(ratio * 100).toStringAsFixed(1)}% 사용',
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
