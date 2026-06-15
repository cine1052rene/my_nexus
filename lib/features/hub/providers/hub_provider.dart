import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/link_item.dart';
import '../../../shared/services/firestore_service.dart';

// 선택된 카테고리 필터
final hubCategoryProvider = StateProvider<String>((ref) => 'all');

// 검색어
final hubSearchProvider = StateProvider<String>((ref) => '');

// 링크 스트림
final linksStreamProvider = StreamProvider.family<List<LinkItem>, String>(
  (ref, category) => FirestoreService().linksStream(category: category),
);

// 필터링된 링크 목록
final filteredLinksProvider = Provider<AsyncValue<List<LinkItem>>>((ref) {
  final category = ref.watch(hubCategoryProvider);
  final search = ref.watch(hubSearchProvider);
  final links = ref.watch(linksStreamProvider(category));

  return links.when(
    data: (items) {
      if (search.isEmpty) return AsyncData(items);
      final q = search.toLowerCase();
      return AsyncData(items.where((item) =>
        item.title.toLowerCase().contains(q) ||
        (item.summary?.toLowerCase().contains(q) ?? false) ||
        (item.notes?.toLowerCase().contains(q) ?? false) ||
        item.tags.any((t) => t.toLowerCase().contains(q))
      ).toList());
    },
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});

// 링크 추가/수정/삭제 액션
class HubNotifier extends Notifier<void> {
  @override
  void build() {}

  final _service = FirestoreService();
  final _uuid = const Uuid();

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
        id: _uuid.v4(),
        url: url,
        title: title,
        category: category,
        description: description,
        thumbnailUrl: thumbnailUrl,
        summary: summary,
        notes: notes,
        tags: tags,
        createdAt: DateTime.now(),
      );
      await _service.addLink(item);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 공유 시트에서 빠른 저장 (카테고리/메타데이터 자동 감지 후 즉시 저장)
  Future<LinkItem?> quickAddLink({
    required String url,
    required String title,
    required String category,
    String? thumbnailUrl,
  }) async {
    try {
      final item = LinkItem(
        id: _uuid.v4(),
        url: url,
        title: title,
        category: category,
        thumbnailUrl: thumbnailUrl,
        tags: [],
        createdAt: DateTime.now(),
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
