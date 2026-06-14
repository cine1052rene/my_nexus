// Google Calendar(CalDAV)로 이전하여 사용하지 않는 파일
// device_calendar 패키지 의존성 제거됨
import '../../features/calendar/models/schedule_event.dart';

class NativeCalendarService {
  static Future<bool> requestPermission() async => false;
  static Future<List<ScheduleEvent>> getEventsForMonth(DateTime month) async => [];
}
