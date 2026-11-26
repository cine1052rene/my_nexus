import 'package:flutter/material.dart';

/// 추천 질문 하나. [placeholder]가 있으면 입력창에 넣은 뒤 그 부분을
/// 선택해 둔다 — 바로 타이핑하면 "ㅇㅇ"이 사용자 단어로 바뀐다.
class ChatSuggestion {
  final String icon;
  final String text;
  final String hint;
  final String? placeholder;
  const ChatSuggestion(this.icon, this.text, this.hint, {this.placeholder});
}

/// 2026-11-27 — 카테고리별 목록·개수는 DB허브 정렬로 충분해서 예시에서 뺐다.
/// 대신 주 1회 돌아보기(관심 분포), 주제 정리(AI), 기간 조회를 보여준다.
List<ChatSuggestion> buildChatSuggestions(DateTime now) {
  // 날짜 예시는 늘 지난달로 — 하드코딩하면 해가 바뀌어 엉뚱한 날짜가 된다
  final prevMonth = DateTime(now.year, now.month - 1, 1).month;
  return [
    const ChatSuggestion(
        '📊', '이번 주 관심 분포 정리해줘', '주 1회 · 주제·출처·키워드 분포 (기기 처리)'),
    const ChatSuggestion(
        '✨', 'ㅇㅇ 관련 링크 정리해줘', 'ㅇㅇ에 주제를 넣어요 · AI가 내용을 묶어 정리',
        placeholder: 'ㅇㅇ'),
    const ChatSuggestion(
        '📅', '지난주에 유튜브에서 저장한 링크 보여줘', '기간 + 출처로 찾기 (기기 처리)'),
    ChatSuggestion('🗓️', '$prevMonth월 1일부터 15일까지 저장한 링크 보여줘',
        '날짜 범위로 찾기 (기기 처리)'),
  ];
}

/// 질문을 바로 보내지 않고 입력창에 채운다 — 사용자가 고친 뒤 전송.
void fillChatInput(
  TextEditingController controller,
  FocusNode focus,
  ChatSuggestion s,
) {
  controller.text = s.text;
  final idx = s.placeholder == null ? -1 : s.text.indexOf(s.placeholder!);
  controller.selection = idx < 0
      ? TextSelection.collapsed(offset: s.text.length)
      : TextSelection(baseOffset: idx, extentOffset: idx + s.placeholder!.length);
  focus.requestFocus();
}

/// 대화가 비었을 때 보여주는 안내 + 추천 질문
class ChatEmptyState extends StatelessWidget {
  final ValueChanged<ChatSuggestion> onPick;
  const ChatEmptyState({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      children: [
        const Center(child: Text('🤖', style: TextStyle(fontSize: 52))),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            '무엇이든 물어보세요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '누르면 입력창에 들어가요 · 고쳐서 보내세요',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 20),
        for (final s in buildChatSuggestions(DateTime.now()))
          _SuggestionTile(s: s, onTap: onPick),
        const SizedBox(height: 8),
        Text(
          '"유튜브 관련"은 유튜브 운영·제작에 관한 링크를, '
          '"유튜브에서 저장한"은 유튜브에서 모은 링크를 찾아요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, height: 1.5, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final ChatSuggestion s;
  final ValueChanged<ChatSuggestion> onTap;
  const _SuggestionTile({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: dark ? const Color(0xFF26263A) : const Color(0xFFF4F3FF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(s.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.text,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.hint,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
