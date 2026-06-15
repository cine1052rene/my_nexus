import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/link_item.dart';
import '../providers/hub_provider.dart';
import '../widgets/link_card.dart';
import '../widgets/add_link_sheet.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/share_intent_service.dart';

class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> {
  @override
  void initState() {
    super.initState();
    // cold start: 앱이 꺼진 상태에서 공유로 실행
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final url = await ShareIntentService.getSharedText();
      if (url != null && mounted) _autoSaveFromShare(url);
    });
    // warm start: 앱 실행 중 공유 수신
    ShareIntentService.listenForSharedText((url) {
      if (mounted) _autoSaveFromShare(url);
    });
  }

  /// 공유 URL → 카테고리 자동 감지 → 즉시 저장 → SnackBar
  Future<void> _autoSaveFromShare(String url) async {
    final messenger = ScaffoldMessenger.of(context);

    // 로딩 스낵바
    messenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('저장 중...'),
      ]),
      duration: Duration(seconds: 30),
      behavior: SnackBarBehavior.floating,
    ));

    // 카테고리 + 메타데이터 감지
    final category = _detectCategory(url);
    String title = _defaultTitle(url, category);
    String? thumbnail;

    try {
      if (category == 'youtube') {
        final vid = _extractYoutubeId(url);
        if (vid != null) {
          title = 'YouTube 영상';
          thumbnail = 'https://img.youtube.com/vi/$vid/maxresdefault.jpg';
          // OG title 시도
          final res = await http.get(
            Uri.parse('https://www.youtube.com/watch?v=$vid'),
          ).timeout(const Duration(seconds: 5));
          final m = RegExp(r'"title":"([^"]+)"').firstMatch(res.body);
          if (m != null) title = m.group(1)!.replaceAll(r'&', '&');
        }
      } else if (category != 'tiktok') {
        final res = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        final titleM = RegExp(
          r'<title[^>]*>([^<]+)</title>', caseSensitive: false,
        ).firstMatch(res.body);
        final imgM = RegExp(
          r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(res.body);
        if (titleM != null) title = titleM.group(1)!.trim();
        if (imgM != null) thumbnail = imgM.group(1);
      }
    } catch (_) {}

    // 저장
    final saved = await ref.read(hubNotifierProvider.notifier).quickAddLink(
      url: url,
      title: title,
      category: category,
      thumbnailUrl: thumbnail,
    );

    if (!mounted) return;
    messenger.hideCurrentSnackBar();

    if (saved == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('저장 실패 😢'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // 성공 스낵바 + 편집 버튼
    messenger.showSnackBar(SnackBar(
      content: Text('${_categoryEmoji(category)} 저장됨: $title'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: '편집',
        onPressed: () => _openEditSheet(saved),
      ),
    ));
  }

  void _openEditSheet(LinkItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddLinkSheet(editItem: item),
    );
  }

  // ── 카테고리 자동 감지 ──────────────────────────────────────
  String _detectCategory(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) return 'youtube';
    if (url.contains('tiktok.com')) return 'tiktok';
    if (url.contains('instagram.com')) return 'instagram';
    if (url.contains('twitter.com') || url.contains('x.com')) return 'etc';
    if (url.contains('naver.com') || url.contains('blog.naver')) return 'etc';
    return 'etc';
  }

  String? _extractYoutubeId(String url) =>
      RegExp(r'(?:youtube\.com.*v=|youtu\.be/)([a-zA-Z0-9_-]{11})')
          .firstMatch(url)?.group(1);

  String _defaultTitle(String url, String category) {
    if (category == 'youtube') return 'YouTube 영상';
    if (category == 'tiktok') return 'TikTok 영상';
    if (category == 'instagram') return 'Instagram';
    try { return Uri.parse(url).host; } catch (_) { return url; }
  }

  String _categoryEmoji(String category) {
    const map = {
      'youtube': '▶️', 'tiktok': '🎵', 'instagram': '📸',
      'article': '📄', 'book': '📚', 'etc': '🔗',
    };
    return map[category] ?? '🔗';
  }

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(hubCategoryProvider);
    final search = ref.watch(hubSearchProvider);
    final links = ref.watch(filteredLinksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 DB 허브'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '제목, 요약, 태그 검색...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              ref.read(hubSearchProvider.notifier).state = '',
                        )
                      : null,
                ),
                onChanged: (v) =>
                    ref.read(hubSearchProvider.notifier).state = v,
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: HubCategory.all_list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final cat = HubCategory.all_list[i];
                  final selected = category == cat.id;
                  return FilterChip(
                    label: Text('${cat.emoji} ${cat.label}'),
                    selected: selected,
                    onSelected: (_) =>
                        ref.read(hubCategoryProvider.notifier).state = cat.id,
                  );
                },
              ),
            ),
          ]),
        ),
      ),
      body: links.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔗', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text('아직 저장된 링크가 없어요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('유튜브/카카오톡에서 공유 → MyNexus!',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return LinkCard(
                item: item,
                onEdit: () => _openEditSheet(item),
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('삭제'),
                      content: const Text('이 링크를 삭제할까요?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('삭제',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref
                        .read(hubNotifierProvider.notifier)
                        .deleteLink(item.id);
                  }
                },
              );
            },
          );
        },
      ),
      // + 버튼은 수동 추가 시에만 AddLinkSheet 오픈
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddLinkSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('링크 추가'),
      ),
    );
  }
}
