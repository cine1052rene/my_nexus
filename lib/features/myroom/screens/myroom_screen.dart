import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_clip.dart';
import '../providers/myroom_provider.dart';
import '../widgets/clip_card.dart';
import '../widgets/add_clip_sheet.dart';

// 플랫폼 필터 옵션
const _platformFilters = [
  ('all', '전체', '🎬'),
  ('youtube', 'YouTube', '▶️'),
  ('shorts', 'Shorts', '🩳'),
  ('tiktok', 'TikTok', '🎵'),
  ('reels', 'Reels', '📸'),
  ('clip', '클립', '📎'),
  ('other', '기타', '🔗'),
];

class MyroomScreen extends ConsumerWidget {
  const MyroomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(myroomPlatformProvider);
    final search = ref.watch(myroomSearchProvider);
    final clipsAsync = ref.watch(filteredClipsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎬 마이룸'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // 검색바
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '제목, 메모, 태그 검색...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                ref.read(myroomSearchProvider.notifier).state = '',
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      ref.read(myroomSearchProvider.notifier).state = v,
                ),
              ),
              // 플랫폼 필터 칩
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _platformFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final (id, label, emoji) = _platformFilters[i];
                    final selected = platform == id;
                    return FilterChip(
                      label: Text('$emoji $label'),
                      selected: selected,
                      onSelected: (_) =>
                          ref.read(myroomPlatformProvider.notifier).state = id,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: clipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (clips) {
          if (clips.isEmpty) {
            return _EmptyState(
              onAdd: () => _showAddSheet(context),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemCount: clips.length,
            itemBuilder: (ctx, i) {
              final clip = clips[i];
              return ClipCard(
                clip: clip,
                onEdit: () => _showEditSheet(context, clip),
                onDelete: () => _confirmDelete(context, ref, clip),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('영상 추가'),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddClipSheet(),
    );
  }

  void _showEditSheet(BuildContext context, VideoClip clip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClipSheet(editClip: clip),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, VideoClip clip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('클립 삭제'),
        content: Text('"${clip.title}"을 큐레이션에서 제거할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(myroomNotifierProvider.notifier).deleteClip(clip.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎬', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            '아직 큐레이션한 영상이 없어요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'YouTube, TikTok, Reels, Shorts 등\n나만의 영상 큐레이션을 시작해보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('첫 영상 추가하기'),
          ),
        ],
      ),
    );
  }
}
