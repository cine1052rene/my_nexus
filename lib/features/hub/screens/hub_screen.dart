import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/link_item.dart';
import '../providers/hub_provider.dart';
import '../widgets/link_card.dart';
import '../widgets/add_link_sheet.dart';
import '../widgets/curation_sheet.dart';
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

  // 중복 저장 방지: 앱 전역 static — HubScreen 재생성 시에도 유지됨
  static String? _lastSavedUrl;
  static DateTime? _lastSavedAt;

  @override
  void initState() {
    super.initState();
    // Cold start (앱이 종료됐다가 공유로 실행) — getSharedText 경로
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final url = await ShareIntentService.getSharedText();
      if (url != null && mounted) _autoSaveFromShare(url);
    });
    // Warm start (앱이 백그라운드에 있다가 공유로 복귀) — listener 경로
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

  /// 공유 URL → 즉시 저장 → SnackBar → 백그라운드 메타데이터 업데이트
  Future<void> _autoSaveFromShare(String url) async {
    // ── 1차 방어: 동일 URL이 30초 내 재진입하면 무시 ──────────────
    // Samsung OneUI 등 onNewIntent 지연 중복 호출 케이스까지 커버
    final now = DateTime.now();
    if (url == _lastSavedUrl &&
        _lastSavedAt != null &&
        now.difference(_lastSavedAt!).inSeconds < 30) {
      return;
    }
    _lastSavedUrl = url;
    _lastSavedAt = now;
    final messenger = ScaffoldMessenger.of(context);
    final category  = _detectCategory(url);
    String  title     = _defaultTitle(url, category);
    String? thumbnail;

    // YouTube 썸네일은 HTTP 없이 URL에서 즉시 추출
    if (category == 'youtube') {
      final vid = _extractYoutubeId(url);
      if (vid != null) {
        thumbnail = 'https://img.youtube.com/vi/$vid/maxresdefault.jpg';
      }
    }

    // ① 즉시 Firestore 저장 (기본 제목으로)
    final saved = await ref.read(hubNotifierProvider.notifier).quickAddLink(
      url: url, title: title, category: category, thumbnailUrl: thumbnail,
    );

    if (!mounted) return;

    if (saved == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('저장 실패 😢'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // ② 저장 완료 즉시 알림
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('${_categoryEmoji(category)} 저장됨: $title'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      action: SnackBarAction(label: '편집', onPressed: () => _openEditSheet(saved)),
    ));

    // ③ 백그라운드에서 메타데이터 가져와 조용히 업데이트
    _updateMetadataInBackground(saved, url, category);
  }

  /// 백그라운드 메타데이터 업데이트 (저장 후 호출, 실패해도 무시)
  Future<void> _updateMetadataInBackground(
      LinkItem saved, String url, String category) async {
    try {
      String? newTitle;
      String? newThumb = saved.thumbnailUrl;
      final newTags = List<String>.from(saved.tags);

      if (category == 'youtube') {
        final vid = _extractYoutubeId(url);
        if (vid != null) {
          final res = await http.get(Uri.parse('https://www.youtube.com/watch?v=$vid'))
              .timeout(const Duration(seconds: 5));
          final body = utf8.decode(res.bodyBytes, allowMalformed: true);
          final m = RegExp(r'"title":"([^"]+)"').firstMatch(body);
          if (m != null) {
            newTitle = m.group(1)!.replaceAll(r'&amp;', '&');
            final kw = YoutubeKeyword.detectFromTitle(newTitle);
            if (kw != null && !newTags.contains(kw.label)) newTags.add(kw.label);
          }
        }
      } else if (category == 'instagram' ||
                 category == 'threads' ||
                 category == 'twitter' ||
                 category == 'tiktok') {
        // Microlink API — 클라이언트 IP 기준 50req/일 무료
        // 각 유저 기기 IP가 독립적으로 적용되므로 다수 유저에게도 안전
        final encoded = Uri.encodeQueryComponent(url);
        final res = await http
            .get(Uri.parse('https://api.microlink.io?url=$encoded'))
            .timeout(const Duration(seconds: 8));
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['status'] == 'success') {
          final d = json['data'] as Map<String, dynamic>;
          final t = d['title'] as String?;
          final img = d['image'] as Map<String, dynamic>?;
          // 제목: 제네릭/로그인 유도 제목 제외
          const _genericTitles = [
            'Instagram', 'Threads • Log in', 'Log in • Instagram',
            'TikTok', 'Log in | TikTok',
          ];
          if (t != null && t.isNotEmpty && !_genericTitles.contains(t)) {
            newTitle = t;
          }
          // 이미지: data: URL(base64 로고) 제외, 실제 CDN URL만 사용
          final imgUrl = img?['url'] as String?;
          if (imgUrl != null && !imgUrl.startsWith('data:')) {
            newThumb = imgUrl;
          }
        }
      } else {
        // 일반 사이트: OG 메타태그 직접 fetch
        final res = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        final titleM = RegExp(r'<title[^>]*>([^<]+)</title>',
            caseSensitive: false).firstMatch(body);
        final imgM = RegExp(
            r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"',
            caseSensitive: false).firstMatch(body);
        if (titleM != null) newTitle = titleM.group(1)!.trim();
        if (imgM != null) newThumb = imgM.group(1);
      }

      // 변경된 경우만 업데이트
      final changed = (newTitle != null && newTitle != saved.title) ||
          newThumb != saved.thumbnailUrl ||
          newTags.length != saved.tags.length;
      if (!changed) return;

      await ref.read(hubNotifierProvider.notifier).updateLink(saved.copyWith(
        title:        newTitle ?? saved.title,
        thumbnailUrl: newThumb,
        tags:         newTags,
      ));
    } catch (_) {
      // 메타데이터 업데이트 실패 → 기본 제목으로 이미 저장됐으니 무시
    }
  }

  void _openEditSheet(LinkItem item) => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddLinkSheet(editItem: item),
  );

  void _openCurationSheet(LinkItem item) => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CurationSheet(
      item: item,
      // 부모 context(HubScreen)에서 스낵바 표시 → context 항상 유효
      onSaved: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('📚 마이룸에 저장됐어요!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ));
      },
    ),
  );

  Future<void> _confirmDelete(LinkItem item) async {
    final ok = await showDialog<bool>(
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
    );
    if (ok == true && mounted) {
      ref.read(hubNotifierProvider.notifier).deleteLink(item.id);
    }
  }

  // ── 카테고리 자동 감지 (출처별) ───────────────────────────────────
  String _detectCategory(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be'))        return 'youtube';
    if (url.contains('instagram.com'))                                   return 'instagram';
    if (url.contains('threads.net') || url.contains('threads.com'))     return 'threads';
    if (url.contains('tiktok.com'))                                      return 'tiktok';
    if (url.contains('facebook.com') || url.contains('fb.com') ||
        url.contains('fb.watch'))                                        return 'facebook';
    if (url.contains('twitter.com') || url.contains('x.com') ||
        url.contains('t.co'))                                            return 'twitter';
    if (url.contains('naver.com') || url.contains('naver.me'))          return 'naver';
    return 'etc';
  }

  String? _extractYoutubeId(String url) =>
      RegExp(r'(?:youtube\.com.*v=|youtu\.be/)([a-zA-Z0-9_-]{11})')
          .firstMatch(url)?.group(1);

  String _defaultTitle(String url, String category) {
    switch (category) {
      case 'youtube':   return 'YouTube 영상';
      case 'instagram': return 'Instagram';
      case 'threads':   return 'Threads';
      case 'tiktok':    return 'TikTok';
      case 'facebook':  return 'Facebook';
      case 'twitter':   return 'Twitter/X';
      case 'naver':     return '네이버';
      default:
        try { return Uri.parse(url).host; } catch (_) { return url; }
    }
  }

  String _categoryEmoji(String category) => const {
    'youtube':   '▶️',
    'instagram': '📸',
    'threads':   '🧵',
    'tiktok':    '🎵',
    'facebook':  '👥',
    'twitter':   '🐦',
    'naver':     '🟢',
    'etc':       '🔗',
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
      body: Listener(
        // 화면 어디 터치해도 스낵바 즉시 닫힘
        // (PopupMenu의 모달 배리어가 위에 있으므로 팝업 열려 있을 때는 발동 안 함)
        onPointerDown: (_) =>
            ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        behavior: HitTestBehavior.translucent,
        child: NotificationListener<ScrollStartNotification>(
          // 스크롤 시작 → 스낵바 닫힘
          onNotification: (_) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            return false;
          },
          child: links.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (items) {
              if (items.isEmpty) return _emptyView();
              return viewMode == HubViewMode.grid
                  ? _GridBody(items: items, onEdit: _openEditSheet, onDelete: _confirmDelete, onCurate: _openCurationSheet)
                  : _ListBody(items: items, viewMode: viewMode,
                              onEdit: _openEditSheet, onDelete: _confirmDelete, onCurate: _openCurationSheet);
            },
          ),
        ),
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
  final void Function(LinkItem) onCurate;
  const _ListBody({required this.items, required this.viewMode,
      required this.onEdit, required this.onDelete, required this.onCurate});

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    itemCount: items.length,
    itemBuilder: (_, i) => LinkCard(
      item: items[i], viewMode: viewMode,
      onEdit:   () => onEdit(items[i]),
      onDelete: () => onDelete(items[i]),
      onCurate: () => onCurate(items[i]),
    ),
  );
}

