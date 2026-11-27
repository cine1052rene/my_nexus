import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/link_item.dart';
import '../providers/hub_provider.dart';
import '../../../shared/services/analytics_service.dart';

/// DB허브 항목 열기 — 종류별로 다르게 연다.
///   링크 → 외부 앱/브라우저 / 캡처 → 이미지 뷰어 / 메모 → 본문 보기
///
/// 카드 3종(List·Grid·Compact)이 각자 launchUrl을 부르던 것을 한 곳으로 모았다.
/// "검색 중에 열었는가"를 같이 기록해 다시 찾기 성공률을 잰다.
Future<void> openHubItem(BuildContext context, LinkItem item) async {
  final fromSearch =
      ProviderScope.containerOf(context).read(hubSearchProvider).isNotEmpty;
  final type = switch (item.category) {
    'capture' => 'capture',
    'memo' => 'memo',
    _ => 'link',
  };
  AnalyticsService.itemOpened(type: type, fromSearch: fromSearch);
  // 열어 본 항목은 '봤음'으로 (안 봄·옛 항목만, 기다리지 않음)
  ProviderScope.containerOf(context).read(hubNotifierProvider.notifier).markSeen(item);

  switch (type) {
    case 'capture':
      return _showCapture(context, item);
    case 'memo':
      return _showMemo(context, item);
    default:
      final uri = Uri.tryParse(item.url);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _showCapture(BuildContext context, LinkItem item) {
  final text = item.description ?? '';
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 5,
            child: CachedNetworkImage(imageUrl: item.url, fit: BoxFit.contain),
          ),
        ),
        Positioned(
          top: 8, right: 8,
          child: SafeArea(
            // 흰 캡처 위에서도 보이도록 어두운 원형 배경 (실기기에서 X가 묻혔음)
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(dialogCtx),
            ),
          ),
        ),
        if (text.isNotEmpty)
          Positioned(
            left: 12, bottom: 12,
            child: SafeArea(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.text_snippet_outlined),
                label: const Text('읽은 글자 보기'),
                onPressed: () => _showText(dialogCtx, '캡처에서 읽은 글자', text),
              ),
            ),
          ),
      ]),
    ),
  );
}

Future<void> _showMemo(BuildContext context, LinkItem item) =>
    _showText(context, '메모', item.description ?? item.title);

Future<void> _showText(BuildContext context, String title, String text) {
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText(text)),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            Navigator.pop(dialogCtx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('복사했어요'), behavior: SnackBarBehavior.floating),
            );
          },
          child: const Text('복사'),
        ),
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('닫기')),
      ],
    ),
  );
}
