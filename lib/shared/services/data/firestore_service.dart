import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../features/hub/models/link_item.dart';
import '../../../features/calendar/models/schedule_event.dart';
import '../../../features/myroom/models/video_clip.dart';
import '../../../features/myroom/models/myroom_tag.dart';

/// 로그인하지 않은 상태에서 사용자 데이터에 접근하려 할 때 발생.
class NotSignedInException implements Exception {
  @override
  String toString() => '로그인이 필요합니다.';
}

/// Firestore CRUD 서비스 + 사용량 추적
///
/// **데이터는 전부 `users/{uid}/` 하위에 격리된다.** 예전에는 links·events·
/// video_clips·settings가 최상위 전역 컬렉션이라 로그인한 모든 사용자가
/// 서로의 데이터를 읽고 쓸 수 있었다(싱글 유저 전제). 다중 사용자 배포에는
/// 치명적이므로 서브컬렉션 구조로 전환했다.
///
/// 서브컬렉션을 쓰면 보안 규칙이 경로만으로 완결되고, 쿼리에서 소유자
/// 필터를 빠뜨려 데이터가 새는 실수 자체가 불가능해진다.
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

  /// 현재 로그인 사용자 uid (미로그인 시 null)
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ── 컬렉션 참조 (모두 users/{uid} 하위) ────────────────────
  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = currentUid;
    if (uid == null) throw NotSignedInException();
    return _db.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get _linksCol =>
      _userDoc.collection('links');

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _userDoc.collection('events');

  CollectionReference<Map<String, dynamic>> get _clipsCol =>
      _userDoc.collection('video_clips');

  DocumentReference<Map<String, dynamic>> get _myroomTagsDoc =>
      _userDoc.collection('settings').doc('myroom_tags');

  // ── 링크 허브 CRUD ──────────────────────────────────────────
  Stream<List<LinkItem>> linksStream({String? category}) {
    // 로그아웃 상태에서는 빈 목록 (이전 사용자 데이터가 남지 않도록)
    if (currentUid == null) return Stream.value(const []);

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

  /// 전체 링크 목록 1회 조회 (챗봇 로컬 쿼리용)
  Future<List<LinkItem>> getAllLinks({int limit = 100}) async {
    if (currentUid == null) return const [];
    final snap = await _linksCol
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    _reads += snap.docs.length;
    return snap.docs.map((d) => LinkItem.fromFirestore(d)).toList();
  }

  /// URL로 기존 링크 검색 (중복 저장 방지용)
  Future<LinkItem?> findByUrl(String url) async {
    if (currentUid == null) return null;
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
    if (currentUid == null) return Stream.value(const []);
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
    if (currentUid == null) return Stream.value(const []);
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
    if (currentUid == null) return Stream.value(MyroomTag.defaults);
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
