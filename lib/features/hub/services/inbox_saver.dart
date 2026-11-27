import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/link_item.dart';
import '../providers/hub_provider.dart';
import '../../../shared/services/analytics_service.dart';
import '../../../shared/services/capture_service.dart';
import '../../../shared/utils/inbox_utils.dart';

/// 링크가 아닌 공유물(메모·캡처)을 DB허브 항목으로 저장한다.
///
/// 저장 위치는 링크와 같은 `users/{uid}/links` 컬렉션이고 category만
/// 'memo' / 'capture'로 다르다. 그래서 목록·검색·챗봇·계정 삭제가
/// 기존 코드 그대로 이 항목들을 다룬다.
///   memo    — url 비움, description = 본문
///   capture — url·thumbnailUrl = Storage 이미지, description = 읽은 글자
class InboxSaver {
  InboxSaver._();

  static Future<LinkItem?> saveMemo(WidgetRef ref, String text) async {
    final notifier = ref.read(hubNotifierProvider.notifier);
    final item = LinkItem(
      id: notifier.newId(),
      url: '',
      title: titleFromText(text, fallback: '메모'),
      category: 'memo',
      description: text,
      tags: const [],
      createdAt: DateTime.now(),
      status: LinkStatus.seen, // 직접 쓴 메모는 이미 본 것
    );
    final err = await notifier.addItem(item);
    if (err != null) return null;
    AnalyticsService.itemSaved(type: 'memo', via: 'share');
    return item;
  }

  /// 글자 인식·압축·업로드까지 몇 초 걸린다. 실패하면 예외.
  static Future<LinkItem> saveCapture(WidgetRef ref, String imagePath) async {
    final notifier = ref.read(hubNotifierProvider.notifier);
    final id = notifier.newId();
    final now = DateTime.now();
    final result = await CaptureService.process(id, imagePath);
    final item = LinkItem(
      id: id,
      url: result.imageUrl,
      title: titleFromText(result.ocrText, fallback: defaultCaptureTitle(now)),
      category: 'capture',
      thumbnailUrl: result.imageUrl,
      description: clampOcrText(result.ocrText),
      tags: const [],
      createdAt: now,
      status: LinkStatus.unseen, // 캡처는 나중에 다시 볼 것
    );
    final err = await notifier.addItem(item);
    if (err != null) {
      await CaptureService.delete(id); // 문서 저장 실패 시 이미지 고아 방지
      throw StateError(err);
    }
    AnalyticsService.itemSaved(type: 'capture', via: 'share');
    return item;
  }
}
