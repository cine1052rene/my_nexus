import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/link_item.dart';
import '../../../core/constants/app_constants.dart';

class LinkCard extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const LinkCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            if (item.displayThumbnail.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: item.displayThumbnail,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _UrlPreview(item: item),
                ),
              )
            else
              _UrlPreview(item: item),

            // 본문
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리 칩
                  Row(children: [
                    _CategoryChip(cat: cat),
                    const Spacer(),
                    _MenuButton(onEdit: onEdit, onDelete: onDelete),
                  ]),
                  const SizedBox(height: 6),

                  // 제목
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 요약
                  if (item.summary != null && item.summary!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EFFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.summary!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF5050AA)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // 메모
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📌 ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(
                            item.notes!,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 태그
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrlPreview extends StatelessWidget {
  final LinkItem item;
  const _UrlPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Center(
        child: Text(
          item.isYouTube ? '▶️ YouTube' :
          item.isTikTok ? '🎵 TikTok' : '🔗 링크',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final HubCategory cat;
  const _CategoryChip({required this.cat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('${cat.emoji} ${cat.label}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF))),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MenuButton({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      iconSize: 18,
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('✏️ 수정')),
        const PopupMenuItem(value: 'delete', child: Text('🗑️ 삭제')),
      ],
    );
  }
}
