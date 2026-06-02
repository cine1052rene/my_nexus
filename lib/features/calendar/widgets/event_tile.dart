import 'package:flutter/material.dart';
import '../models/schedule_event.dart';
import '../../../core/constants/app_constants.dart';

class EventTile extends StatelessWidget {
  final ScheduleEvent event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const EventTile({
    super.key,
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = EventCategory.fromId(event.category);
    final color = Color(event.colorValue ?? cat.colorValue);

    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('일정 삭제'),
            content: Text('"${event.title}"을 삭제할까요?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
              TextButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('삭제', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(event.emoji ?? cat.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!event.allDay && event.startTime != null)
                Text(
                  '${event.startTime!.hour.toString().padLeft(2,'0')}:${event.startTime!.minute.toString().padLeft(2,'0')}' +
                  (event.endTime != null ? ' ~ ${event.endTime!.hour.toString().padLeft(2,'0')}:${event.endTime!.minute.toString().padLeft(2,'0')}' : ''),
                  style: TextStyle(fontSize: 11, color: color),
                ),
              Row(children: [
                _RecurringBadge(eventType: event.eventType),
                const SizedBox(width: 4),
                Text(cat.label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ],
          ),
          trailing: Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecurringBadge extends StatelessWidget {
  final String eventType;
  const _RecurringBadge({required this.eventType});

  String get _label {
    switch (eventType) {
      case 'daily': return '매일';
      case 'weekly': return '매주';
      case 'monthly': return '매월';
      case 'yearly': return '매년';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (eventType == 'once') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('🔄 $_label', style: const TextStyle(fontSize: 10, color: Color(0xFF6C63FF))),
    );
  }
}
