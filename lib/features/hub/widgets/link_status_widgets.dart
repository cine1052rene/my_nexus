import 'package:flutter/material.dart';

import '../models/link_item.dart';

const _purple = Color(0xFF6C63FF);

/// 카드에 붙는 작은 표시 — 안 본 링크는 보라 점, 저장 이유가 있으면 그 이름.
/// 1.1.0 이전 항목(status 없음)은 아무것도 안 붙인다.
class LinkStatusBadge extends StatelessWidget {
  final LinkItem item;
  const LinkStatusBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final unseen = item.status == LinkStatus.unseen;
    final done = item.status == LinkStatus.applied;
    final intent = LinkIntent.labels[item.intent];
    if (!unseen && !done && intent == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 6, runSpacing: 4, children: [
        if (unseen) _pill('● 안 봄', _purple),
        if (done) _pill('✓ 적용함', const Color(0xFF2E9E6B)),
        if (intent != null) _pill(intent, Colors.grey.shade600),
      ]),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
      );
}

/// 편집 화면의 상태·저장 이유 선택 줄
class LinkStatusPicker extends StatelessWidget {
  final String? status;
  final String? intent;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onIntent;
  const LinkStatusPicker({
    super.key,
    required this.status,
    required this.intent,
    required this.onStatus,
    required this.onIntent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Label('상태'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in LinkStatus.labels.entries)
          _chip(e.value, status == e.key, () => onStatus(e.key)),
      ]),
      const SizedBox(height: 12),
      const _Label('저장한 이유'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in LinkIntent.labels.entries)
          _chip(e.value, intent == e.key, () => onIntent(e.key)),
      ]),
      const SizedBox(height: 12),
    ]);
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => ChoiceChip(
        label: Text(label,
            style: TextStyle(
              fontSize: 13,
              color: sel ? _purple : Colors.black87,
              fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
            )),
        selected: sel,
        selectedColor: const Color(0xFFEDE9FF),
        backgroundColor: Colors.grey.shade100,
        side: BorderSide(
            color: sel ? _purple : Colors.grey.shade300, width: sel ? 1.5 : 1),
        onSelected: (_) => onTap(),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
      );
}
