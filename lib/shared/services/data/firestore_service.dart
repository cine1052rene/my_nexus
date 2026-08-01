import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/hub/models/link_item.dart';
import '../../../features/calendar/models/schedule_event.dart';
import '../../../features/myroom/models/video_clip.dart';
import '../../../features/myroom/models/myroom_tag.dart';

/// Firestore CRUD 서비스 + 사용량 추적
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._();
  factory FirestoreService() => _instance;
  FirestoreService._();

  final _db = FirebaseFirestore.instance;

  // 사용량 카운터 (세션 기반)
  int _reads = 0;
  int _writes = 0;
  int _deletes = 0;

  int get reads => _reads;
  int get writes => _writes;
  int get deletes => _deletes;

  // ── 컬렉션 참조 ────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _linksCol =>
      _db.collection('links');

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _db.collection('events');

  CollectionReference<Map<String, dynamic>> get _clipsCol =>
      _db.collection('video_clips');

  DocumentReference<Map<String, dynamic>> get _myroomTagsDoc =>
      _db.collection('settings').doc('myroom_tags');

  // ── 링크 허브 CRUD ──────────────────────────────────────────
  Stream<List<LinkItem>> linksStream({String? category}) {
    // 카테고리 필터 시 where + orderBy 복합 인덱스 불필요하게 orderBy를 client-side로 처리
    Query<Map<String, dynamic>> q;
    if (category != null && category != 'all') {
      // 단일 필드 where만 사용 → 복합 인덱스 불필요, 정렬은 client-side
      q = _linksCol.where('category', isEqualTo: category);
    } else {
      // 전체 조회는 orderBy만 → 단일 필드 인덱스 자동 생성됨
      q = _linksCol.orderBy('createdAt', descending: true);
    }
    return q.snapshots().map((snap) {
      _reads += snap.docs.length;
      final items = snap.docs.map((d) => LinkItem.fromFirestore(d)).toList();
      // 카테고리 필터 시 client-side 최신순 정렬
      if (category != null && category != 'all') {
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      return items;
    });
  }

  Future<void> addLink(LinkItem item) async {
    await _linksCol.doc(item.id).set(item.toFirestore());
    _writes++;
  }

  /// 전체 링크 목록 1회 조회 (챗봇 컨텍스트 주입용)
  Future<List<LinkItem>> getAllLinks({int limit = 100}) async {
    final snap = await _linksCol
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    _reads += snap.docs.length;
    return snap.docs.map((d) => LinkItem.fromFirestore(d)).toList();
  }

  /// URL로 기존 링크 검색 (중복 저장 방지용)
  Future<LinkItem?> findByUrl(String url) async {
    final snap = await _linksCol
        .where('url', isEqualTo: url)
        .limit(1)
        .get();
    _reads++;
    if (snap.docs.isEmpty) return null;
    return LinkItem.fromFirestore(snap.docs.first);
  }

  Future<void> updateLink(LinkItem item) async {
    await _linksCol.doc(item.id).update(item.toFirestore());
    _writes++;
  }

  Future<void> deleteLink(String id) async {
    await _linksCol.doc(id).delete();
    _deletes++;
  }

  // ── 일정/이벤트 CRUD ────────────────────────────────────────
  Stream<List<ScheduleEvent>> eventsStream() {
    return _eventsCol.snapshots().map((snap) {
      _reads += snap.docs.length;
      return snap.docs.map((d) => ScheduleEvent.fromFirestore(d)).toList();
    });
  }

  Future<void> addEvent(ScheduleEvent event) async {
    await _eventsCol.doc(event.id).set(event.toFirestore());
    _writes++;
  }

  Future<void> updateEvent(ScheduleEvent event) async {
    await _eventsCol.doc(event.id).update(event.toFirestore());
    _writes++;
  }

  Future<void> deleteEvent(String id) async {
    await _eventsCol.doc(id).delete();
    _deletes++;
  }

  // ── 마이룸 비디오 클립 CRUD ─────────────────────────────────
  Stream<List<VideoClip>> clipsStream({String? platform}) {
    Query<Map<String, dynamic>> q =
        _clipsCol.orderBy('createdAt', descending: true);
    if (platform != null && platform != 'all') {
      q = q.where('platform', isEqualTo: platform);
    }
    return q.snapshots().map((snap) {
      _reads += snap.docs.length;
      return snap.docs.map((d) => VideoClip.fromFirestore(d)).toList();
    });
  }

  Future<void> addClip(VideoClip clip) async {
    await _clipsCol.doc(clip.id).set(clip.toFirestore());
    _writes++;
  }

  Future<void> updateClip(VideoClip clip) async {
    await _clipsCol.doc(clip.id).update(clip.toFirestore());
    _writes++;
  }

  Future<void> deleteClip(String id) async {
    await _clipsCol.doc(id).delete();
    _deletes++;
  }

  // ── 마이룸 태그 설정 ────────────────────────────────────────
  Stream<List<MyroomTag>> myroomTagsStream() {
    return _myroomTagsDoc.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return MyroomTag.defaults;
      final raw = snap.data()!['tags'] as List<dynamic>?;
      if (raw == null || raw.isEmpty) return MyroomTag.defaults;
      return raw
          .map((e) => MyroomTag.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> saveMyroomTags(List<MyroomTag> tags) async {
    await _myroomTagsDoc.set({'tags': tags.map((t) => t.toMap()).toList()});
    _writes++;
  }

  // ── 사용량 리셋 ─────────────────────────────────────────────
  void resetCounters() {
    _reads = 0;
    _writes = 0;
    _deletes = 0;
  }
}
