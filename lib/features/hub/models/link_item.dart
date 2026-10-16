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
  };

  LinkItem copyWith({
    String? title,
    String? description,
    String? thumbnailUrl,
    String? category,
    List<String>? tags,
    String? summary,
    String? notes,
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
  );
}
