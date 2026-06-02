// Firebase Spark (무료) 플랜 한도
class FirebaseLimits {
  static const int firestoreReadsPerDay = 50000;
  static const int firestoreWritesPerDay = 20000;
  static const int firestoreDeletesPerDay = 20000;
  static const int storageGb = 5;
}

// 링크 허브 카테고리
class HubCategory {
  final String id;
  final String label;
  final String emoji;

  const HubCategory({required this.id, required this.label, required this.emoji});

  static const all = HubCategory(id: 'all', label: '전체', emoji: '📋');
  static const youtube = HubCategory(id: 'youtube', label: '유튜브', emoji: '▶️');
  static const tiktok = HubCategory(id: 'tiktok', label: '틱톡', emoji: '🎵');
  static const knitting = HubCategory(id: 'knitting', label: '뜨개질', emoji: '🧶');
  static const cooking = HubCategory(id: 'cooking', label: '요리', emoji: '🍳');
  static const recipe = HubCategory(id: 'recipe', label: '레시피', emoji: '📝');
  static const etc = HubCategory(id: 'etc', label: '기타', emoji: '📌');

  static const List<HubCategory> all_list = [
    all, youtube, tiktok, knitting, cooking, recipe, etc
  ];

  static HubCategory fromId(String id) {
    return all_list.firstWhere((c) => c.id == id, orElse: () => etc);
  }
}

// 일정 유형
class EventType {
  static const String once = 'once';          // 일회성
  static const String daily = 'daily';        // 매일
  static const String weekly = 'weekly';      // 매주
  static const String monthly = 'monthly';    // 매월
  static const String yearly = 'yearly';      // 매년 (생일 등)
}

// 일정 카테고리
class EventCategory {
  final String id;
  final String label;
  final String emoji;
  final int colorValue;

  const EventCategory({
    required this.id,
    required this.label,
    required this.emoji,
    required this.colorValue,
  });

  static const personal = EventCategory(id: 'personal', label: '개인', emoji: '👤', colorValue: 0xFF6C63FF);
  static const birthday = EventCategory(id: 'birthday', label: '생일', emoji: '🎂', colorValue: 0xFFFF6584);
  static const health = EventCategory(id: 'health', label: '건강', emoji: '💊', colorValue: 0xFF4CAF50);
  static const work = EventCategory(id: 'work', label: '일', emoji: '💼', colorValue: 0xFF2196F3);
  static const hobby = EventCategory(id: 'hobby', label: '취미', emoji: '🎨', colorValue: 0xFFFF9800);
  static const reminder = EventCategory(id: 'reminder', label: '리마인더', emoji: '🔔', colorValue: 0xFF9C27B0);

  static const List<EventCategory> list = [
    personal, birthday, health, work, hobby, reminder
  ];

  static EventCategory fromId(String id) {
    return list.firstWhere((c) => c.id == id, orElse: () => personal);
  }
}
