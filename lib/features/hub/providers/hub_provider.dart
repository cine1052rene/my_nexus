import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/link_item.dart';
import '../../../shared/services/data/firestore_service.dart';
import '../../../shared/services/thumbnail_store.dart';
import '../../../shared/services/capture_service.dart';
import '../../../shared/services/link_metadata_service.dart';
import '../../../shared/utils/link_key.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

// 선택된 카테고리 필터
final hubCategoryProvider = StateProvider<String>((ref) => 'all');

// 검색어
final hubSearchProvider = StateProvider<String>((ref) => '');

// 보기 모드 (list / grid / compact)
final hubViewModeProvider = StateProvider<HubViewMode>((ref) => HubViewMode.list);

// 유튜브 키워드 서브필터 (null = 전체)
final hubYoutubeKeywordProvider = StateProvider<String?>((ref) => null);

// 안 본 것만 보기 (1.1.0) — status가 unseen인 항목만
final hubUnseenOnlyProvider = StateProvider<bool>((ref) => false);

// 링크 스트림 (Firestore 실시간)
// currentUserProvider를 watch해야 계정 전환 시 스트림이 새 사용자 경로로
// 다시 만들어진다. 안 하면 이전 사용자의 링크가 화면에 계속 남는다.
final linksStreamProvider = StreamProvider.family<List<LinkItem>, String>((
  ref,
  category,
) {
  ref.watch(currentUserProvider);
  return FirestoreService().linksStream(category: category);
});

// 필터링된 링크 목록 (검색 + 유튜브 키워드 인메모리 필터)
final filteredLinksProvider = Provider<AsyncValue<List<LinkItem>>>((ref) {
  final category   = ref.watch(hubCategoryProvider);
  final search     = ref.watch(hubSearchProvider);
  final ytKeyword  = ref.watch(hubYoutubeKeywordProvider);
  final unseenOnly = ref.watch(hubUnseenOnlyProvider);
  final links      = ref.watch(linksStreamProvider(category));

  return links.when(
    data: (items) {
      var result = items;
      if (unseenOnly) {
        result = result.where((i) => i.status == LinkStatus.unseen).toList();
      }

      // 검색어 필터
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        // description에는 메모 본문·캡처에서 읽은 글자가 들어 있다
        result = result.where((item) =>
          item.title.toLowerCase().contains(q) ||
          (item.description?.toLowerCase().contains(q) ?? false) ||
          (item.summary?.toLowerCase().contains(q) ?? false) ||
          (item.notes?.toLowerCase().contains(q) ?? false) ||
          item.tags.any((t) => t.toLowerCase().contains(q)),
        ).toList();
      }

      // 유튜브 키워드 서브필터 (제목 + 태그 패턴 매칭)
      if (category == 'youtube' && ytKeyword != null) {
        final kw = YoutubeKeyword.all_list
            .cast<YoutubeKeyword?>()
            .firstWhere((k) => k?.id == ytKeyword, orElse: () => null);
        if (kw != null) {
          result = result.where((item) {
            final lower    = item.title.toLowerCase();
            final tagLower = item.tags.join(' ').toLowerCase();
            return kw.patterns.any((p) =>
              lower.contains(p.toLowerCase()) ||
              tagLower.contains(p.toLowerCase()),
            );
          }).toList();
        }
      }

      return AsyncData(result);
    },
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});

// ── 링크 CRUD 노티파이어 ────────────────────────────────────────
class HubNotifier extends Notifier<void> {
  @override
  void build() {}

  final _service = FirestoreService();
  final _uuid    = const Uuid();

