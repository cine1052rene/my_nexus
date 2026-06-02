import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/hub/models/link_item.dart';
import '../../features/calendar/models/schedule_event.dart';

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

  // ── 컬렉션 참조 ──────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _linksCol =>
      _db.collection('links');

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _db.collection('events');

  // ── 링크 허브 CRUD ────────────────────────────────────────
  Stream<List<LinkItem>> linksStream({String? category}) {
    Query<Map<String, dynamic>> q = _linksCol.orderBy('createdAt', descending: true);
    if (category != null && category != 'all') {
      q = q.where('category', isEqualTo: category);
    }
    return q.snapshots().map((snap) {
      _reads += snap.docs.length;
      return snap.docs.map((d) => LinkItem.fromFirestore(d)).toList();
    });
  }

  Future<void> addLink(LinkItem item) async {
    await _linksCol.doc(item.id).set(item.toFirestore());
    _writes++;
  }

  Future<void> updateLink(LinkItem item) async {
    await _linksCol.doc(item.id).update(item.toFirestore());
    _writes++;
  }

  Future<void> deleteLink(String id) async {
    await _linksCol.doc(id).delete();
    _deletes++;
  }

  // ── 일정/이벤트 CRUD ──────────────────────────────────────
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

  // ── 사용량 리셋 ───────────────────────────────────────────
  void resetCounters() {
    _reads = 0;
    _writes = 0;
    _deletes = 0;
  }
}
