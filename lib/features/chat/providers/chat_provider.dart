import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../../../shared/services/gemini_service.dart';
import '../../../shared/services/firestore_service.dart';

// DB허브 연동 여부
final hubInjectedProvider = StateProvider<bool>((ref) => false);

class ChatNotifier extends Notifier<List<ChatMessage>> {
  /// Gemini 형식의 대화 히스토리 (Firebase Function으로 전송)
  final List<Map<String, dynamic>> _history = [];

  @override
  List<ChatMessage> build() => [];

  // 슬라이딩 윈도우: 최대 10턴(20 메시지) 유지 → 토큰 비용 절감
  static const int _maxHistoryTurns = 10;

  List<Map<String, dynamic>> get _trimmedHistory {
    if (_history.length <= _maxHistoryTurns * 2) return List.from(_history);
    return List.from(_history.sublist(_history.length - _maxHistoryTurns * 2));
  }

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
      // Firebase Function 호출 (슬라이딩 윈도우 히스토리 전달)
      final answer = await GeminiService.chat(
        prompt: text,
        history: _trimmedHistory,
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

  /// DB허브 링크 목록을 AI 컨텍스트로 주입
  Future<void> injectHubContext() async {
    final links = await FirestoreService().getAllLinks();

    if (links.isEmpty) {
      state = [
        ...state,
        ChatMessage(
          text: 'DB허브에 저장된 링크가 없어요.\n먼저 링크를 저장해보세요!',
          role: MessageRole.bot,
          timestamp: DateTime.now(),
        ),
      ];
      return;
    }

    // 링크를 텍스트로 포맷팅 (AI가 이해하기 좋은 구조)
    final linksText = links.map((l) {
      final parts = <String>['[${l.category}] ${l.title}', '  URL: ${l.url}'];
      if (l.notes != null && l.notes!.isNotEmpty) {
        parts.add('  메모: ${l.notes}');
      }
      if (l.tags.isNotEmpty) {
        parts.add('  태그: ${l.tags.join(', ')}');
      }
      return parts.join('\n');
    }).join('\n\n');

    final contextMsg =
        '사용자의 DB허브 저장 링크 목록 (${links.length}개, 최신순):\n\n'
        '$linksText\n\n'
        '이 링크 목록을 기억하고, 사용자가 저장한 콘텐츠에 대해 질문하면 이 정보를 바탕으로 답변해주세요.';

    _history.add({'role': 'user',  'parts': [{'text': contextMsg}]});
    _history.add({'role': 'model', 'parts': [{'text': 'DB허브 링크 ${links.length}개를 확인했습니다. 무엇이 궁금하신가요?'}]});

    ref.read(hubInjectedProvider.notifier).state = true;

    // UI에 연동 완료 안내 메시지
    final cats = <String, int>{};
    for (final l in links) {
      cats[l.category] = (cats[l.category] ?? 0) + 1;
    }
    final catSummary = cats.entries
        .map((e) => '${e.key} ${e.value}개')
        .join(', ');

    state = [
      ...state,
      ChatMessage(
        text: '📚 DB허브 ${links.length}개 링크 연동 완료!\n($catSummary)\n\n이런 걸 물어보세요:\n• "유튜브 링크 목록 보여줘"\n• "최근 저장한 거 요약해줘"\n• "인스타 링크 몇 개야?"\n• "테크 관련 링크 찾아줘"',
        role: MessageRole.bot,
        timestamp: DateTime.now(),
      ),
    ];
  }

  void reset() {
    _history.clear();
    state = [];
    ref.read(hubInjectedProvider.notifier).state = false;
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