  Future<String?> addLink({
    required String url,
    required String title,
    required String category,
    String? description,
    String? thumbnailUrl,
    String? summary,
    String? notes,
    List<String> tags = const [],
  }) async {
    try {
      final item = LinkItem(
        id: _uuid.v4(), url: url, title: title, category: category,
        description: description, thumbnailUrl: thumbnailUrl,
        summary: summary, notes: notes, tags: tags,
        createdAt: DateTime.now(),
        urlKey: await urlKeyFor(url), status: LinkStatus.unseen,
      );
      await _service.addLink(item);
      persistThumbnail(item);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 만료되는 SNS 썸네일이면 Storage에 복사한 뒤 주소를 바꿔 둔다.
  /// 저장을 기다리게 하지 않으려고 백그라운드로 돌린다(결과를 await 안 함).
  /// 사본 주소는 만료 주소가 아니므로 이 갱신이 다시 복사를 부르지 않는다.
  void persistThumbnail(LinkItem item) {
    if (!ThumbnailStore.needsCopy(item.thumbnailUrl)) return;
    ThumbnailStore.copy(item.id, item.thumbnailUrl).then((copied) async {
      if (copied == null) return;
      try {
        await _service.updateThumbnail(item.id, copied);
      } catch (_) {}
    });
  }

  /// 이 링크의 중복 판별 키. 틱톡 단축링크는 공유마다 코드가 달라서
  /// 실제 주소로 풀어야 같은 영상끼리 같은 키가 된다.
  static Future<String> urlKeyFor(String url) async {
    var target = url;
    if (url.contains('tiktok.com')) {
      target = await LinkMetadataService.resolveTikTok(url);
    }
    return canonicalLinkKey(target);
  }

  /// 같은 콘텐츠를 이미 저장했다면 그 항목 (없거나 조회 실패면 null)
  Future<LinkItem?> findDuplicate(String url) async {
    try {
      return await _service.findDuplicate(
          urlKey: await urlKeyFor(url), url: url);
    } catch (_) {
      return null;
    }
  }

  /// 공유 시트에서 빠른 저장.
  /// 같은 콘텐츠가 이미 있으면 새로 만들지 않고 기존 항목을 duplicate로 돌려준다
  /// — 예전엔 조용히 기존 항목을 "저장됨"으로 보여줘서 또 저장한 줄 몰랐다.
  Future<SaveOutcome?> quickAddLink({
    required String url,
    required String title,
    required String category,
    String? thumbnailUrl,
    List<String> tags = const [],
  }) async {
    try {
      final key = await urlKeyFor(url);
      // 중복 확인이 실패(오프라인 등)해도 저장은 계속한다 — 놓치는 쪽이 낫다
      LinkItem? existing;
      try {
        existing = await _service
            .findDuplicate(urlKey: key, url: url)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      if (existing != null) return SaveOutcome(existing, duplicate: true);

      final item = LinkItem(
        id: _uuid.v4(), url: url, title: title, category: category,
        thumbnailUrl: thumbnailUrl, tags: tags, createdAt: DateTime.now(),
        urlKey: key, status: LinkStatus.unseen,
      );
      await _service.addLink(item);
      persistThumbnail(item);
      return SaveOutcome(item);
    } catch (_) {
      return null;
    }
  }

  /// 상태·저장 이유 등 일부 필드만 갱신
  Future<void> setFields(String id, Map<String, Object?> fields) async {
    try {
      await _service.updateFields(id, fields);
    } catch (_) {}
  }

  /// 열어 본 링크는 '봤음'으로 — 안 봄·옛 항목만 (적용함·버림은 유지)
  Future<void> markSeen(LinkItem item) async {
    if (item.status != null && item.status != LinkStatus.unseen) return;
    await setFields(item.id, {'status': LinkStatus.seen});
  }

  Future<String?> updateLink(LinkItem item) async {
    try {
      await _service.updateLink(item);
      persistThumbnail(item);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 이미 id가 정해진 항목 저장 (메모·캡처 — Storage 경로와 id를 맞추기 위해)
  Future<String?> addItem(LinkItem item) async {
    try {
      await _service.addLink(item);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String newId() => _uuid.v4();

  Future<String?> deleteLink(String id) async {
    try {
      await _service.deleteLink(id);
      ThumbnailStore.delete(id);
      CaptureService.delete(id); // 캡처가 아니면 404 — 조용히 넘어간다
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final hubNotifierProvider = NotifierProvider<HubNotifier, void>(HubNotifier.new);

/// 빠른 저장 결과 — [duplicate]면 새로 저장하지 않고 기존 항목을 돌려준 것
class SaveOutcome {
  final LinkItem item;
  final bool duplicate;
  const SaveOutcome(this.item, {this.duplicate = false});
}
