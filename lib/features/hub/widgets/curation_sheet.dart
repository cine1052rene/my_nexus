import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/link_item.dart';
import '../../settings/providers/settings_provider.dart';
import '../../myroom/providers/myroom_provider.dart';

class CurationSheet extends ConsumerStatefulWidget {
  final LinkItem item;
  const CurationSheet({super.key, required this.item});

  @override
  ConsumerState<CurationSheet> createState() => _CurationSheetState();
}

class _CurationSheetState extends ConsumerState<CurationSheet> {
  bool   _loading = true;
  String? _error;
  final _titleCtrl   = TextEditingController();
  final _summaryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.item.title;
    WidgetsBinding.instance.addPostFrameCallback((_) => _curate());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  // ── AI 큐레이션 ────────────────────────────────────────────────
  Future<void> _curate() async {
    final apiKey = ref.read(geminiApiKeyProvider).valueOrNull ?? '';
    if (apiKey.isEmpty) {
      setState(() {
        _error  = 'Gemini API 키가 설정되지 않았어요.\n설정 탭에서 먼저 키를 입력해주세요.';
        _loading = false;
      });
      return;
    }

    try {
      final description = await _fetchDescription();
      final model       = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final prompt      = _buildPrompt(description);
      final response    = await model.generateContent([Content.text(prompt)]);
      final summary     = response.text?.trim() ?? '요약을 생성하지 못했어요.';

      if (!mounted) return;
      setState(() {
        _summaryCtrl.text = summary;
        _loading          = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '오류가 발생했어요:\n$e'; _loading = false; });
    }
  }

  /// URL에서 설명 텍스트 추출 (YouTube description / OG:description / meta description)
  Future<String> _fetchDescription() async {
    try {
      final url = widget.item.url;
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        final vid = RegExp(r'(?:youtube\.com.*v=|youtu\.be/)([a-zA-Z0-9_-]{11})')
            .firstMatch(url)?.group(1);
        if (vid != null) {
          final res  = await http.get(Uri.parse('https://www.youtube.com/watch?v=$vid'))
              .timeout(const Duration(seconds: 8));
          final body = utf8.decode(res.bodyBytes, allowMalformed: true);
          // shortDescription JSON 파싱
          final m = RegExp(r'"shortDescription":"((?:[^"\\]|\\.)*)\"')
              .firstMatch(body);
          if (m != null) {
            return m.group(1)!
                .replaceAll(r'\n', '\n')
                .replaceAll(r'\"', '"')
                .replaceAll(r'\\', '\\')
                .substring(0, m.group(1)!.length.clamp(0, 1500));
          }
        }
      } else {
        final res  = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        // og:description 우선
        final og = RegExp(
            r"""<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)""",
            caseSensitive: false).firstMatch(body);
        if (og != null) return og.group(1)!;
        // fallback: name="description"
        final desc = RegExp(
            r"""<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)""",
            caseSensitive: false).firstMatch(body);
        if (desc != null) return desc.group(1)!;
      }
    } catch (_) {}
    return '';
  }

  String _buildPrompt(String description) => '''
아래 콘텐츠를 지식·학습 목적으로 한국어로 요약해주세요.

제목: ${widget.item.title}
URL: ${widget.item.url}
${description.isNotEmpty ? '설명:\n$description' : ''}

다음 형식으로 작성해주세요 (마크다운):

## 📌 핵심 요약
• 핵심 내용 1
• 핵심 내용 2
• 핵심 내용 3
(3~5개, 각 1~2문장)

## 💡 주요 키워드
#키워드1 #키워드2 #키워드3

## 🔗 원본
${widget.item.url}
''';

  // ── 마이룸 저장 ────────────────────────────────────────────────
  Future<void> _save() async {
    final title = _titleCtrl.text.trim().isEmpty
        ? widget.item.title
        : _titleCtrl.text.trim();

    // 키워드 태그 추출 (#태그 파싱)
    final tags = RegExp(r'#(\S+)')
        .allMatches(_summaryCtrl.text)
        .map((m) => m.group(1)!)
        .toList();

    final err = await ref.read(myroomNotifierProvider.notifier).addClip(
      url:          widget.item.url,
      title:        title,
      note:         _summaryCtrl.text.trim(),
      thumbnailUrl: widget.item.thumbnailUrl,
      tags:         tags,
    );

    if (!mounted) return;

    // pop 전에 messenger 캡처 (pop 후 context 무효화 방지)
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(err == null
        ? const SnackBar(
            content: Text('📚 마이룸에 저장됐어요!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          )
        : SnackBar(
            content: Text('저장 실패: $err'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ));
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize:     0.5,
      maxChildSize:     0.98,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // 핸들
          Container(
            margin:     const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              const Text('🎓 큐레이션',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (!_loading && _error == null)
                TextButton(
                  onPressed: _save,
                  child: const Text('마이룸 저장',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          const Divider(),

          // 바디
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('AI가 요약 중이에요...',
                            style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 6),
                        Text(widget.item.title,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[400]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('😢',
                                  style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        controller: ctrl,
                        padding:
                            const EdgeInsets.fromLTRB(20, 12, 20, 40),
                        children: [
                          // 제목
                          TextField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: '📌 제목',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // AI 요약 (편집 가능)
                          TextField(
                            controller: _summaryCtrl,
                            maxLines: null,
                            style: const TextStyle(fontSize: 14, height: 1.6),
                            decoration: const InputDecoration(
                              labelText: '📋 AI 요약 (편집 가능)',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 저장 버튼
                          ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.bookmark_add),
                            label: const Text('마이룸에 저장'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ),
          ),
        ]),
      ),
    );
  }
}
