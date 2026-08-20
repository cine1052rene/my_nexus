import '../../hub/models/link_item.dart';

enum MessageRole { user, bot }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool isError;

  /// 로컬 쿼리 결과로 첨부된 링크들 (있으면 말풍선 아래 카드로 렌더링)
  final List<LinkItem> links;

  /// AI 호출 없이 기기에서 처리된 응답인지 (뱃지 표시용)
  final bool isLocal;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.isError = false,
    this.links = const [],
    this.isLocal = false,
  });

  bool get isUser => role == MessageRole.user;
  bool get hasLinks => links.isNotEmpty;
}
