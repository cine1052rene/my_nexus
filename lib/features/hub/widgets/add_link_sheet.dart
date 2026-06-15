import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/link_item.dart';
import '../providers/hub_provider.dart';
import '../../../core/constants/app_constants.dart';

class AddLinkSheet extends ConsumerStatefulWidget {
  final LinkItem? editItem;
  final String? initialUrl;
  const AddLinkSheet({super.key, this.editItem, this.initialUrl});

  @override
  ConsumerState<AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends ConsumerState<AddLinkSheet> {
  final _urlCtrl     = TextEditingController();
  final _titleCtrl   = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();
  final _tagsCtrl    = TextEditingController();

  String  _category     = 'etc';
  String? _ytKeywordId;      // 선택된 YouTube 키워드 ID
  bool    _loading      = false;
  String? _fetchedThumb;

  @override
  void initState() {
    super.initState();
    if (widget.editItem != null) {
      final e = widget.editItem!;
      _urlCtrl.text     = e.url;
      _titleCtrl.text   = e.title;
      _summaryCtrl.text = e.summary ?? '';
      _notesCtrl.text   = e.notes ?? '';
      _tagsCtrl.text    = e.tags.join(', ');
      _category         = e.category;
      _fetchedThumb     = e.thumbnailUrl;
      // 기존 태그에서 YouTube 키워드 복원
      if (_category == 'youtube') {
        for (final kw in YoutubeKeyword.all_list) {
          if (e.tags.contains(kw.label)) { _ytKeywordId = kw.id; break; }
        }
      }
    } else if (widget.initialUrl != null) {
      _urlCtrl.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMetadata());
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose(); _titleCtrl.dispose();
    _summaryCtrl.dispose(); _notesCtrl.dispose(); _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMetadata() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _loading = true);

    try {
      // YouTube
      final ytMatch = RegExp(
          r'(?:youtube\.com.*v=|youtu\.be/)([a-zA-Z0-9_-]{11})')
          .firstMatch(url);
      if (ytMatch != null) {
        final vid = ytMatch.group(1)!;
        _fetchedThumb = 'https://img.youtube.com/vi/$vid/maxresdefault.jpg';
        // 실제 제목 가져오기
        try {
          final res = await http.get(
            Uri.parse('https://www.youtube.com/watch?v=$vid'),
          ).timeout(const Duration(seconds: 5));
          final m = RegExp(r'"title":"([^"]+)"').firstMatch(res.body);
          if (m != null) {
            final ytTitle = m.group(1)!
                .replaceAll(r'&amp;', '&')
                .replaceAll(r'&', '&');
            if (_titleCtrl.text.isEmpty) _titleCtrl.text = ytTitle;
            // 키워드 자동 감지
            _applyYoutubeKeyword(ytTitle);
          }
        } catch (_) {}
        if (_titleCtrl.text.isEmpty) _titleCtrl.text = 'YouTube 영상 ($vid)';
        setState(() { _category = 'youtube'; _loading = false; });
        return;
      }

      // TikTok
      if (url.contains('tiktok.com')) {
        if (_titleCtrl.text.isEmpty) _titleCtrl.text = 'TikTok 영상';
        setState(() { _category = 'tiktok'; _loading = false; });
        return;
      }

      // OG 태그 파싱
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      final body = res.body;
      final titleM = RegExp(r'<title[^>]*>([^<]+)</title>',
          caseSensitive: false).firstMatch(body);
      final imgM   = RegExp(
          r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"',
          caseSensitive: false).firstMatch(body);
      if (titleM != null && _titleCtrl.text.isEmpty) {
        _titleCtrl.text = titleM.group(1)?.trim() ?? '';
      }
      if (imgM != null) _fetchedThumb = imgM.group(1);
    } catch (_) {}

    setState(() => _loading = false);
  }

  /// 제목에서 YouTube 키워드 자동 감지 후 적용
  void _applyYoutubeKeyword(String title) {
    final kw = YoutubeKeyword.detectFromTitle(title);
    if (kw != null) {
      _ytKeywordId = kw.id;
      _syncYtKeywordToTags(kw.id);
    }
  }

  /// 선택한 YouTube 키워드를 태그에 반영 (기존 yt 키워드 태그 교체)
  void _syncYtKeywordToTags(String? kwId) {
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    // 기존 YouTube 키워드 태그 제거
    for (final k in YoutubeKeyword.all_list) tags.remove(k.label);
    // 새 키워드 추가
    if (kwId != null) {
      final kw = YoutubeKeyword.all_list
          .cast<YoutubeKeyword?>()
          .firstWhere((k) => k?.id == kwId, orElse: () => null);
      if (kw != null) tags.insert(0, kw.label);
    }
    _tagsCtrl.text = tags.join(', ');
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _urlCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL과 제목을 입력해주세요')));
      return;
    }
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final notifier = ref.read(hubNotifierProvider.notifier);
    String? err;

    if (widget.editItem != null) {
      err = await notifier.updateLink(widget.editItem!.copyWith(
        title: _titleCtrl.text, category: _category,
        thumbnailUrl: _fetchedThumb,
        summary: _summaryCtrl.text.isEmpty ? null : _summaryCtrl.text,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        tags: tags,
      ));
    } else {
      err = await notifier.addLink(
        url: _urlCtrl.text.trim(), title: _titleCtrl.text.trim(),
        category: _category, thumbnailUrl: _fetchedThumb,
        summary: _summaryCtrl.text.isEmpty ? null : _summaryCtrl.text,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        tags: tags,
      );
    }

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $err')));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.98,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Text(widget.editItem == null ? '🔗 링크 추가' : '✏️ 링크 수정',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(onPressed: _save,
                  child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // URL
                Row(children: [
                  Expanded(child: TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(
                          labelText: '🔗 URL', hintText: 'https://...'),
                      keyboardType: TextInputType.url)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _fetchMetadata,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: _loading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('가져오기'),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: '📌 제목 *')),
                const SizedBox(height: 12),

                // 카테고리
                const Text('카테고리',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: HubCategory.all_list.skip(1).map((cat) => ChoiceChip(
                    label: Text('${cat.emoji} ${cat.label}'),
                    selected: _category == cat.id,
                    onSelected: (_) => setState(() {
                      _category = cat.id;
                      if (cat.id != 'youtube') {
                        _ytKeywordId = null;
                      }
                    }),
                  )).toList(),
                ),
                const SizedBox(height: 12),

                // YouTube 키워드 (유튜브 카테고리 선택 시만 표시)
                if (_category == 'youtube') ...[
                  const Text('YouTube 키워드 (선택)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: YoutubeKeyword.all_list.map((kw) {
                      final sel = _ytKeywordId == kw.id;
                      return ChoiceChip(
                        label: Text('${kw.emoji} ${kw.label}'),
                        selected: sel,
                        onSelected: (v) => setState(() {
                          _ytKeywordId = v ? kw.id : null;
                          _syncYtKeywordToTags(_ytKeywordId);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(controller: _summaryCtrl, maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: '📋 요약 메모', hintText: '영상/링크 내용 요약...')),
                const SizedBox(height: 12),
                TextField(controller: _notesCtrl, maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: '💬 주석', hintText: '개인 메모, 아이디어...')),
                const SizedBox(height: 12),
                TextField(controller: _tagsCtrl,
                    decoration: const InputDecoration(
                        labelText: '🏷️ 태그 (쉼표로 구분)',
                        hintText: '뜨개질, 초보, 겨울...')),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
