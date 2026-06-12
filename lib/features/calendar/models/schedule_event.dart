import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleEvent {
  final String id;
  final String title;
  final DateTime date;
  final DateTime? endDate;
  final String eventType;   // EventType 상수 참고
  final String category;   // EventCategory.id
  final String? notes;
  final String? emoji;
  final int? colorValue;
  final bool allDay;
  final DateTime? startTime;  // 시간 포함 일정용
  final DateTime? endTime;
  final bool isNative;         // 폰 기본 캘린더에서 읽어온 일정
  final int? calendarColor;    // 캘린더 앱 색상

  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.date,
    this.endDate,
    this.eventType = 'once',
    this.category = 'personal',
    this.notes,
    this.emoji,
    this.colorValue,
    this.allDay = true,
    this.startTime,
    this.endTime,
    this.isNative = false,
    this.calendarColor,
  });

  factory ScheduleEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ScheduleEvent(
      id: doc.id,
      title: d['title'] ?? '',
      date: (d['date'] as Timestamp).toDate(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      eventType: d['eventType'] ?? 'once',
      category: d['category'] ?? 'personal',
      notes: d['notes'],
      emoji: d['emoji'],
      colorValue: d['colorValue'],
      allDay: d['allDay'] ?? true,
      startTime: (d['startTime'] as Timestamp?)?.toDate(),
      endTime: (d['endTime'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'date': Timestamp.fromDate(date),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'eventType': eventType,
    'category': category,
    'notes': notes,
    'emoji': emoji,
    'colorValue': colorValue,
    'allDay': allDay,
    'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
    'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
  };

  /// 반복 일정이 특정 날짜에 해당하는지 확인
  bool occursOn(DateTime checkDate) {
    final d = DateTime(date.year, date.month, date.day);
    final c = DateTime(checkDate.year, checkDate.month, checkDate.day);

    // 네이티브 일정: 시작일~종료일 범위 체크
    if (isNative) {
      final end = endDate != null
          ? DateTime(endDate!.year, endDate!.month, endDate!.day)
          : d;
      return !c.isBefore(d) && !c.isAfter(end);
    }

    if (eventType == 'once') return d == c;
    if (d.isAfter(c)) return false;

    switch (eventType) {
      case 'daily':
        return true;
      case 'weekly':
        return d.weekday == c.weekday;
      case 'monthly':
        return d.day == c.day;
      case 'yearly':
        return d.month == c.month && d.day == c.day;
      default:
        return d == c;
    }
  }

  ScheduleEvent copyWith({
    String? title,
    DateTime? date,
    DateTime? endDate,
    String? eventType,
    String? category,
    String? notes,
    String? emoji,
    int? colorValue,
    bool? allDay,
    DateTime? startTime,
    DateTime? endTime,
  }) => ScheduleEvent(
    id: id,
    title: title ?? this.title,
    date: date ?? this.date,
    endDate: endDate ?? this.endDate,
    eventType: eventType ?? this.eventType,
    category: category ?? this.category,
    notes: notes ?? this.notes,
    emoji: emoji ?? this.emoji,
    colorValue: colorValue ?? this.colorValue,
    allDay: allDay ?? this.allDay,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
  );
}
