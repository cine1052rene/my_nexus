import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import '../services/chat_query_parser.dart';
import '../services/chat_query_executor.dart';
import '../../hub/models/link_item.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/services/ai/gemini_service.dart';
import '../../../shared/services/ai/gemini_prompts.dart';
import '../../../shared/services/data/firestore_service.dart';

const freeDailyLimit = 30;

String _todayString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// 오늘 사용한 챗봇 횟수 (날짜 바뀌면 자동 0)
///
/// 로컬 쿼리로 처리된 질문은 여기 포함되지 않는다 — 서버를 거치지
/// 않으므로 한도를 소모하지 않는다.
final chatDailyUsageProvider = StreamProvider<int>((ref) {
  // 계정 전환 시 새 사용자 문서를 구독하도록 watch
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(0);
  return FirebaseFirestore.instance.doc('users/${user.uid}').snapshots().map((
    doc,
  ) {
    final data = doc.data() ?? {};
    final lastDate = data['lastUsageDate'] as String? ?? '';
    if (lastDate != _todayString()) return 0;
    return data['dailyUsage'] as int? ?? 0;
  });
});

// DB허브 연동 여부
final hubInjectedProvider = StateProvider<bool>((ref) => false);

class ChatNotifier extends Notifier<List<ChatMessage>> {
  /// Gemini 형식의 대화 히스토리 (일반 대화용)
  final List<Map<String, dynamic>> _history = [];

  /// 로컬 쿼리용 링크 캐시
  List<LinkItem> _linkCache = const [];
  DateTime? _cachedAt;

  /// 캐시를 만든 사용자 uid. 계정이 바뀌면 이전 사용자의 링크가
  /// TTL 동안 남아 보이므로 반드시 함께 검사한다.
  String? _cachedUid;

  @override
  List<ChatMessage> build() {
    // 계정이 바뀌면(로그아웃 포함) 이전 사용자의 대화 내용과 링크 캐시가
    // 남지 않도록 전부 초기화한다.
    ref.watch(currentUserProvider);
    _history.clear();
    _clearCache();
    return [];
  }

  // 슬라이딩 윈도우: 최대 10턴(20 메시지) 유지 → 토큰 비용 절감
  static const int _maxHistoryTurns = 10;

  /// 링크 캐시 유효 시간
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// 한 번에 조회할 링크 최대 개수
  static const int _linkFetchLimit = 300;

  List<Map<String, dynamic>> get _trimmedHistory {
    if (_history.length <= _maxHistoryTurns * 2) return List.from(_history);
    return List.from(_history.sublist(_history.length - _maxHistoryTurns * 2));
  }

  /// 링크 목록 조회 (캐시 우선)
  Future<List<LinkItem>> _links({bool forceRefresh = false}) async {
    final service = FirestoreService();
    final uid = service.currentUid;

    // 로그아웃 상태면 캐시를 비우고 빈 목록을 돌려준다
    if (uid == null) {
      _clearCache();
      return const [];
    }

    final fresh =
        _cachedUid == uid &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl &&
        _linkCache.isNotEmpty;
    if (!forceRefresh && fresh) return _linkCache;

    _linkCache = await service.getAllLinks(limit: _linkFetchLimit);
    _cachedAt = DateTime.now();
    _cachedUid = uid;
    return _linkCache;
  }

