import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/video_clip.dart';
import '../../../shared/services/firestore_service.dart';

// 선택된 플랫폼 필터
final myroomPlatformProvider = StateProvider<String>((ref) => 'all');

// 검색어
final myroomSearchProvider = StateProvider<String>((ref) => '');

// 클립 스트림 (플랫폼 필터별)
final clipsStreamProvider = StreamProvider.family<List<VideoClip>, String>(
  (ref, platform) => FirestoreService().clipsStream(platform: platform),
);

// 필터링된 클립 목록
final filteredClipsProvider = Provider<AsyncValue<List<VideoClip>>>((ref) {
  final platform = ref.watch(myroomPlatformProvider);
  final search = ref.watch(myroomSearchProvider);
  final clips = ref.watch(clipsStreamProvider(platform));

  return clips.when(
    data: (items) {
      if (search.isEmpty) return AsyncData(items);
      final q = search.toLowerCase();
      return AsyncData(
        items.where((c) =>
          c.title.toLowerCase().contains(q) ||
          (c.note?.toLowerCase().contains(q) ?? false) ||
          c.tags.any((t) => t.toLowerCase().contains(q)),
        ).toList(),
      );
    },
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});

// 클립 CRUD 액션
class MyroomNotifier extends Notifier<void> {
  @override
  void build() {}

  final _svc = FirestoreService();
  final _uuid = const Uuid();

  Future<String?> addClip({
    required String url,
    required String title,
    String? note,
    String? thumbnailUrl,
    List<String> tags = const [],
  }) async {
    try {
      final clip = VideoClip(
        id: _uuid.v4(),
        url: url,
        title: title,
        platform: ClipPlatform.detect(url),
        thumbnailUrl: thumbnailUrl,
        note: note,
        tags: tags,
        createdAt: DateTime.now(),
      );
      await _svc.addClip(clip);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateClip(VideoClip clip) async {
    try {
      await _svc.updateClip(clip);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteClip(String id) async {
    try {
      await _svc.deleteClip(id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final myroomNotifierProvider =
    NotifierProvider<MyroomNotifier, void>(MyroomNotifier.new);
