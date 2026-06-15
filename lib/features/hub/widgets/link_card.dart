import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/link_item.dart';
import '../../../core/constants/app_constants.dart';

/// 뷰모드에 따라 List / Grid / Compact 카드를 렌더링
class LinkCard extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final HubViewMode viewMode;

  const LinkCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.viewMode = HubViewMode.list,
  });

  @override
  Widget build(BuildContext context) {
    return switch (viewMode) {
      HubViewMode.grid    => _GridCard(item: item, onEdit: onEdit, onDelete: onDelete),
      HubViewMode.compact => _CompactRow(item: item, onEdit: onEdit, onDelete: onDelete),
      _                   => _ListCard(item: item, onEdit: onEdit, onDelete: onDelete),
    };
  }
}

// ── List 모드 (썸네일 풀 카드) ──────────────────────────────────
class _ListCard extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ListCard({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cat = HubCategory.fromId(item.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(item.url);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 썸네일
          if (item.displayThumbnail.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: item.displayThumbnail,
                height: 140, width: double.infinity, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _Placeholder(item: item),
              ),
            )
          else
            _Placeholder(item: item),

          // 본문
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _CatChip(cat: cat),
                const Spacer(),
                _Menu(onEdit: onEdit, onDelete: onDelete),
              ]),
              const SizedBox(height: 6),
              Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (item.summary != null && item.summary!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EFFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(item.summary!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5050AA)),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              ],
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: item.tags.map((t) => Chip(
                    label: Text(t, style: const TextStyle(fontSize: 10)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Grid 모드 (2열 그리드, 작은 썸네일) ───────────────────────────
class _GridCard extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _GridCard({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cat = HubCategory.fromId(item.category);
    return Card(
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(item.url);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 썸네일
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: item.displayThumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.displayThumbnail,
                    height: 110, width: double.infinity, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _Placeholder(item: item, height: 110),
                  )
                : _Placeholder(item: item, height: 110),
          ),
          // 제목 + 메뉴
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${cat.emoji} ${cat.label}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600)),
                ),
                _Menu(onEdit: onEdit, onDelete: onDelete, iconSize: 16),
              ]),
              const SizedBox(height: 4),
              Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (item.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(item.tags.take(2).join(' · '),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Compact 모드 (텍스트 전용) ─────────────────────────────────────
class _CompactRow extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CompactRow({required this.item, required this.onEdit, required this.onDelete});

  String _domain(String url) {
    try { return Uri.parse(url).host.replaceFirst('www.', ''); }
    catch (_) { return url; }
  }

  @override
  Widget build(BuildContext context) {
    final cat = HubCategory.fromId(item.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(item.url);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_domain(item.url),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EFFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item.tags.first,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6C63FF))),
              ),
            ],
            _Menu(onEdit: onEdit, onDelete: onDelete, iconSize: 16),
          ]),
        ),
      ),
    );
  }
}

// ── 공통 서브위젯 ───────────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  final LinkItem item;
  final double height;
  const _Placeholder({required this.item, this.height = 80});

  @override
  Widget build(BuildContext context) => Container(
    height: height, width: double.infinity,
    decoration: const BoxDecoration(
      color: Color(0xFFF0EFFF),
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: Center(
      child: Text(
        item.isYouTube ? '▶️' : item.isTikTok ? '🎵' : '🔗',
        style: TextStyle(fontSize: height > 90 ? 36 : 26),
      ),
    ),
  );
}

class _CatChip extends StatelessWidget {
  final HubCategory cat;
  const _CatChip({required this.cat});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EFFF), borderRadius: BorderRadius.circular(12)),
    child: Text('${cat.emoji} ${cat.label}',
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF))),
  );
}

class _Menu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final double iconSize;
  const _Menu({required this.onEdit, required this.onDelete, this.iconSize = 18});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    iconSize: iconSize,
    padding: EdgeInsets.zero,
    onSelected: (v) {
      if (v == 'edit') onEdit();
      if (v == 'delete') onDelete();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit',   child: Text('✏️ 수정')),
      const PopupMenuItem(value: 'delete', child: Text('🗑️ 삭제')),
    ],
  );
}
