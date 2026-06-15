import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/link_item.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../core/constants/app_constants.dart';

// 선택된 카테고리 필터
final hubCategoryProvider = StateProvider<String>((ref) => 'all');

// 검색어
final hubSearchProvider = StateProvider<String>((ref) => '');

// 보기 모드 (list / grid / compact)
final hubViewModeProvider = StateProvider<HubViewMode>((ref) => HubViewMode.list);

// 유튜브 키워드 서브필터 (null = 전체)
final hubYoutubeKeywordProvider = StateProvider<String?>((ref) => null);

// 링크 스트림 (Firestore 실시간)
final linksStreamProvider = StreamProvider.family<List<LinkItem>, String>(
  (ref, category) => FirestoreService().linksStream(category: category),
);

// 필터링된 링크 목록 (검색 + 유튜브 키워드 인메모리 필터)
final filteredLinksProvider = Provider<AsyncValue<List<LinkItem>>>((ref) {
  final category   = ref.watch(hubCategoryProvider);
  final search     = ref.watch(hubSearchProvider);
  final ytKeyword  = ref.watch(hubYoutubeKeywordProvider);
  final links      = ref.watch(linksStreamProvider(category));

  return links.when(
    data: (items) {
      var result = items;

      // 검색어 필터
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        result = result.where((item) =>
          item.title.toLowerCase().contains(q) ||
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
      );
      await _service.addLink(item);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 공유 시트에서 빠른 저장 (태그 포함)
  Future<LinkItem?> quickAddLink({
    required String url,
    required String title,
    required String category,
    String? thumbnailUrl,
    List<String> tags = const [],
  }) async {
    try {
      final item = LinkItem(
        id: _uuid.v4(), url: url, title: title, category: category,
        thumbnailUrl: thumbnailUrl, tags: tags, createdAt: DateTime.now(),
      );
      await _service.addLink(item);
      return item;
    } catch (_) {
      return null;
    }
  }

  Future<String?> updateLink(LinkItem item) async {
    try {
      await _service.updateLink(item);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteLink(String id) async {
    try {
      await _service.deleteLink(id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final hubNotifierProvider = NotifierProvider<HubNotifier, void>(HubNotifier.new);
