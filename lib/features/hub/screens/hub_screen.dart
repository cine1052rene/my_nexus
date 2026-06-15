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
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final url = await ShareIntentService.getSharedText();
      if (url != null && mounted) _autoSaveFromShare(url);
    });
    ShareIntentService.listenForSharedText((url) {
      if (mounted) _autoSaveFromShare(url);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchActive = true);
  }

  void _closeSearch() {
    setState(() => _searchActive = false);
    _searchCtrl.clear();
    ref.read(hubSearchProvider.notifier).state = '';
  }

  /// 공유 URL → 카테고리·키워드 자동 감지 → 즉시 저장 → SnackBar
  Future<void> _autoSaveFromShare(String url) async {
    final messenger = ScaffoldMessenger.of(context);
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

    final category = _detectCategory(url);
    String title = _defaultTitle(url, category);
    String? thumbnail;
    final tags = <String>[];

    try {
      if (category == 'youtube') {
        final vid = _extractYoutubeId(url);
        if (vid != null) {
          thumbnail = 'https://img.youtube.com/vi/$vid/maxresdefault.jpg';
          final res = await http.get(Uri.parse('https://www.youtube.com/watch?v=$vid'))
              .timeout(const Duration(seconds: 5));
          final m = RegExp(r'"title":"([^"]+)"').firstMatch(res.body);
          if (m != null) title = m.group(1)!.replaceAll(r'&amp;', '&');
          final kw = YoutubeKeyword.detectFromTitle(title);
          if (kw != null) tags.add(kw.label);
        }
      } else if (category != 'tiktok') {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        final titleM = RegExp(r'<title[^>]*>([^<]+)</title>',
            caseSensitive: false).firstMatch(res.body);
        final imgM = RegExp(
            r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"',
            caseSensitive: false).firstMatch(res.body);
        if (titleM != null) title = titleM.group(1)!.trim();
        if (imgM != null) thumbnail = imgM.group(1);
      }
    } catch (_) {}

    final saved = await ref.read(hubNotifierProvider.notifier).quickAddLink(
      url: url, title: title, category: category,
      thumbnailUrl: thumbnail, tags: tags,
    );

    if (!mounted) return;
    messenger.hideCurrentSnackBar();

    if (saved == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('저장 실패 😢'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text('${_categoryEmoji(category)} 저장됨: $title'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: '편집', onPressed: () => _openEditSheet(saved)),
    ));
  }

  void _openEditSheet(LinkItem item) => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddLinkSheet(editItem: item),
  );

  void _confirmDelete(LinkItem item) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 링크를 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        ref.read(hubNotifierProvider.notifier).deleteLink(item.id);
      }
    });
  }

  // ── 카테고리 자동 감지 ──────────────────────────────────────────
  String _detectCategory(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) return 'youtube';
    if (url.contains('tiktok.com'))   return 'tiktok';
    if (url.contains('instagram.com')) return 'instagram';
    return 'etc';
  }

  String? _extractYoutubeId(String url) =>
      RegExp(r'(?:youtube\.com.*v=|youtu\.be/)([a-zA-Z0-9_-]{11})')
          .firstMatch(url)?.group(1);

  String _defaultTitle(String url, String category) {
    if (category == 'youtube') return 'YouTube 영상';
    if (category == 'tiktok')  return 'TikTok 영상';
    try { return Uri.parse(url).host; } catch (_) { return url; }
  }

  String _categoryEmoji(String category) => const {
    'youtube': '▶️', 'tiktok': '🎵', 'instagram': '📸', 'etc': '🔗',
  }[category] ?? '🔗';

  IconData _viewModeIcon(HubViewMode m) => switch (m) {
    HubViewMode.grid    => Icons.grid_view,
    HubViewMode.compact => Icons.format_list_bulleted,
    _                   => Icons.view_agenda_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(hubCategoryProvider);
    final links    = ref.watch(filteredLinksProvider);
    final viewMode = ref.watch(hubViewModeProvider);

    return Scaffold(
      appBar: AppBar(
        // 검색 활성화 시 title → TextField
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '제목, 요약, 태그 검색...',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    ref.read(hubSearchProvider.notifier).state = v,
              )
            : const Text('📚 DB 허브'),
        actions: _searchActive
            // 검색 중: X 버튼만
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _closeSearch,
                ),
              ]
            // 기본: 돋보기 + 뷰모드
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: '검색',
                  onPressed: _openSearch,
                ),
                PopupMenuButton<HubViewMode>(
                  icon: Icon(_viewModeIcon(viewMode)),
                  tooltip: '보기 방식',
                  onSelected: (m) =>
                      ref.read(hubViewModeProvider.notifier).state = m,
                  itemBuilder: (_) => [
                    _viewMenuItem(HubViewMode.list,    Icons.view_agenda_outlined, '카드 보기'),
                    _viewMenuItem(HubViewMode.grid,    Icons.grid_view,            '그리드 보기'),
                    _viewMenuItem(HubViewMode.compact, Icons.format_list_bulleted, '간략 보기'),
                  ],
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: _CategoryIconBar(
            selected: category,
            onSelect: (id) =>
                ref.read(hubCategoryProvider.notifier).state = id,
          ),
        ),
      ),
      body: links.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          if (items.isEmpty) return _emptyView();
          return viewMode == HubViewMode.grid
              ? _GridBody(items: items, onEdit: _openEditSheet, onDelete: _confirmDelete)
              : _ListBody(items: items, viewMode: viewMode,
                          onEdit: _openEditSheet, onDelete: _confirmDelete);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddLinkSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('링크 추가'),
      ),
    );
  }

  Widget _emptyView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔗', style: TextStyle(fontSize: 60)),
      const SizedBox(height: 16),
      const Text('아직 저장된 링크가 없어요',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('유튜브/카카오톡에서 공유 → MyNexus!',
          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
    ]),
  );

  PopupMenuItem<HubViewMode> _viewMenuItem(
      HubViewMode mode, IconData icon, String label) =>
      PopupMenuItem(
        value: mode,
        child: Row(children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ]),
      );
}

