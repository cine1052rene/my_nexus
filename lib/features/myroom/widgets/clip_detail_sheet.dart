import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/video_clip.dart';

/// 마이룸 클립 상세 보기 시트
/// - 저장된 정리 내용을 읽기 좋게 표시
/// - 원본 링크 열기 버튼 포함
class ClipDetailSheet extends StatelessWidget {
  final VideoClip clip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ClipDetailSheet({
    super.key,
    required this.clip,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _open() async {
    final uri = Uri.tryParse(clip.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platformColor = Color(clip.platform.colorValue);
    final isDarkPlatform = clip.platform.colorValue == 0xFF010101;

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
          // 헤더: 플랫폼 배지 + 메뉴
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: platformColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${clip.platform.emoji} ${clip.platform.label}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDarkPlatform ? Colors.grey[700] : platformColor,
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) {
                  Navigator.pop(context);
                  if (v == 'edit')   onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit',
                      child: Text('✏️ 수정')),
                  PopupMenuItem(value: 'delete',
                      child: Text('🗑️ 삭제',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ]),
          ),
          // 제목
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: Text(
              clip.title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, height: 1.4),
            ),
          ),
          const Divider(),

          // 내용 영역
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (clip.note != null && clip.note!.isNotEmpty)
                  _NoteRenderer(note: clip.note!)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text('정리된 내용이 없어요.',
                          style: TextStyle(color: Colors.grey[400])),
                    ),
                  ),

                // 태그 chips
                if (clip.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: clip.tags.map((t) => Chip(
                      label: Text('#$t',
                          style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: const Color(0xFFEDE9FF),
                      labelStyle: const TextStyle(color: Color(0xFF6C63FF)),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 80), // FAB 여백
              ],
            ),
          ),

          // 원본 링크 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('원본 링크 열기',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 마크다운 간단 렌더러 ────────────────────────────────────────────
/// ## 헤더, - 리스트, **bold**, #태그 를 스타일링해서 렌더링
class _NoteRenderer extends StatelessWidget {
  final String note;
  const _NoteRenderer({required this.note});

  static const _accentColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    final lines = note.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('## ')) {
        // 섹션 헤더
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 6),
          child: Text(
            line.substring(3),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _accentColor,
            ),
          ),
        ));
      } else if (line.startsWith('# ')) {
        // 대 헤더
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 6),
          child: Text(
            line.substring(2),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('• ')) {
        // 리스트 항목
        final text = line.startsWith('- ')
            ? line.substring(2)
            : line.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('• ',
                    style: TextStyle(fontSize: 14, color: _accentColor,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(child: _InlineText(text: text)),
            ],
          ),
        ));
      } else if (line.startsWith('http://') || line.startsWith('https://')) {
        // URL 라인 → 링크처럼 표시
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            line,
            style: const TextStyle(
              fontSize: 13,
              color: _accentColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ));
      } else if (RegExp(r'^#\w').hasMatch(line)) {
        // 태그 라인 (#태그1 #태그2)
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(line,
              style: const TextStyle(
                  fontSize: 13,
                  color: _accentColor,
                  fontWeight: FontWeight.w600)),
        ));
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 4));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _InlineText(text: line),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

/// **bold** 인라인 파싱
class _InlineText extends StatelessWidget {
  final String text;
  const _InlineText({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts  = text.split(RegExp(r'\*\*'));
    final spans  = <TextSpan>[];

    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd
            ? const TextStyle(fontWeight: FontWeight.w700)
            : null,
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 14, height: 1.65, color: Colors.black87),
        children: spans,
      ),
    );
  }
}
