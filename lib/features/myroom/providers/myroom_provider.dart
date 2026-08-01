import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/video_clip.dart';
import '../models/myroom_tag.dart';
import '../../../shared/services/data/firestore_service.dart';

// 검색어
final myroomSearchProvider = StateProvider<String>((ref) => '');

// 선택된 콘텐츠 태그 필터 (null = 전체)
final myroomSelectedTagProvider = StateProvider<String?>((ref) => null);

// 사용자 커스텀 태그 목록 (Firestore, 없으면 기본값)
final myroomTagsProvider = StreamProvider<List<MyroomTag>>(
  (ref) => FirestoreService().myroomTagsStream(),
);

// 클립 스트림 (전체)
final clipsStreamProvider = StreamProvider<List<VideoClip>>(
  (ref) => FirestoreService().clipsStream(),
);

// 필터링된 클립 목록
final filteredClipsProvider = Provider<AsyncValue<List<VideoClip>>>((ref) {
  final search = ref.watch(myroomSearchProvider);
  final selectedTag = ref.watch(myroomSelectedTagProvider);
  final clips = ref.watch(clipsStreamProvider);

  return clips.when(
    data: (items) {
      var filtered = items;
      if (selectedTag != null) {
        filtered =
            filtered.where((c) => c.tags.contains(selectedTag)).toList();
      }
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        filtered = filtered
            .where((c) =>
                c.title.toLowerCase().contains(q) ||
                (c.note?.toLowerCase().contains(q) ?? false) ||
                c.tags.any((t) => t.toLowerCase().contains(q)))
            .toList();
      }
      return AsyncData(filtered);
    },
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});

// 클립 + 태그 CRUD 액션
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

  Future<String?> saveTags(List<MyroomTag> tags) async {
    try {
      await _svc.saveMyroomTags(tags);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final myroomNotifierProvider =
    NotifierProvider<MyroomNotifier, void>(MyroomNotifier.new);
