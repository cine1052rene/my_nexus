class MyroomTag {
  final String id;
  final String label;
  final String emoji;

  const MyroomTag({
    required this.id,
    required this.label,
    required this.emoji,
  });

  factory MyroomTag.fromMap(Map<String, dynamic> m) => MyroomTag(
        id: m['id'] as String,
        label: m['label'] as String,
        emoji: (m['emoji'] as String?) ?? '🏷️',
      );

  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'emoji': emoji};

  MyroomTag copyWith({String? label, String? emoji}) => MyroomTag(
        id: id,
        label: label ?? this.label,
        emoji: emoji ?? this.emoji,
      );

  /// 기본 태그 5개 (DB허브 YoutubeKeyword 기반)
  static const List<MyroomTag> defaults = [
    MyroomTag(id: 'cooking', label: '요리', emoji: '🍳'),
    MyroomTag(id: 'fitness', label: '운동', emoji: '💪'),
    MyroomTag(id: 'music',   label: '음악', emoji: '🎵'),
    MyroomTag(id: 'study',   label: '공부', emoji: '📚'),
    MyroomTag(id: 'tech',    label: 'IT',   emoji: '💻'),
  ];
}
