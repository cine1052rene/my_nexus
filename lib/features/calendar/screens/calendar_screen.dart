import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_tile.dart';
import '../data/korean_holidays.dart';
import '../data/moon_void_data.dart';
import '../../../core/utils/lunar_converter.dart';
import '../../../core/constants/app_constants.dart';
import 'add_event_sheet.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final focusedDay = ref.watch(focusedDayProvider);
    final moonVoid = ref.watch(moonVoidEnabledProvider);
    final lunar = ref.watch(lunarEnabledProvider);
    final eventDays = ref.watch(eventDaysProvider);
    final dayEvents = ref.watch(dayEventsProvider(selectedDay));

    // 음력
    final lunarDate = LunarConverter.toSolar(selectedDay);
    // 공휴일
    final holiday = KoreanHolidays.getHoliday(selectedDay);
    // 문보이드
    final voidPeriod = moonVoid ? MoonVoidData.getVoidForDate(selectedDay) : null;

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
          // 문보이드 토글
          IconButton(
            icon: Text('🌑', style: TextStyle(
                fontSize: 20,
                color: moonVoid ? Colors.black : Colors.grey[400])),
            tooltip: '문보이드 달력',
            onPressed: () =>
                ref.read(moonVoidEnabledProvider.notifier).state = !moonVoid,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 달력 ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, selectedDay),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'ko_KR',
              onDaySelected: (selected, focused) {
                ref.read(selectedDayProvider.notifier).state = selected;
                ref.read(focusedDayProvider.notifier).state = focused;
              },
              onPageChanged: (focused) =>
                  ref.read(focusedDayProvider.notifier).state = focused,
              eventLoader: (day) {
                final key = DateTime(day.year, day.month, day.day);
                return eventDays[key] ?? [];
              },
              calendarBuilders: CalendarBuilders(
                // 요일 헤더 커스텀
                dowBuilder: (_, day) {
                  const weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
                  final text = weekdayNames[day.weekday - 1];
                  final isWeekend = day.weekday == DateTime.saturday ||
                      day.weekday == DateTime.sunday;
                  return Center(
                    child: Text(text,
                        style: TextStyle(
                          fontSize: 12,
                          color: isWeekend ? Colors.red : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        )),
                  );
                },
                // 날짜 셀 커스텀 (공휴일, 문보이드)
                defaultBuilder: (_, day, __) => _DayCell(
                  day: day,
                  isSelected: isSameDay(day, selectedDay),
                  moonVoid: moonVoid,
                  lunar: lunar,
                ),
                selectedBuilder: (_, day, __) => _DayCell(
                  day: day,
                  isSelected: true,
                  moonVoid: moonVoid,
                  lunar: lunar,
                ),
                todayBuilder: (_, day, __) => _DayCell(
                  day: day,
                  isToday: true,
                  isSelected: isSameDay(day, selectedDay),
                  moonVoid: moonVoid,
                  lunar: lunar,
                ),
                outsideBuilder: (_, day, __) => _DayCell(
                  day: day,
                  isOutside: true,
                  moonVoid: moonVoid,
                  lunar: lunar,
                ),
              ),
              calendarStyle: CalendarStyle(
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),

          // ── 선택일 정보 바 ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8F8FF),
            child: Row(
              children: [
                // 선택 날짜
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      () {
                        const wd = ['월', '화', '수', '목', '금', '토', '일'];
                        return '${selectedDay.month}월 ${selectedDay.day}일 (${wd[selectedDay.weekday - 1]})';
                      }(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (lunar)
                      Text(lunarDate.toString(),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6C63FF))),
                  ],
                ),
                const SizedBox(width: 10),
                // 공휴일
                if (holiday != null)
                  _InfoChip(label: holiday, color: Colors.red[50]!, textColor: Colors.red),
                // 문보이드
                if (voidPeriod != null) ...[
                  const SizedBox(width: 6),
                  _InfoChip(
                    label: '🌑 문보이드',
                    color: const Color(0xFF1A1A2E),
                    textColor: Colors.white,
                  ),
                ],
                const Spacer(),
                Text('${dayEvents.length}개', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),

          // 문보이드 상세
          if (voidPeriod != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFF1A1A2E),
              child: Text(
                '🌑 문보이드: ${voidPeriod.description}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),

          // ── 이벤트 목록 ──────────────────────────────────────
          Expanded(
            child: dayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('📅', style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 10),
                        Text('일정이 없어요', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: dayEvents.length,
                    itemBuilder: (_, i) {
                      final event = dayEvents[i];
                      return EventTile(
                        event: event,
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => AddEventSheet(editEvent: event),
                        ),
                        onDelete: () => ref
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

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final bool isOutside;
  final bool moonVoid;
  final bool lunar;

  const _DayCell({
    required this.day,
    this.isSelected = false,
    this.isToday = false,
    this.isOutside = false,
    required this.moonVoid,
    required this.lunar,
  });

  @override
  Widget build(BuildContext context) {
    final isHoliday = KoreanHolidays.isHoliday(day);
    final isVoid = moonVoid && MoonVoidData.isVoidToday(day);
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final lunarDate = lunar ? LunarConverter.toSolar(day) : null;

    Color textColor = isOutside
        ? Colors.grey[400]!
        : (isHoliday || isWeekend)
            ? Colors.red[400]!
            : Colors.black87;
    if (isSelected) textColor = Colors.white;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF6C63FF)
            : isToday
                ? const Color(0xFFEEEEFF)
                : isVoid
                    ? const Color(0xFFF0F0F0)
                    : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w400,
                  color: textColor,
                ),
              ),
              if (lunar && lunarDate != null)
                Text(
                  '${lunarDate.day}',
                  style: TextStyle(
                    fontSize: 8,
                    color: isSelected ? Colors.white70 : const Color(0xFF9999CC),
                  ),
                ),
            ],
          ),
          // 문보이드 작은 점
          if (isVoid && !isSelected)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 4, height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF555555),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
