import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/video_clip.dart';
import 'clip_detail_sheet.dart';

class ClipCard extends StatelessWidget {
  final VideoClip clip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ClipCard({
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

  /// note가 있으면 상세 시트, 없으면 URL 바로 열기
  void _handleTap(BuildContext context) {
    if (clip.note != null && clip.note!.isNotEmpty) {
      _showDetailSheet(context);
    } else {
      _open();
    }
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipDetailSheet(
        clip: clip,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('열기'),
              onTap: () { Navigator.pop(context); _open(); },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('수정'),
              onTap: () { Navigator.pop(context); onEdit(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('삭제', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); onDelete(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platformColor = Color(clip.platform.colorValue);

    return GestureDetector(
      onTap: () => _handleTap(context),
      onLongPress: () => _showOptions(context),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 썸네일 ──
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: clip.thumbUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: clip.thumbUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _PlatformPlaceholder(platform: clip.platform),
                          )
                        : _PlatformPlaceholder(platform: clip.platform),
                  ),
                  // 📝 인디케이터: note가 있는 클립임을 표시
                  if (clip.note != null && clip.note!.isNotEmpty)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('📝',
                            style: TextStyle(fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
            // ── 정보 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 플랫폼 배지
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: platformColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${clip.platform.emoji} ${clip.platform.label}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: platformColor == const Color(0xFF010101)
                            ? Colors.grey[700]
                            : platformColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // 제목
                  Text(
                    clip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformPlaceholder extends StatelessWidget {
  final ClipPlatform platform;
  const _PlatformPlaceholder({required this.platform});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(platform.colorValue).withOpacity(0.1),
      child: Center(
        child: Text(platform.emoji, style: const TextStyle(fontSize: 36)),
      ),
    );
  }
}