// ── 바디 위젯 (Scaffold body 분리) ─────────────────────────────
class _ListBody extends StatelessWidget {
  final List<LinkItem> items;
  final HubViewMode viewMode;
  final void Function(LinkItem) onEdit;
  final void Function(LinkItem) onDelete;
  const _ListBody({required this.items, required this.viewMode,
      required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    itemCount: items.length,
    itemBuilder: (_, i) => LinkCard(
      item: items[i], viewMode: viewMode,
      onEdit: () => onEdit(items[i]),
      onDelete: () => onDelete(items[i]),
    ),
  );
}

class _GridBody extends StatelessWidget {
  final List<LinkItem> items;
  final void Function(LinkItem) onEdit;
  final void Function(LinkItem) onDelete;
  const _GridBody({required this.items, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.82,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => LinkCard(
      item: items[i], viewMode: HubViewMode.grid,
      onEdit: () => onEdit(items[i]),
      onDelete: () => onDelete(items[i]),
    ),
  );
}

// ── 카테고리 아이콘 바 ─────────────────────────────────────────────
class _CategoryIconBar extends StatelessWidget {
  final String selected;
  final void Function(String id) onSelect;

  const _CategoryIconBar({required this.selected, required this.onSelect});

  static const _icons = <String, IconData>{
    'all':      Icons.apps,
    'youtube':  Icons.play_circle_filled,
    'tiktok':   Icons.music_note,
    'knitting': Icons.hub_outlined,
    'cooking':  Icons.restaurant,
    'recipe':   Icons.menu_book,
    'etc':      Icons.link,
  };

  static const _colors = <String, Color>{
    'all':      Color(0xFF6C63FF),
    'youtube':  Color(0xFFFF0000),
    'tiktok':   Color(0xFF000000),
    'knitting': Color(0xFF9C27B0),
    'cooking':  Color(0xFFFF9800),
    'recipe':   Color(0xFF4CAF50),
    'etc':      Color(0xFF607D8B),
  };

  @override
  Widget build(BuildContext context) {
    final cats = HubCategory.all_list;
    return SizedBox(
      height: 36,
      child: Row(
        children: cats.map((cat) {
          final isSelected = selected == cat.id;
          final color = _colors[cat.id] ?? const Color(0xFF6C63FF);
          final icon  = _icons[cat.id]  ?? Icons.label_outline;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(cat.id),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? color : Colors.grey[400],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
