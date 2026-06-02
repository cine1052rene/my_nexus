import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_tile.dart';
import '../data/korean_holidays.dart';
import '../data/moon_void_data.dart';
import '../../../core/utils/lunar_converter.dart';
import 'add_event_sheet.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final focusedDay = ref.watch(focusedDayProvider);
    final moonVoid = ref.watch(moonVoidEnabledProvider);
    final lunar = ref.watch(lunarEnabledProvider);
    final dayEvents = ref.watch(dayEventsProvider(selectedDay));

    final lunarDate = LunarConverter.toSolar(selectedDay);
    final holiday = KoreanHolidays.getHoliday(selectedDay);
    final voidPeriod = moonVoid ? MoonVoidData.getVoidForDate(selectedDay) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 스케줄'),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_2_outlined,
                color: lunar ? const Color(0xFF6C63FF) : Colors.grey),
            tooltip: '음력 표시',
            onPressed: () => ref.read(lunarEnabledProvider.notifier).state = !lunar,
          ),
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
          // ── 달력 헤더 ─────────────────────────────────────────
          _CalendarWidget(
            focusedDay: focusedDay,
            selectedDay: selectedDay,
            moonVoid: moonVoid,
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

          // ── 문보이드 상세 (시작·종료 시간 + 별자리) ──────────
          if (voidPeriod != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🌑', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('문보이드 (Moon Void of Course)',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 시작
                      _VoidTimeCard(
                        label: '시작',
                        time: _fmtTime(voidPeriod.start),
                        icon: '🌒',
                        color: const Color(0xFF2A2A4E),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('→', style: TextStyle(color: Colors.white54, fontSize: 18)),
                      ),
                      // 종료
                      _VoidTimeCard(
                        label: '종료',
                        time: _fmtTime(voidPeriod.end),
                        icon: '🌕',
                        color: const Color(0xFF2A2A4E),
                      ),
                      const Spacer(),
                      // 이동 별자리
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF6C63FF), width: 1),
                        ),
                        child: Text(
                          '→ ${voidPeriod.entering}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ── 이벤트 목록 ──────────────────────────────────────
          Expanded(
            child: dayEvents.isEmpty
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

  String _formatDate(DateTime d) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})';
  }

  String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── 커스텀 달력 위젯 (table_calendar 없이) ───────────────────
class _CalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final bool moonVoid;
  final bool lunar;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _CalendarWidget({
    required this.focusedDay,
    required this.selectedDay,
    required this.moonVoid,
    required this.lunar,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final year = focusedDay.year;
    final month = focusedDay.month;

    // 이 달의 첫째 날
    final firstDay = DateTime(year, month, 1);
    // 첫째 날의 요일 (0=월, 6=일)
    final startWeekday = (firstDay.weekday - 1) % 7;
    // 이 달의 마지막 날
    final lastDay = DateTime(year, month + 1, 0).day;

    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    const headerStyle = TextStyle(fontWeight: FontWeight.w800, fontSize: 15);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          // 월 헤더
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onMonthChanged(DateTime(year, month - 1, 1)),
                ),
                Text('$year년 $month월', style: headerStyle),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => onMonthChanged(DateTime(year, month + 1, 1)),
                ),
              ],
            ),
          ),
          // 요일 헤더
          Row(
            children: weekdays.asMap().entries.map((e) {
              final isWeekend = e.key >= 5;
              return Expanded(
                child: Center(
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isWeekend ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // 날짜 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: startWeekday + lastDay,
            itemBuilder: (_, index) {
              if (index < startWeekday) return const SizedBox();
              final day = index - startWeekday + 1;
              final date = DateTime(year, month, day);
              final isSelected = _isSameDay(date, selectedDay);
              final isToday = _isSameDay(date, DateTime.now());
              final isHoliday = KoreanHolidays.isHoliday(date);
              final isVoid = moonVoid && MoonVoidData.isVoidToday(date);
              final isWeekend = date.weekday == DateTime.saturday ||
                  date.weekday == DateTime.sunday;

              final lunarDate = lunar ? LunarConverter.toSolar(date) : null;

              Color textColor = (isHoliday || isWeekend)
                  ? Colors.red[400]!
                  : Colors.black87;
              if (isSelected) textColor = Colors.white;

              return GestureDetector(
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
                    border: isVoid && !isSelected
                        ? Border.all(color: const Color(0xFF555577), width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 문보이드 배경 오버레이
                      if (isVoid && !isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w400,
                              color: textColor,
                            ),
                          ),
                          if (lunarDate != null)
                            Text(
                              '${lunarDate.day}',
                              style: TextStyle(
                                fontSize: 8,
                                color: isSelected
                                    ? Colors.white70
                                    : const Color(0xFF9999CC),
                              ),
                            ),
                        ],
                      ),
                      // 문보이드: 상단 작은 달 아이콘
                      if (isVoid && !isSelected)
                        const Positioned(
                          top: 1,
                          right: 1,
                          child: Text('🌑', style: TextStyle(fontSize: 7)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _VoidTimeCard extends StatelessWidget {
  final String label;
  final String time;
  final String icon;
  final Color color;
  const _VoidTimeCard({required this.label, required this.time, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$icon $label', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ],
    ),
  );
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
