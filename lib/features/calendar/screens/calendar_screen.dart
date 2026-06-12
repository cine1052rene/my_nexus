import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_tile.dart';
import '../data/korean_holidays.dart';
import '../../../core/utils/lunar_converter.dart';
import '../../../shared/services/google_calendar_service.dart';
import 'add_event_sheet.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final focusedDay = ref.watch(focusedDayProvider);
    final lunar = ref.watch(lunarEnabledProvider);
    final googleEnabled = ref.watch(googleCalendarEnabledProvider);

    // Firestore 이벤트
    final firestoreEvents = ref.watch(dayEventsProvider(selectedDay));

    // 구글 캘린더 이벤트 (해당 월 전체 → 선택일 필터)
    final monthKey = DateTime(selectedDay.year, selectedDay.month, 1);
    final googleAsync = ref.watch(googleCalendarEventsProvider(monthKey));
    final googleEvents = googleAsync.when(
      data: (list) => list.where((e) => e.occursOn(selectedDay)).toList(),
      loading: () => <dynamic>[],
      error: (_, __) => <dynamic>[],
    );

    final allEvents = [...firestoreEvents, ...googleEvents];

    final lunarDate = LunarConverter.toSolar(selectedDay);
    final holiday = KoreanHolidays.getHoliday(selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 스케줄'),
        actions: [
          // 음력 토글
          IconButton(
            icon: Icon(Icons.brightness_2_outlined,
                color: lunar ? const Color(0xFF6C63FF) : Colors.grey),
            tooltip: '음력 표시',
            onPressed: () => ref.read(lunarEnabledProvider.notifier).state = !lunar,
          ),
          // 구글 캘린더 토글
          IconButton(
            icon: Icon(
              Icons.calendar_today,
              color: googleEnabled ? const Color(0xFF4285F4) : Colors.grey,
            ),
            tooltip: '구글 캘린더 연동',
            onPressed: () => _toggleGoogleCalendar(context, ref, googleEnabled),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 달력 ─────────────────────────────────────────────
          _CalendarWidget(
            focusedDay: focusedDay,
            selectedDay: selectedDay,
            lunar: lunar,
            onDaySelected: (day) {
              ref.read(selectedDayProvider.notifier).state = day;
              ref.read(focusedDayProvider.notifier).state = day;
            },
            onMonthChanged: (month) {
              ref.read(focusedDayProvider.notifier).state = month;
            },
          ),

          // ── 선택일 정보 바 ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8F8FF),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(selectedDay),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (lunar)
                      Text(lunarDate.toString(),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6C63FF))),
                  ],
                ),
                const SizedBox(width: 10),
                if (holiday != null)
                  _InfoChip(label: holiday, color: Colors.red.shade50, textColor: Colors.red),
                if (googleEnabled && googleAsync.isLoading) ...[
                  const SizedBox(width: 6),
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
                const Spacer(),
                Text('${allEvents.length}개',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),

          // ── 이벤트 목록 ──────────────────────────────────────
          Expanded(
            child: allEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📅', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 10),
                        Text('일정이 없어요', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: allEvents.length,
                    itemBuilder: (_, i) {
                      final event = allEvents[i];
                      return EventTile(
                        event: event,
                        onTap: () {
                          if (!event.isNative) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => AddEventSheet(editEvent: event),
                            );
                          }
                        },
                        onDelete: event.isNative
                            ? null
                            : () => ref
                                .read(calendarNotifierProvider.notifier)
                                .deleteEvent(event.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddEventSheet(initialDate: selectedDay),
        ),
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
    );
  }

  Future<void> _toggleGoogleCalendar(
      BuildContext context, WidgetRef ref, bool currentEnabled) async {
    if (!currentEnabled) {
      final granted = await GoogleCalendarService.requestPermission();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구글 캘린더 연동에 실패했어요. 다시 시도해주세요.')),
        );
        return;
      }
      ref.read(googleCalendarEnabledProvider.notifier).state = true;
    } else {
      await GoogleCalendarService.disconnect();
      ref.read(googleCalendarEnabledProvider.notifier).state = false;
    }
  }

  String _formatDate(DateTime d) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})';
  }
}

// ── 커스텀 달력 위젯 ──────────────────────────────────────────
class _CalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final bool lunar;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _CalendarWidget({
    required this.focusedDay,
    required this.selectedDay,
    required this.lunar,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final year = focusedDay.year;
    final month = focusedDay.month;
    final firstDay = DateTime(year, month, 1);
    final startWeekday = (firstDay.weekday - 1) % 7; // 0=월
    final lastDay = DateTime(year, month + 1, 0).day;

    final allDays = <DateTime?>[];
    for (int i = 0; i < startWeekday; i++) allDays.add(null);
    for (int d = 1; d <= lastDay; d++) allDays.add(DateTime(year, month, d));
    while (allDays.length % 7 != 0) allDays.add(null);

    final weeks = <List<DateTime?>>[];
    for (int i = 0; i < allDays.length; i += 7) {
      weeks.add(allDays.sublist(i, i + 7));
    }

    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Column(
        children: [
          // ── 월 헤더
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onMonthChanged(DateTime(year, month - 1, 1)),
                ),
                Text('$year년 $month월',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => onMonthChanged(DateTime(year, month + 1, 1)),
                ),
              ],
            ),
          ),
          // ── 요일 헤더
          Row(
            children: weekdays.asMap().entries.map((e) {
              final isWeekend = e.key >= 5;
              return Expanded(
                child: Center(
                  child: Text(e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isWeekend ? Colors.red : Colors.grey[600],
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 2),
          // ── 주 단위 행
          ...weeks.map((week) {
            return Row(
              children: week.asMap().entries.map((e) {
                final col = e.key;
                final date = e.value;
                if (date == null) {
                  return Expanded(child: AspectRatio(aspectRatio: 1, child: Container()));
                }
                final isSelected = _isSameDay(date, selectedDay);
                final isToday = _isSameDay(date, DateTime.now());
                final isHoliday = KoreanHolidays.isHoliday(date);
                final isWeekend = col >= 5;
                final lunarDate = lunar ? LunarConverter.toSolar(date) : null;

                Color textColor = (isHoliday || isWeekend)
                    ? Colors.red[400]!
                    : Colors.black87;
                if (isSelected) textColor = Colors.white;

                return Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GestureDetector(
                      onTap: () => onDaySelected(date),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6C63FF)
                              : isToday
                                  ? const Color(0xFFEEEEFF)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${date.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday || isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                  color: textColor,
                                )),
                            if (lunarDate != null)
                              Text('${lunarDate.day}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: isSelected
                                        ? Colors.white70
                                        : const Color(0xFF9999CC),
                                  )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _InfoChip({required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
  );
}
