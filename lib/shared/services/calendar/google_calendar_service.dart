import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../features/calendar/models/schedule_event.dart';
import '../auth/google_auth_service.dart';

class GoogleCalendarService {
  /// 구글 캘린더 권한 요청 (로그인 + calendar 스코프 증분 요청)
  static Future<bool> requestPermission() async {
    final token = await getCalendarAccessToken();
    return token != null;
  }

  /// 현재 연결 상태
  static bool get isConnected => appGoogleSignIn.currentUser != null;

  /// Calendar 연결 해제 (앱 로그아웃 X — 스코프만 해제 불가, 토글 OFF만)
  static Future<void> disconnect() async {
    // Google API는 클라이언트에서 개별 스코프 취소 불가
    // 토글 OFF 처리는 provider에서 상태만 false로 변경
  }

  /// 특정 월의 Google Calendar 이벤트 → ScheduleEvent 리스트로 반환
  static Future<List<ScheduleEvent>> getEventsForMonth(DateTime month) async {
    try {
      final token = await getCalendarAccessToken();
      if (token == null) return [];

      // 해당 월 범위 (UTC)
      final timeMin =
          DateTime(month.year, month.month, 1).toUtc().toIso8601String();
      final timeMax =
          DateTime(month.year, month.month + 1, 1).toUtc().toIso8601String();

      final uri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/primary/events',
        {
          'timeMin': timeMin,
          'timeMax': timeMax,
          'singleEvents': 'true',
          'orderBy': 'startTime',
          'maxResults': '250',
        },
      );

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];

      return items
          .map((e) => _parseEvent(e as Map<String, dynamic>))
          .whereType<ScheduleEvent>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static ScheduleEvent? _parseEvent(Map<String, dynamic> item) {
    try {
      final title = item['summary'] as String? ?? '(제목 없음)';
      final startMap = item['start'] as Map<String, dynamic>?;
      final endMap = item['end'] as Map<String, dynamic>?;
      if (startMap == null) return null;

      final allDay = startMap.containsKey('date');
      DateTime start;
      DateTime? end;

      if (allDay) {
        start = DateTime.parse(startMap['date'] as String);
        final endStr = endMap?['date'] as String?;
        // Google Calendar: 종일 이벤트 종료일은 exclusive → 1일 빼기
        end = endStr != null
            ? DateTime.parse(endStr).subtract(const Duration(days: 1))
            : start;
      } else {
        start = DateTime.parse(startMap['dateTime'] as String).toLocal();
        final endStr = endMap?['dateTime'] as String?;
        end = endStr != null ? DateTime.parse(endStr).toLocal() : null;
      }

      return ScheduleEvent(
        id: 'gcal_${item['id']}',
        title: title,
        date: start,
        endDate: end,
        allDay: allDay,
        startTime: allDay ? null : start,
        endTime: allDay ? null : end,
        notes: item['description'] as String?,
        isNative: true, // 읽기 전용 (구글 캘린더)
      );
    } catch (_) {
      return null;
    }
  }
}