  void _clearCache() {
    _linkCache = const [];
    _cachedAt = null;
    _cachedUid = null;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 사용자 메시지 + 로딩 표시
    state = [
      ...state,
      ChatMessage(
        text: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ),
      ChatMessage(text: '', role: MessageRole.bot, timestamp: DateTime.now()),
    ];

    try {
      final query = ChatQueryParser.parse(text);

      // ── ① 로컬에서 완결 가능한 질문 (목록/개수/최근/검색) ──
      // 네트워크 호출 없음 → 비용 0원, 한도 미차감, 환각 불가
      if (query.isLocal) {
        final result = ChatQueryExecutor.run(query, await _links());
        _replaceLast(
          ChatMessage(
            text: result.text,
            role: MessageRole.bot,
            timestamp: DateTime.now(),
            links: result.links,
            isLocal: true,
          ),
        );
        return;
      }

      // ── ② 요약·설명 요청: 관련 링크만 추려서 LLM에 전달 ──
      // 전체 목록을 통째로 보내지 않으므로 토큰이 극적으로 줄어든다
      if (query.needsLlm) {
        final result = ChatQueryExecutor.run(query, await _links());
        if (result.isEmpty) {
          _replaceLast(
            ChatMessage(
              text: result.text,
              role: MessageRole.bot,
              timestamp: DateTime.now(),
              isLocal: true,
            ),
          );
          return;
        }
        final answer = await GeminiService.chat(
          prompt: GeminiPrompts.hubSummarize(
            question: text,
            linksText: _formatLinks(result.links),
          ),
          history: const [],
        );
        _replaceLast(
          ChatMessage(
            text: answer,
            role: MessageRole.bot,
            timestamp: DateTime.now(),
            links: result.links,
          ),
        );
        return;
      }

      // ── ③ 일반 대화 → 기존 LLM 경로 ──
      final answer = await GeminiService.chat(
        prompt: text,
        history: _trimmedHistory,
      );
      _history.add({
        'role': 'user',
        'parts': [
          {'text': text},
        ],
      });
      _history.add({
        'role': 'model',
        'parts': [
          {'text': answer},
        ],
      });

      _replaceLast(
        ChatMessage(
          text: answer,
          role: MessageRole.bot,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      _replaceLast(
        ChatMessage(
          text: '오류가 발생했어요: ${e.toString()}',
          role: MessageRole.bot,
          timestamp: DateTime.now(),
          isError: true,
        ),
      );
    }
  }

  /// 마지막(로딩 중) 메시지를 실제 응답으로 교체
  void _replaceLast(ChatMessage msg) {
    if (state.isEmpty) return;
    final updated = List<ChatMessage>.from(state);
    updated[updated.length - 1] = msg;
    state = updated;
  }

  /// LLM에 넘길 링크 텍스트 포맷 (요약 요청 시에만 사용)
  static String _formatLinks(List<LinkItem> links) {
    return links
        .map((l) {
          final parts = <String>[
            '[${l.category}] ${l.title}',
            '  URL: ${l.url}',
          ];
          if (l.summary != null && l.summary!.isNotEmpty) {
            parts.add('  요약: ${l.summary}');
          }
          if (l.notes != null && l.notes!.isNotEmpty) {
            parts.add('  메모: ${l.notes}');
          }
          if (l.tags.isNotEmpty) parts.add('  태그: ${l.tags.join(', ')}');
          return parts.join('\n');
        })
        .join('\n\n');
  }

  /// DB허브 연동 — 링크를 미리 불러와 캐시에 채운다.
  ///
  /// 예전에는 링크 전체를 대화 히스토리에 주입했으나, 슬라이딩 윈도우가
  /// 10턴 뒤 그 내용을 잘라내면서 봇이 없는 링크를 지어내는 문제가 있었다.
  /// 이제는 히스토리를 오염시키지 않고 로컬 캐시만 갱신한다.
  Future<void> injectHubContext() async {
    final links = await _links(forceRefresh: true);

    if (links.isEmpty) {
      state = [
        ...state,
        ChatMessage(
          text: 'DB허브에 저장된 링크가 없어요.\n먼저 링크를 저장해보세요!',
          role: MessageRole.bot,
          timestamp: DateTime.now(),
          isLocal: true,
        ),
      ];
      return;
    }

    ref.read(hubInjectedProvider.notifier).state = true;

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
        text:
            '📚 DB허브 ${links.length}개 링크 연동 완료!\n($catSummary)\n\n'
            '이런 걸 물어보세요:\n'
            '• "유튜브 링크 목록 보여줘"\n'
            '• "최근 저장한 링크 알려줘"\n'
            '• "인스타 링크 몇 개야?"\n'
            '• "요리 관련 링크 찾아줘"',
        role: MessageRole.bot,
        timestamp: DateTime.now(),
        isLocal: true,
      ),
    ];
  }

  void reset() {
    _history.clear();
    _clearCache();
    state = [];
    ref.read(hubInjectedProvider.notifier).state = false;
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);

final isChatLoadingProvider = Provider<bool>((ref) {
  final msgs = ref.watch(chatProvider);
  if (msgs.isEmpty) return false;
  final last = msgs.last;
  return last.role == MessageRole.bot && last.text.isEmpty;
});
