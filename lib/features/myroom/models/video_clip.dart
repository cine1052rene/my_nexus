import 'package:cloud_firestore/cloud_firestore.dart';

enum ClipPlatform {
  youtube('YouTube', '▶️', 0xFFFF0000),
  shorts('Shorts', '🩳', 0xFFFF0000),
  tiktok('TikTok', '🎵', 0xFF010101),
  reels('Reels', '📸', 0xFFE1306C),
  clip('클립', '📎', 0xFF9146FF),
  other('기타', '🔗', 0xFF78909C);

  const ClipPlatform(this.label, this.emoji, this.colorValue);
  final String label;
  final String emoji;
  final int colorValue;

  static ClipPlatform detect(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube.com/shorts')) return ClipPlatform.shorts;
    if (u.contains('youtube.com') || u.contains('youtu.be')) return ClipPlatform.youtube;
    if (u.contains('tiktok.com')) return ClipPlatform.tiktok;
    if (u.contains('instagram.com/reel')) return ClipPlatform.reels;
    if (u.contains('twitch.tv/clip') || u.contains('clips.twitch.tv')) return ClipPlatform.clip;
    return ClipPlatform.other;
  }
}

class VideoClip {
  final String id;
  final String url;
  final String title;
  final ClipPlatform platform;
  final String? thumbnailUrl;
  final String? note;
  final List<String> tags;
  final DateTime createdAt;

  const VideoClip({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    this.thumbnailUrl,
    this.note,
    this.tags = const [],
    required this.createdAt,
  });

  // YouTube 비디오 ID 추출
  String? get youtubeVideoId {
    if (platform != ClipPlatform.youtube && platform != ClipPlatform.shorts) return null;
    final re = RegExp(
      r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|shorts)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    );
    return re.firstMatch(url)?.group(1);
  }

  // 표시할 썸네일 URL
  String get thumbUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl!;
    final vid = youtubeVideoId;
    if (vid != null) return 'https://img.youtube.com/vi/$vid/mqdefault.jpg';
    return '';
  }

  factory VideoClip.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VideoClip(
      id: doc.id,
      url: d['url'] ?? '',
      title: d['title'] ?? '',
      platform: ClipPlatform.values.firstWhere(
        (p) => p.name == (d['platform'] ?? 'other'),
        orElse: () => ClipPlatform.other,
      ),
      thumbnailUrl: d['thumbnailUrl'],
      note: d['note'],
      tags: List<String>.from(d['tags'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'url': url,
    'title': title,
    'platform': platform.name,
    'thumbnailUrl': thumbnailUrl,
    'note': note,
    'tags': tags,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  VideoClip copyWith({
    String? title,
    String? note,
    List<String>? tags,
    String? thumbnailUrl,
  }) =>
      VideoClip(
        id: id,
        url: url,
        title: title ?? this.title,
        platform: platform,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        createdAt: createdAt,
      );
}
