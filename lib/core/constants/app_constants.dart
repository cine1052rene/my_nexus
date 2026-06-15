// Firebase Spark (무료) 플랜 한도
class FirebaseLimits {
  static const int firestoreReadsPerDay = 50000;
  static const int firestoreWritesPerDay = 20000;
  static const int firestoreDeletesPerDay = 20000;
  static const int storageGb = 5;
}

// 허브 보기 모드
enum HubViewMode { list, grid, compact }

// 링크 허브 카테고리
class HubCategory {
  final String id;
  final String label;
  final String emoji;

  const HubCategory({required this.id, required this.label, required this.emoji});

  static const all     = HubCategory(id: 'all',      label: '전체',   emoji: '📋');
  static const youtube = HubCategory(id: 'youtube',  label: '유튜브', emoji: '▶️');
  static const tiktok  = HubCategory(id: 'tiktok',   label: '틱톡',   emoji: '🎵');
  static const knitting= HubCategory(id: 'knitting', label: '뜨개질', emoji: '🧶');
  static const cooking = HubCategory(id: 'cooking',  label: '요리',   emoji: '🍳');
  static const recipe  = HubCategory(id: 'recipe',   label: '레시피', emoji: '📝');
  static const etc     = HubCategory(id: 'etc',      label: '기타',   emoji: '📌');

  static const List<HubCategory> all_list = [
    all, youtube, tiktok, knitting, cooking, recipe, etc,
  ];

  static HubCategory fromId(String id) =>
      all_list.firstWhere((c) => c.id == id, orElse: () => etc);
}

// YouTube 키워드 분류 (제목/태그 패턴 매칭)
class YoutubeKeyword {
  final String id;
  final String label;
  final String emoji;
  final List<String> patterns;

  const YoutubeKeyword({
    required this.id,
    required this.label,
    required this.emoji,
    required this.patterns,
  });

  static const knitting = YoutubeKeyword(
    id: 'yt_knitting', label: '뜨개질', emoji: '🧶',
    patterns: ['뜨개', '코바늘', 'knitting', 'crochet', '뜨기', '털실', '대바늘', '니팅'],
  );
  static const cooking = YoutubeKeyword(
    id: 'yt_cooking', label: '요리', emoji: '🍳',
    patterns: ['요리', '레시피', 'recipe', 'cooking', '음식', '먹방', '맛집', '쿠킹', '베이킹'],
  );
  static const game = YoutubeKeyword(
    id: 'yt_game', label: '게임', emoji: '🎮',
    patterns: ['게임', 'game', 'gaming', 'lol', 'minecraft', '마인크래프트', '롤', '플레이'],
  );
  static const beauty = YoutubeKeyword(
    id: 'yt_beauty', label: '뷰티', emoji: '💄',
    patterns: ['뷰티', '화장', 'makeup', '메이크업', '스킨케어', 'skincare', '파운데이션', '립스틱'],
  );
  static const fitness = YoutubeKeyword(
    id: 'yt_fitness', label: '운동', emoji: '💪',
    patterns: ['운동', '헬스', 'workout', 'fitness', '다이어트', '홈트', '필라테스', '요가'],
  );
  static const music = YoutubeKeyword(
    id: 'yt_music', label: '음악', emoji: '🎵',
    patterns: ['뮤직비디오', 'official audio', 'official video', '커버', 'cover', '노래', '가요', 'mv'],
  );
  static const study = YoutubeKeyword(
    id: 'yt_study', label: '공부', emoji: '📚',
    patterns: ['공부', '강의', 'study', '교육', '강좌', '수업', 'tutorial', '튜토리얼', '학습'],
  );
  static const tech = YoutubeKeyword(
    id: 'yt_tech', label: 'IT', emoji: '💻',
    patterns: ['개발', '코딩', 'coding', 'programming', 'flutter', 'python', '인공지능', 'tech', 'ai'],
  );
  static const travel = YoutubeKeyword(
    id: 'yt_travel', label: '여행', emoji: '✈️',
    patterns: ['여행', 'travel', 'vlog', '브이로그', '나들이', '해외', '관광', '캠핑'],
  );

  static const List<YoutubeKeyword> all_list = [
    knitting, cooking, game, beauty, fitness, music, study, tech, travel,
  ];

  /// 제목/태그 문자열에서 키워드 자동 감지
  static YoutubeKeyword? detectFromTitle(String title) {
    final lower = title.toLowerCase();
    for (final kw in all_list) {
      if (kw.patterns.any((p) => lower.contains(p.toLowerCase()))) return kw;
    }
    return null;
  }
}

// 일정 유형
class EventType {
  static const String once    = 'once';
  static const String daily   = 'daily';
  static const String weekly  = 'weekly';
  static const String monthly = 'monthly';
  static const String yearly  = 'yearly';
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

  static const personal = EventCategory(id: 'personal', label: '개인',      emoji: '👤', colorValue: 0xFF6C63FF);
  static const birthday = EventCategory(id: 'birthday', label: '생일',      emoji: '🎂', colorValue: 0xFFFF6584);
  static const health   = EventCategory(id: 'health',   label: '건강',      emoji: '💊', colorValue: 0xFF4CAF50);
  static const work     = EventCategory(id: 'work',     label: '일',        emoji: '💼', colorValue: 0xFF2196F3);
  static const hobby    = EventCategory(id: 'hobby',    label: '취미',      emoji: '🎨', colorValue: 0xFFFF9800);
  static const reminder = EventCategory(id: 'reminder', label: '리마인더',  emoji: '🔔', colorValue: 0xFF9C27B0);

  static const List<EventCategory> list = [
    personal, birthday, health, work, hobby, reminder,
  ];

  static EventCategory fromId(String id) =>
      list.firstWhere((c) => c.id == id, orElse: () => personal);
}
