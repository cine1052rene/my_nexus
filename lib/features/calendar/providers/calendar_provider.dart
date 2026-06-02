import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_event.dart';
import '../../../shared/services/firestore_service.dart';

// 선택된 날짜
final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

// 표시 중인 달
final focusedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

// 문보이드 온/오프
final moonVoidEnabledProvider = StateProvider<bool>((ref) => true);

// 음력 표시 온/오프
final lunarEnabledProvider = StateProvider<bool>((ref) => true);

// 전체 이벤트 스트림
final eventsStreamProvider = StreamProvider<List<ScheduleEvent>>(
  (ref) => FirestoreService().eventsStream(),
);

// 특정 날짜의 이벤트 목록
final dayEventsProvider = Provider.family<List<ScheduleEvent>, DateTime>((ref, day) {
  final events = ref.watch(eventsStreamProvider);
  return events.when(
    data: (list) => list.where((e) => e.occursOn(day)).toList()
      ..sort((a, b) => a.title.compareTo(b.title)),
    loading: () => [],
    error: (_, __) => [],
  );
});

// 달력 마커용 — 어떤 날에 이벤트가 있는지
final eventDaysProvider = Provider<Map<DateTime, List<ScheduleEvent>>>((ref) {
  final events = ref.watch(eventsStreamProvider);
  return events.when(
    data: (list) {
      final map = <DateTime, List<ScheduleEvent>>{};
      // 오늘 기준 ±3개월 범위에서 반복 일정 전개
      final now = DateTime.now();
      for (int i = -90; i <= 90; i++) {
        final day = DateTime(now.year, now.month, now.day + i);
        final dayEvents = list.where((e) => e.occursOn(day)).toList();
        if (dayEvents.isNotEmpty) {
          map[DateTime(day.year, day.month, day.day)] = dayEvents;
        }
      }
      return map;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

class CalendarNotifier extends Notifier<void> {
  @override
  void build() {}

  final _service = FirestoreService();
  final _uuid = const Uuid();

  Future<String?> addEvent(ScheduleEvent event) async {
    try {
      final e = ScheduleEvent(
        id: _uuid.v4(),
        title: event.title,
        date: event.date,
        endDate: event.endDate,
        eventType: event.eventType,
        category: event.category,
        notes: event.notes,
        emoji: event.emoji,
        colorValue: event.colorValue,
        allDay: event.allDay,
        startTime: event.startTime,
        endTime: event.endTime,
      );
      await _service.addEvent(e);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateEvent(ScheduleEvent event) async {
    try {
      await _service.updateEvent(event);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteEvent(String id) async {
    try {
      await _service.deleteEvent(id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final calendarNotifierProvider =
    NotifierProvider<CalendarNotifier, void>(CalendarNotifier.new);
