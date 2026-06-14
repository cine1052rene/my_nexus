import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import '../../features/calendar/models/schedule_event.dart';

class NativeCalendarService {
  static final _plugin = DeviceCalendarPlugin();

  /// 권한 요청 — true면 허용됨
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final result = await _plugin.requestPermissions();
      return result.isSuccess && (result.data ?? false);
    } catch (_) {
      return false;
    }
  }

  /// 해당 월의 네이티브 캘린더 이벤트를 ScheduleEvent 리스트로 반환
  static Future<List<ScheduleEvent>> getEventsForMonth(DateTime month) async {
    if (kIsWeb) return [];
    try {
      // 권한 확인
      var perm = await _plugin.hasPermissions();
      if (!(perm.data ?? false)) {
        perm = await _plugin.requestPermissions();
        if (!(perm.data ?? false)) return [];
      }

      // 캘린더 목록
      final calsResult = await _plugin.retrieveCalendars();
      if (!calsResult.isSuccess || calsResult.data == null) return [];

      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final events = <ScheduleEvent>[];

      for (final cal in calsResult.data!) {
        if (cal.id == null) continue;
        final evResult = await _plugin.retrieveEvents(
          cal.id!,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        if (!evResult.isSuccess || evResult.data == null) continue;

        for (final e in evResult.data!) {
          if (e.title == null || e.start == null) continue;
          final isAllDay = e.allDay ?? true;
          events.add(ScheduleEvent(
            id: 'native_${e.eventId ?? e.title}_${e.start!.millisecondsSinceEpoch}',
            title: e.title!,
            date: e.start!,
            endDate: e.end,
            allDay: isAllDay,
            startTime: isAllDay ? null : e.start,
            endTime: isAllDay ? null : e.end,
            notes: e.description,
            isNative: true,
            calendarColor: cal.color,
          ));
        }
      }
      return events;
    } catch (_) {
      return [];
    }
  }
}
