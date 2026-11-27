import 'package:flutter/material.dart';

import '../models/link_item.dart';
import '../../../shared/services/analytics_service.dart';

/// 저장 직후 알림 (1.1.0) — hub_screen에서 분리 (파일 500줄 제한).
///
/// ① 새로 저장: 제목 + "왜 저장했어요?" 칩 4개. 고르지 않아도 사라지면 끝.
/// ② 이미 저장된 링크: 새로 만들지 않고 언제 저장했는지 알려준다.
///    "잊어버리고 또 받아온다"를 그 자리에서 끊는 장치.
class SaveFeedback {
  SaveFeedback._();

  static void saved(
    ScaffoldMessengerState messenger, {
    required String emoji,
    required LinkItem item,
    required VoidCallback onEdit,
    required void Function(String intent) onIntent,
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: '편집', onPressed: onEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji 저장됨: ${item.title}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in LinkIntent.labels.entries)
                _IntentChip(
                  label: e.value,
                  onTap: () {
                    onIntent(e.key);
                    AnalyticsService.intentPicked(e.key);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(milliseconds: 1200),
                      content: Text('${e.value}(으)로 표시했어요'),
                    ));
                  },
                ),
            ],
          ),
        ],
      ),
    ));
  }

  static void duplicate(
    ScaffoldMessengerState messenger, {
    required LinkItem existing,
    required VoidCallback onView,
  }) {
    final status = LinkStatus.labels[existing.status];
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: '보기', onPressed: onView),
      content: Text(
        '🔁 이미 저장한 링크예요 · ${ago(existing.createdAt)} 저장'
        '${status == null ? '' : ' · $status'}\n${existing.title}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ));
  }

  /// "오늘 / 어제 / 3일 전 / 2주 전 / 5개월 전"
  static String ago(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final days = DateTime(n.year, n.month, n.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    if (days <= 0) return '오늘';
    if (days == 1) return '어제';
    if (days < 14) return '$days일 전';
    if (days < 60) return '${days ~/ 7}주 전';
    if (days < 365) return '${days ~/ 30}개월 전';
    return '${days ~/ 365}년 전';
  }
}

class _IntentChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _IntentChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ),
      );
}
