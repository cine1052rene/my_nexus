import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_message.dart';
import '../../settings/providers/settings_provider.dart';

const _systemPrompt = '당신은 간결하고 친절한 한국어 챗봇입니다.';
const _modelName = 'gemini-2.5-flash';

class ChatNotifier extends Notifier<List<ChatMessage>> {
  ChatSession? _session;
  GenerativeModel? _model;

  @override
  List<ChatMessage> build() => [];

  /// 현재 API 키로 모델/세션 초기화
  bool _initSession(String apiKey) {
    if (apiKey.isEmpty) return false;
    _model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 2048,
      ),
    );
    _session = _model!.startChat();
    return true;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // API 키 확인
    final apiKey = ref.read(geminiApiKeyProvider).valueOrNull ?? '';
    if (!_initSession(apiKey)) {
      state = [
        ...state,
        ChatMessage(
          text: '⚙️ Gemini API 키가 설정되지 않았어요.\n설정 탭에서 키를 입력해주세요.',
          role: MessageRole.bot,
          timestamp: DateTime.now(),
          isError: true,
        ),
      ];
      return;
    }

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
      final response = await _session!.sendMessage(Content.text(text));
      final answer = response.text?.trim() ?? '(응답이 비어있어요)';

      // 로딩 메시지 → 실제 응답으로 교체
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
        text: 'API 오류: ${e.toString()}',
        role: MessageRole.bot,
        timestamp: DateTime.now(),
        isError: true,
      );
      state = updated;
    }
  }

  void reset() {
    if (_model != null) _session = _model!.startChat();
    state = [];
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);

// 전송 중 여부 (마지막 메시지가 bot이고 text가 빈 경우)
final isChatLoadingProvider = Provider<bool>((ref) {
  final msgs = ref.watch(chatProvider);
  if (msgs.isEmpty) return false;
  final last = msgs.last;
  return last.role == MessageRole.bot && last.text.isEmpty;
});
