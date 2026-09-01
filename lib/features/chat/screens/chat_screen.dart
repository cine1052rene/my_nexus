import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../widgets/chat_link_list.dart';
import '../../settings/providers/settings_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _hubLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _injectHub() async {
    if (_hubLoading) return;
    setState(() => _hubLoading = true);
    try {
      await ref.read(chatProvider.notifier).injectHubContext();
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _hubLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final isLoading = ref.watch(isChatLoadingProvider);
    final hubInjected = ref.watch(hubInjectedProvider);
    final apiKey = ref.watch(geminiApiKeyProvider).valueOrNull ?? '';
    final isUnlimited = apiKey.isNotEmpty;
    final usedToday = ref.watch(chatDailyUsageProvider).valueOrNull ?? 0;
    final remaining = (freeDailyLimit - usedToday).clamp(0, freeDailyLimit);

    // 새 메시지 오면 스크롤
    ref.listen(chatProvider, (prev, next) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤖 AI 챗봇'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isUnlimited
                    ? Colors.green.shade50
                    : remaining <= 5
                    ? Colors.red.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isUnlimited ? '무제한' : '$remaining회 남음',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isUnlimited
                      ? Colors.green.shade700
                      : remaining <= 5
                      ? Colors.red.shade600
                      : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // DB허브 연동 버튼
          if (_hubLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Tooltip(
              message: hubInjected ? 'DB허브 연동됨 (다시 연동)' : 'DB허브 연동',
              child: IconButton(
                icon: Icon(
                  hubInjected
                      ? Icons.library_books
                      : Icons.library_books_outlined,
                  color: hubInjected ? const Color(0xFF6C63FF) : null,
                ),
                onPressed: _injectHub,
              ),
            ),
          // 대화 초기화 버튼
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '대화 초기화',
              onPressed: () => _confirmReset(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 메시지 목록 ─────────────────────────────────────
          Expanded(
            child: messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _MessageBubble(msg: messages[i]),
                  ),
          ),

          // ── 입력창 ──────────────────────────────────────────
          _InputBar(
            controller: _controller,
            isLoading: isLoading,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      // 다이얼로그 자신의 context로 pop해야 한다. 바깥 context를 쓰면
      // 다이얼로그가 아니라 현재 페이지가 pop돼서 화면이 검게 빈다.
      builder: (dialogCtx) => AlertDialog(
        title: const Text('대화 초기화'),
        content: const Text('대화 내용을 모두 지울까요?\nDB허브 연동도 해제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(chatProvider.notifier).reset();
  }
}

// ── 빈 상태 ─────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🤖', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            '무엇이든 물어보세요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '저장한 링크 조회는 기기에서 바로 처리돼요',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text(
            '"유튜브 링크 보여줘" · "인스타 몇 개야?"',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ── 로컬 처리 뱃지 ───────────────────────────────────────────
class _LocalBadge extends StatelessWidget {
  const _LocalBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 38),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.offline_bolt_outlined, size: 11, color: Colors.grey[400]),
          const SizedBox(width: 3),
          Text(
            '기기에서 즉시 처리 (AI 사용 안 함)',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ── 메시지 말풍선 ────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final isLoading = !isUser && msg.text.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bubbleRow(isUser, isLoading),
          if (msg.isLocal && !isLoading) const _LocalBadge(),
          if (msg.hasLinks) ChatLinkList(links: msg.links),
        ],
      ),
    );
  }

  Widget _bubbleRow(bool isUser, bool isLoading) {
    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFF6C63FF),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFF6C63FF)
                  : msg.isError
                  ? Colors.red.shade50
                  : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 40,
                    height: 16,
                    child: _TypingIndicator(),
                  )
                : Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : msg.isError
                          ? Colors.red[700]
                          : Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
          ),
        ),
        if (isUser) const SizedBox(width: 8),
      ],
    );
  }
}

// ── 타이핑 인디케이터 ────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context2, animation) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final opacity = (((_ctrl.value * 3 - i) % 1.0) * 2 - 1).abs().clamp(
              0.2,
              1.0,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity,
                child: const CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF6C63FF),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── 입력창 ───────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEF5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: isLoading ? null : onSend,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
