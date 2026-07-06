import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_clip.dart';
import '../providers/myroom_provider.dart';
import '../widgets/clip_card.dart';
import '../widgets/add_clip_sheet.dart';
import '../widgets/tag_manager_sheet.dart';

class MyroomScreen extends ConsumerStatefulWidget {
  const MyroomScreen({super.key});

  @override
  ConsumerState<MyroomScreen> createState() => _MyroomScreenState();
}

class _MyroomScreenState extends ConsumerState<MyroomScreen> {
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _activateSearch() {
    setState(() => _searchActive = true);
    Future.microtask(() => _focusNode.requestFocus());
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(myroomSearchProvider.notifier).state = '';
    setState(() => _searchActive = false);
    _focusNode.unfocus();
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddClipSheet(),
    );
  }

  void _showEditSheet(VideoClip clip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClipSheet(editClip: clip),
    );
  }

  Future<void> _confirmDelete(VideoClip clip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('클립 삭제'),
        content: Text('"${clip.title}"을 큐레이션에서 제거할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(myroomNotifierProvider.notifier).deleteClip(clip.id);
    }
  }

  void _openTagManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TagManagerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clipsAsync = ref.watch(filteredClipsProvider);
    final tagsAsync = ref.watch(myroomTagsProvider);
    final selectedTag = ref.watch(myroomSelectedTagProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '제목, 메모, 태그 검색...',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (v) =>
                    ref.read(myroomSearchProvider.notifier).state = v,
              )
            : const Text('🎬 마이룸'),
        actions: [
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSearch,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _activateSearch,
            ),
            IconButton(
              icon: const Icon(Icons.label_outline),
              tooltip: '태그 관리',
              onPressed: _openTagManager,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 태그 필터 칩
          tagsAsync.when(
            loading: () => const SizedBox(height: 44),
            error: (_, __) => const SizedBox(height: 44),
            data: (tags) => SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // 전체
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('📋 전체'),
                      selected: selectedTag == null,
                      onSelected: (_) => ref
                          .read(myroomSelectedTagProvider.notifier)
                          .state = null,
                    ),
                  ),
                  // 커스텀 태그들
                  ...tags.map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text('${tag.emoji} ${tag.label}'),
                          selected: selectedTag == tag.label,
                          onSelected: (_) => ref
                              .read(myroomSelectedTagProvider.notifier)
                              .state = selectedTag == tag.label
                                  ? null
                                  : tag.label,
                        ),
                      )),
                ],
              ),
            ),
          ),
          // 클립 그리드
          Expanded(
            child: clipsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (clips) {
                if (clips.isEmpty) {
                  return _EmptyState(onAdd: _showAddSheet);
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: clips.length,
                  itemBuilder: (ctx, i) {
                    final clip = clips[i];
                    return ClipCard(
                      clip: clip,
                      onEdit: () => _showEditSheet(clip),
                      onDelete: () => _confirmDelete(clip),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('영상 추가'),
      ),
    );
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
            style:
                TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
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
