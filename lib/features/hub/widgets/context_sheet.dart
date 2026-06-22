import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/link_item.dart';
import '../../settings/providers/settings_provider.dart';
import '../../myroom/providers/myroom_provider.dart';

/// DB 허브 → 상세 학습용 컨텍스트 정리 시트
/// 큐레이션보다 훨씬 상세한 내용 정리 + 마이룸 저장
class ContextSheet extends ConsumerStatefulWidget {
  final LinkItem item;
  final VoidCallback? onSaved;
  const ContextSheet({super.key, required this.item, this.onSaved});

  @override
  ConsumerState<ContextSheet> createState() => _ContextSheetState();
}

class _ContextSheetState extends ConsumerState<ContextSheet> {
  bool _loading = true;
  String? _error;
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.item.title;
    WidgetsBinding.instance.addPostFrameCallback((_) => _organize());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── AI 내용 정리 ───────────────────────────────────────────────
  Future<void> _organize() async {
    final apiKey = ref.read(geminiApiKeyProvider).valueOrNull ?? '';
    if (apiKey.isEmpty) {
      setState(() {
        _error  = 'Gemini API 키가 설정되지 않았어요.\n설정 탭에서 먼저 키를 입력해주세요.';
        _loading = false;
      });
      return;
    }

    try {
      final rawContent = await _fetchContent();
      final model      = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final response   = await model.generateContent([Content.text(_buildPrompt(rawContent))]);
      final content    = response.text?.trim() ?? '내용을 정리하지 못했어요.';

      if (!mounted) return;
      setState(() {
        _contentCtrl.text = content;
        _loading          = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '오류가 발생했어요:\n$e'; _loading = false; });
    }
  }

  /// URL에서 원문 내용 추출 (YouTube description / OG / meta)
  Future<String> _fetchContent() async {
    try {
      final url = widget.item.url;
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        final vid = RegExp(r'(?:youtube\.com.*v=|youtu\.be/)([a-zA-Z0-9_-]{11})')
            .firstMatch(url)?.group(1);
        if (vid != null) {
          final res  = await http.get(Uri.parse('https://www.youtube.com/watch?v=$vid'))
              .timeout(const Duration(seconds: 8));
          final body = utf8.decode(res.bodyBytes, allowMalformed: true);
          final m    = RegExp(r'"shortDescription":"((?:[^"\\]|\\.)*)\"')
              .firstMatch(body);
          if (m != null) {
            final raw = m.group(1)!;
            return raw
                .replaceAll(r'\n', '\n')
                .replaceAll(r'\"', '"')
                .replaceAll(r'\\', '\\')
                .substring(0, raw.length.clamp(0, 3000));
          }
        }
      } else {
        final res  = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        final og   = RegExp(
            r"""<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)""",
            caseSensitive: false).firstMatch(body);
        if (og != null) return og.group(1)!;
        final desc = RegExp(
            r"""<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)""",
            caseSensitive: false).firstMatch(body);
        if (desc != null) return desc.group(1)!;
      }
    } catch (_) {}
    return '';
  }

  String _buildPrompt(String rawContent) => '''
아래 콘텐츠를 학습·보관 목적으로 상세하게 정리해주세요.

제목: ${widget.item.title}
URL: ${widget.item.url}
${rawContent.isNotEmpty ? '원문 내용:\n$rawContent' : ''}

다음 형식으로 작성해주세요 (마크다운):

## 📌 개요
(이 콘텐츠가 무엇인지 2~3문장으로 명확하게)

## 🎯 핵심 내용
- 핵심 내용 1 (충분히 상세하게)
- 핵심 내용 2
- 핵심 내용 3
(5~8개 항목, 각 항목을 구체적이고 명확하게)

## 💡 주요 개념
**개념/용어**: 설명 (한 문장)
(중요 개념이나 키워드 3~5개)

## 📚 학습 포인트
- 이 내용에서 배울 수 있는 핵심 교훈
- 실생활 적용 방법 또는 추가 탐구 방향

## 🔖 태그
#태그1 #태그2 #태그3 #태그4

## 🔗 원본
${widget.item.url}
''';

  // ── 마이룸 저장 ────────────────────────────────────────────────
  Future<void> _save() async {
    final title = _titleCtrl.text.trim().isEmpty
        ? widget.item.title
        : _titleCtrl.text.trim();

    final tags = RegExp(r'#(\S+)')
        .allMatches(_contentCtrl.text)
        .map((m) => m.group(1)!)
        .toList();

    final err = await ref.read(myroomNotifierProvider.notifier).addClip(
      url:          widget.item.url,
      title:        title,
      note:         _contentCtrl.text.trim(),
      thumbnailUrl: widget.item.thumbnailUrl,
      tags:         tags,
    );

    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('저장 실패: $err'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    Navigator.pop(context);
    widget.onSaved?.call();
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
              const Text('📝 컨텍스트 정리',
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
                        Text('AI가 내용을 상세하게 정리 중이에요...',
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
                              const Text('😢', style: TextStyle(fontSize: 40)),
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
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                        children: [
                          TextField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: '📌 제목',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _contentCtrl,
                            maxLines: null,
                            style: const TextStyle(fontSize: 14, height: 1.6),
                            decoration: const InputDecoration(
                              labelText: '📋 정리된 내용 (편집 가능)',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.bookmark_add),
                            label: const Text('마이룸에 저장'),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
