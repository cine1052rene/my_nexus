import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/utils/youtube_utils.dart';

class LinkItem {
  final String id;
  final String url;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String category;   // HubCategory.id
  final List<String> tags;
  final String? summary;   // 요약 메모
  final String? notes;     // 주석/개인 메모
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// 중복 판별 키 ([canonicalLinkKey]). 1.1.0 이전 항목은 백필로 채움
  final String? urlKey;

  /// 소화 상태 — [LinkStatus]. null = 1.1.0 이전에 저장된 항목(legacy)
  final String? status;

  /// 저장한 이유 — [LinkIntent]. null = 고르지 않음
  final String? intent;

  const LinkItem({
    required this.id,
    required this.url,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.category,
    this.tags = const [],
    this.summary,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.urlKey,
    this.status,
    this.intent,
  });

  // YouTube 여부 판단
  bool get isYouTube =>
      url.contains('youtube.com') || url.contains('youtu.be');

  // TikTok 여부 판단
  bool get isTikTok => url.contains('tiktok.com');

  // YouTube 비디오 ID 추출 (쇼츠 포함 — youtube_utils 단일 규칙 사용)
  String? get youTubeVideoId => isYouTube ? extractYoutubeId(url) : null;

  // YouTube 썸네일 URL — 저장된 값이 없어도 ID만으로 즉시 그린다.
  // 그래서 ID 규칙만 고치면 기존에 썸네일 없이 저장된 쇼츠도 바로 살아난다.
  String? get youTubeThumbnail {
    final vid = youTubeVideoId;
    return vid == null ? null : youtubeThumbnail(vid);
  }

  String get displayThumbnail => youTubeThumbnail ?? thumbnailUrl ?? '';

  factory LinkItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LinkItem(
      id: doc.id,
      url: d['url'] ?? '',
      title: d['title'] ?? '',
      description: d['description'],
      thumbnailUrl: d['thumbnailUrl'],
      category: d['category'] ?? 'etc',
      tags: List<String>.from(d['tags'] ?? []),
      summary: d['summary'],
      notes: d['notes'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      urlKey: d['urlKey'] as String?,
      status: d['status'] as String?,
      intent: d['intent'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'url': url,
    'title': title,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'category': category,
    'tags': tags,
    'summary': summary,
    'notes': notes,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    if (urlKey != null) 'urlKey': urlKey,
    if (status != null) 'status': status,
    if (intent != null) 'intent': intent,
  };

  LinkItem copyWith({
    String? title,
    String? description,
    String? thumbnailUrl,
    String? category,
    List<String>? tags,
    String? summary,
    String? notes,
    String? status,
    String? intent,
  }) => LinkItem(
    id: id,
    url: url,
    title: title ?? this.title,
    description: description ?? this.description,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    summary: summary ?? this.summary,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    urlKey: urlKey,
    status: status ?? this.status,
    intent: intent ?? this.intent,
  );
}

/// 링크 소화 상태 (1.1.0). 저장 → 안 봄 → 봤음 → 적용함 / 버림
class LinkStatus {
  LinkStatus._();
  static const unseen = 'unseen';
  static const seen = 'seen';
  static const applied = 'applied';
  static const dropped = 'dropped';

  static const labels = {
    unseen: '안 봄',
    seen: '봤음',
    applied: '적용함',
    dropped: '버림',
  };
}

/// 저장한 이유 (1.1.0) — 나중에 묶기·정리의 단서가 된다
class LinkIntent {
  LinkIntent._();
  static const labels = {
    'ref': '📌 참고',
    'try': '🛠️ 해볼 것',
    'buy': '🛒 살 것',
    'study': '📚 공부',
  };
}
