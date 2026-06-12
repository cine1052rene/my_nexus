import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/email_message.dart';
import '../providers/email_provider.dart';

class EmailDetailScreen extends ConsumerStatefulWidget {
  final EmailMessage email;
  const EmailDetailScreen({super.key, required this.email});

  @override
  ConsumerState<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends ConsumerState<EmailDetailScreen> {
  String? _body;
  String? _summary;
  bool _loadingBody = false;
  bool _loadingSummary = false;

  @override
  void initState() {
    super.initState();
    _loadBody();
    // 읽음 처리
    if (!widget.email.isRead) {
      ref.read(emailsProvider.notifier).markRead(widget.email.id);
    }
  }

  Future<void> _loadBody() async {
    setState(() => _loadingBody = true);
    final body = await ref
        .read(emailsProvider.notifier)
        .loadBody(widget.email.id, widget.email.accountId);
    if (mounted) setState(() { _body = body; _loadingBody = false; });
    // 본문 로드 후 자동 요약 시작
    if (body != null) _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (_loadingSummary) return;
    setState(() => _loadingSummary = true);
    final summary =
        await ref.read(emailsProvider.notifier).summarize(widget.email);
    if (mounted) setState(() { _summary = summary; _loadingSummary = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메일'),
        actions: [
          if (widget.email.isStarred)
            const Icon(Icons.star, color: Color(0xFFFFBF00)),
          IconButton(
            icon: const Icon(Icons.reply_outlined),
            onPressed: () => _showReply(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 제목
          Text(
            widget.email.subject,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),

          // 발신자 / 날짜
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF6C63FF),
                child: Text(
                  widget.email.fromName.isNotEmpty
                      ? widget.email.fromName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.email.fromName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(widget.email.from,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Text(
                _formatDate(widget.email.date),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const Divider(height: 24),

          // AI 요약 박스
          _AiSummaryBox(
            summary: _summary ?? widget.email.aiSummary,
            isLoading: _loadingSummary,
            onRefresh: _loadSummary,
          ),
          const SizedBox(height: 16),

          // 본문
          if (_loadingBody)
            const Center(child: CircularProgressIndicator())
          else if (_body != null)
            SelectableText(
              _body!,
              style: const TextStyle(fontSize: 14, height: 1.6),
            )
          else
            Text(
              widget.email.snippet,
              style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _showReply(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplySheet(to: widget.email.from),
    );
  }
}

class _AiSummaryBox extends StatelessWidget {
  final String? summary;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _AiSummaryBox({
    required this.summary,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0CFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨ AI 요약',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6C63FF),
                    fontSize: 13,
                  )),
              const Spacer(),
              if (!isLoading)
                GestureDetector(
                  onTap: onRefresh,
                  child: const Icon(Icons.refresh,
                      size: 16, color: Color(0xFF6C63FF)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (summary != null)
            Text(summary!,
                style: const TextStyle(fontSize: 13, height: 1.5))
          else
            const Text('요약 불러오는 중...',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ReplySheet extends ConsumerStatefulWidget {
  final String to;
  const _ReplySheet({required this.to});

  @override
  ConsumerState<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<_ReplySheet> {
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() { _bodyCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_bodyCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    // Gmail 전송 (다른 계정은 추후 지원)
    // await GmailService.sendEmail(to: widget.to, subject: 'Re: ...', body: _bodyCtrl.text);
    await Future.delayed(const Duration(seconds: 1)); // placeholder
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송됐어요!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('To: ${widget.to}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '답장 내용을 입력하세요...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
            label: const Text('보내기'),
          ),
        ],
      ),
    );
  }
}
