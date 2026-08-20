import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../hub/models/link_item.dart';

/// 챗봇 응답에 첨부되는 링크 카드 목록.
///
/// 로컬 쿼리가 찾아낸 링크를 텍스트로 나열하면 URL을 복사해야 해서
/// 불편하다. 탭하면 바로 열리는 카드로 보여준다.
class ChatLinkList extends StatelessWidget {
  final List<LinkItem> links;
  const ChatLinkList({super.key, required this.links});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ChatLinkTile(link: link),
            ),
        ],
      ),
    );
  }
}

class _ChatLinkTile extends StatelessWidget {
  final LinkItem link;
  const _ChatLinkTile({required this.link});

  Future<void> _open() async {
    final uri = Uri.tryParse(link.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = HubCategory.fromId(link.category);
    final thumb = link.displayThumbnail;

    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 (없으면 카테고리 이모지)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 42,
                child: thumb.isNotEmpty
                    ? Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _EmojiThumb(emoji: cat.emoji),
                      )
                    : _EmojiThumb(emoji: cat.emoji),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    link.title.isNotEmpty ? link.title : link.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${cat.emoji} ${cat.label}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      if (link.tags.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            link.tags.take(2).map((t) => '#$t').join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 14, color: Color(0xFFAAAAAA)),
          ],
        ),
      ),
    );
  }
}

class _EmojiThumb extends StatelessWidget {
  final String emoji;
  const _EmojiThumb({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F2F7),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}
