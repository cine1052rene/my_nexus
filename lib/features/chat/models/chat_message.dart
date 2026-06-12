enum MessageRole { user, bot }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool isError;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.isError = false,
  });

  bool get isUser => role == MessageRole.user;
}
