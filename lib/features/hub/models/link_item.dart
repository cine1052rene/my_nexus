import 'package:cloud_firestore/cloud_firestore.dart';

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

  // YouTube 비디오 ID 추출
  String? get youTubeVideoId {
    if (!isYouTube) return null;
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  // YouTube 썸네일 URL
  String? get youTubeThumbnail {
    final vid = youTubeVideoId;
    if (vid == null) return null;
    return 'https://img.youtube.com/vi/$vid/maxresdefault.jpg';
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
