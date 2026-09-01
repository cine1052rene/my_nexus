import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule_event.dart';
import '../providers/calendar_provider.dart';
import '../../../core/constants/app_constants.dart';

class AddEventSheet extends ConsumerStatefulWidget {
  final ScheduleEvent? editEvent;
  final DateTime? initialDate;
  const AddEventSheet({super.key, this.editEvent, this.initialDate});

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _eventType = 'once';
  String _category = 'personal';
  String? _emoji;
  bool _allDay = true;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    if (widget.editEvent != null) {
      final e = widget.editEvent!;
      _titleCtrl.text = e.title;
      _notesCtrl.text = e.notes ?? '';
      _date = e.date;
      _eventType = e.eventType;
      _category = e.category;
      _emoji = e.emoji;
      _allDay = e.allDay;
      if (e.startTime != null) _startTime = TimeOfDay.fromDateTime(e.startTime!);
      if (e.endTime != null) _endTime = TimeOfDay.fromDateTime(e.endTime!);
    } else {
      _date = widget.initialDate ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정 제목을 입력해주세요')));
      return;
    }
    final notifier = ref.read(calendarNotifierProvider.notifier);
    DateTime? startDt;
    DateTime? endDt;
    if (!_allDay && _startTime != null) {
      startDt = DateTime(_date.year, _date.month, _date.day, _startTime!.hour, _startTime!.minute);
    }
    if (!_allDay && _endTime != null) {
      endDt = DateTime(_date.year, _date.month, _date.day, _endTime!.hour, _endTime!.minute);
    }

    final event = ScheduleEvent(
      id: widget.editEvent?.id ?? '',
      title: _titleCtrl.text.trim(),
      date: _date,
      eventType: _eventType,
      category: _category,
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      emoji: _emoji,
      allDay: _allDay,
      startTime: startDt,
      endTime: endDt,
    );

    String? err;
    if (widget.editEvent != null) {
      err = await notifier.updateEvent(event);
    } else {
      err = await notifier.addEvent(event);
    }

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $err')));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Text(widget.editEvent == null ? '📅 일정 추가' : '✏️ 일정 수정',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(onPressed: _save, child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  // 제목 + 이모지
                  Row(children: [
                    GestureDetector(
                      onTap: _pickEmoji,
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: const Color(0xFFF0EFFF), borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text(_emoji ?? '📅', style: const TextStyle(fontSize: 24))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '일정 제목 *'))),
                  ]),
                  const SizedBox(height: 16),

                  // 날짜 선택
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Color(0xFF6C63FF)),
                    title: Text(() {
                      const wd = ['월','화','수','목','금','토','일'];
                      return '${_date.year}년 ${_date.month}월 ${_date.day}일 (${wd[_date.weekday - 1]})';
                    }()),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),

                  // 종일/시간
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('종일'),
                    value: _allDay,
                    onChanged: (v) => setState(() => _allDay = v),
                  ),
                  if (!_allDay) ...[
                    Row(children: [
                      Expanded(child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time),
                        title: Text(_startTime?.format(context) ?? '시작 시간'),
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
                          if (t != null) setState(() => _startTime = t);
                        },
                      )),
                      const Text('~'),
                      Expanded(child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_endTime?.format(context) ?? '종료 시간'),
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _endTime ?? TimeOfDay.now());
                          if (t != null) setState(() => _endTime = t);
                        },
                      )),
                    ]),
                  ],
                  const SizedBox(height: 8),

                  // 반복 유형
                  const Text('반복', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      _typeChip('once', '일회성'),
                      _typeChip('daily', '매일'),
                      _typeChip('weekly', '매주'),
                      _typeChip('monthly', '매월'),
                      _typeChip('yearly', '매년'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 카테고리
                  const Text('카테고리', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: EventCategory.list.map((cat) => ChoiceChip(
                      label: Text('${cat.emoji} ${cat.label}'),
                      selected: _category == cat.id,
                      selectedColor: Color(cat.colorValue).withOpacity(0.2),
                      onSelected: (_) => setState(() => _category = cat.id),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '📝 메모', hintText: '추가 메모...'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label) => ChoiceChip(
    label: Text(label),
    selected: _eventType == type,
    onSelected: (_) => setState(() => _eventType = type),
  );

  void _pickEmoji() async {
    const emojis = ['📅', '🎂', '💊', '💼', '🎨', '🔔', '⭐', '🏃', '📚', '🎵',
                     '✈️', '🍽️', '💪', '🌙', '☀️', '❤️', '🎯', '🛒', '💰', '🎉'];
    final result = await showDialog<String>(
      context: context,
      // 다이얼로그 자신의 context로 pop해야 한다. 바깥 context를 쓰면
      // 다이얼로그가 아니라 현재 화면이 pop된다.
      builder: (dialogCtx) => AlertDialog(
        title: const Text('이모지 선택'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: emojis.map((e) => GestureDetector(
            onTap: () => Navigator.pop(dialogCtx, e),
            child: Text(e, style: const TextStyle(fontSize: 28)),
          )).toList(),
        ),
      ),
    );
    if (result != null) setState(() => _emoji = result);
  }
}
