import 'package:flutter/material.dart';
import '../models/email_message.dart';

class EmailTile extends StatelessWidget {
  final EmailMessage email;
  final VoidCallback onTap;

  const EmailTile({super.key, required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: email.isRead ? Colors.white : const Color(0xFFF0EFFF),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFEEEEF5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 발신자 아바타
            _Avatar(name: email.fromName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          email.fromName,
                          style: TextStyle(
                            fontWeight: email.isRead
                                ? FontWeight.w400
                                : FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(email.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email.subject,
                    style: TextStyle(
                      fontWeight: email.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          email.snippet,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (email.hasAttachment) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.attach_file,
                            size: 14, color: Colors.grey[400]),
                      ],
                      if (email.isStarred) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star,
                            size: 14, color: Color(0xFFFFBF00)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // AI 카테고리 칩
                  _CategoryChip(category: email.category),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.month}/${d.day}';
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF6C63FF), const Color(0xFF4285F4),
      const Color(0xFF0F9D58), const Color(0xFFDB4437),
      const Color(0xFFF4B400),
    ];
    final colorIdx = name.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return CircleAvatar(
      radius: 22,
      backgroundColor: colors[colorIdx],
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final EmailCategory category;
  const _CategoryChip({required this.category});

  static const _colors = {
    EmailCategory.work: Color(0xFFE8F0FE),
    EmailCategory.personal: Color(0xFFE6F4EA),
    EmailCategory.newsletter: Color(0xFFFCE8B2),
    EmailCategory.notification: Color(0xFFFCE8E8),
    EmailCategory.other: Color(0xFFF1F3F4),
  };
  static const _textColors = {
    EmailCategory.work: Color(0xFF1A73E8),
    EmailCategory.personal: Color(0xFF137333),
    EmailCategory.newsletter: Color(0xFFB06000),
    EmailCategory.notification: Color(0xFFB00020),
    EmailCategory.other: Color(0xFF5F6368),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _colors[category],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${category.emoji} ${category.label}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _textColors[category],
        ),
      ),
    );
  }
}
