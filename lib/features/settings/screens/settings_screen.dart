import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // 저장된 키 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(geminiApiKeyProvider).valueOrNull ?? '';
      _apiKeyCtrl.text = saved;
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    final apiKeyAsync = ref.watch(geminiApiKeyProvider);
    final savedKey = apiKeyAsync.valueOrNull ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Gemini API 키 ───────────────────────────────────
          _SectionTitle('🤖 Gemini API 키'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        savedKey.isNotEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: savedKey.isNotEmpty ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        savedKey.isNotEmpty ? '키가 설정되어 있어요' : 'API 키가 없어요',
                        style: TextStyle(
                          fontSize: 12,
                          color: savedKey.isNotEmpty ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'AIza...',
                      labelText: 'Gemini API Key',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await ref.read(geminiApiKeyProvider.notifier).save(_apiKeyCtrl.text);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ API 키가 저장됐어요')),
                              );
                            }
                          },
                          child: const Text('저장'),
                        ),
                      ),
                      if (savedKey.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            await ref.read(geminiApiKeyProvider.notifier).clear();
                            _apiKeyCtrl.clear();
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('삭제'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Google AI Studio (aistudio.google.com)에서 무료로 발급받을 수 있어요.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Firebase 사용량 ─────────────────────────────────
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
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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

          // ── 계정 ────────────────────────────────────────────
          _SectionTitle('👤 계정'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: ref.watch(currentUserProvider)?.photoURL != null
                        ? NetworkImage(ref.watch(currentUserProvider)!.photoURL!)
                        : null,
                    child: ref.watch(currentUserProvider)?.photoURL == null
                        ? const Text('👤')
                        : null,
                  ),
                  title: Text(ref.watch(currentUserProvider)?.displayName ?? '사용자'),
                  subtitle: Text(ref.watch(currentUserProvider)?.email ?? ''),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                  title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('로그아웃'),
                        content: const Text('로그아웃 할까요?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                          TextButton(onPressed: () => Navigator.pop(context, true),
                              child: const Text('로그아웃', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(authNotifierProvider.notifier).signOut();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 앱 정보 ─────────────────────────────────────────
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
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF6C63FF))),
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
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
            valueColor: AlwaysStoppedAnimation(isHigh ? Colors.red : color),
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