class _GridBody extends StatelessWidget {
  final List<LinkItem> items;
  final void Function(LinkItem) onEdit;
  final void Function(LinkItem) onDelete;
  final void Function(LinkItem) onCurate;
  const _GridBody({required this.items, required this.onEdit,
      required this.onDelete, required this.onCurate});

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
      onEdit:   () => onEdit(items[i]),
      onDelete: () => onDelete(items[i]),
      onCurate: () => onCurate(items[i]),
    ),
  );
}

// ── 카테고리 아이콘 바 (출처별) ───────────────────────────────────
class _CategoryIconBar extends StatelessWidget {
  final String selected;
  final void Function(String id) onSelect;

  const _CategoryIconBar({required this.selected, required this.onSelect});

  // 출처별 브랜드 컬러
  static const _colors = <String, Color>{
    'all':       Color(0xFF6C63FF),
    'youtube':   Color(0xFFFF0000),
    'instagram': Color(0xFFE1306C),
    'threads':   Color(0xFF101010),
    'tiktok':    Color(0xFFEE1D52),
    'facebook':  Color(0xFF1877F2),
    'twitter':   Color(0xFF000000),
    'naver':     Color(0xFF03C75A),
    'etc':       Color(0xFF607D8B),
  };

  // Material 아이콘 (브랜드 아이콘 없는 경우 대체)
  static const _icons = <String, IconData>{
    'all':       Icons.apps,
    'youtube':   Icons.play_circle_filled,
    'instagram': Icons.camera_alt,
    'tiktok':    Icons.music_note,
    'etc':       Icons.link,
  };

  // 브랜드 텍스트 아이콘 (Material 아이콘 없는 경우)
  static const _labels = <String, String>{
    'threads':  '@',
    'facebook': 'f',
    'twitter':  'X',
    'naver':    'N',
  };

  Widget _iconWidget(String id, bool isSelected) {
    final color = isSelected
        ? (_colors[id] ?? const Color(0xFF6C63FF))
        : const Color(0xFFBDBDBD);

    // 브랜드 텍스트 아이콘
    if (_labels.containsKey(id)) {
      return Text(
        _labels[id]!,
        style: TextStyle(
          fontSize: id == 'twitter' ? 16 : 18,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1.1,
        ),
      );
    }

    // Material 아이콘
    return Icon(_icons[id] ?? Icons.label_outline, size: 20, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final cats = HubCategory.all_list;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: cats.map((cat) {
          final isSelected = selected == cat.id;
          final color = _colors[cat.id] ?? const Color(0xFF6C63FF);
          return GestureDetector(
            onTap: () => onSelect(cat.id),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _iconWidget(cat.id, isSelected),
            ),
          );
        }).toList(),
      ),
    );
  }
}
