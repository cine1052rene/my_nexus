import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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

          // ── Firebase 콘솔 바로가기 ──────────────────────────
          _SectionTitle('🔗 빠른 링크'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🔥', style: TextStyle(fontSize: 20)),
                  title: const Text('Firebase 콘솔'),
                  subtitle: const Text('Firestore 사용량 모니터링'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Text('📊', style: TextStyle(fontSize: 20)),
                  title: const Text('Firestore 데이터 보기'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 앱 정보 ─────────────────────────────────────────
          _SectionTitle('ℹ️ 앱 정보'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Text('🤖', style: TextStyle(fontSize: 20)),
                  title: Text('MyNexus'),
                  subtitle: Text('나만의 비서 앱 v1.0.0'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Text('☁️', style: TextStyle(fontSize: 20)),
                  title: const Text('Firebase 프로젝트'),
                  subtitle: const Text('my-nexus-hub'),
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
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF6C63FF))),
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
