import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../../../shared/services/gemini_service.dart';

class ChatNotifier extends Notifier<List<ChatMessage>> {
  /// Gemini 형식의 대화 히스토리 (Firebase Function으로 전송)
  final List<Map<String, dynamic>> _history = [];

  @override
  List<ChatMessage> build() => [];

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 사용자 메시지 추가
    state = [
      ...state,
      ChatMessage(text: text, role: MessageRole.user, timestamp: DateTime.now()),
    ];

    // 로딩 표시 (빈 bot 메시지)
    state = [
      ...state,
      ChatMessage(text: '', role: MessageRole.bot, timestamp: DateTime.now()),
    ];

    try {
      // Firebase Function 호출 (API 키 불필요)
      final answer = await GeminiService.chat(
        prompt: text,
        history: List.from(_history),
      );

      // 히스토리 업데이트
      _history.add({'role': 'user',  'parts': [{'text': text}]});
      _history.add({'role': 'model', 'parts': [{'text': answer}]});

      // 로딩 → 응답으로 교체
      final updated = List<ChatMessage>.from(state);
      updated[updated.length - 1] = ChatMessage(
        text: answer,
        role: MessageRole.bot,
        timestamp: DateTime.now(),
      );
      state = updated;
    } catch (e) {
      final updated = List<ChatMessage>.from(state);
      updated[updated.length - 1] = ChatMessage(
        text: '오류가 발생했어요: ${e.toString()}',
        role: MessageRole.bot,
        timestamp: DateTime.now(),
        isError: true,
      );
      state = updated;
    }
  }

  void reset() {
    _history.clear();
    state = [];
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);

final isChatLoadingProvider = Provider<bool>((ref) {
  final msgs = ref.watch(chatProvider);
  if (msgs.isEmpty) return false;
  final last = msgs.last;
  return last.role == MessageRole.bot && last.text.isEmpty;
});
