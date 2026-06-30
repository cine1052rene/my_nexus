import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/myroom_tag.dart';
import '../providers/myroom_provider.dart';

class TagManagerSheet extends ConsumerStatefulWidget {
  const TagManagerSheet({super.key});

  @override
  ConsumerState<TagManagerSheet> createState() => _TagManagerSheetState();
}

class _TagManagerSheetState extends ConsumerState<TagManagerSheet> {
  late List<MyroomTag> _tags;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(myroomTagsProvider);

    return tagsAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(
        height: 200,
        child: Center(child: Text('오류: $e')),
      ),
      data: (tags) {
        if (!_loaded) {
          _tags = List.from(tags);
          _loaded = true;
        }
        return _buildSheet(context);
      },
    );
  }

  Widget _buildSheet(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                const Text(
                  '🏷️ 태그 관리',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('추가'),
                ),
              ],
            ),
          ),
          const Divider(),
          // 태그 목록
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tags.length,
            itemBuilder: (_, i) {
              final tag = _tags[i];
              return ListTile(
                leading: Text(tag.emoji,
                    style: const TextStyle(fontSize: 22)),
                title: Text(
                  tag.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showEditDialog(i, tag),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: _tags.length > 1
                            ? Colors.red[300]
                            : Colors.grey[300],
                      ),
                      onPressed: _tags.length > 1
                          ? () => _deleteTag(i)
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final result = await _showTagDialog();
    if (result == null) return;
    setState(() {
      _tags = [
        ..._tags,
        MyroomTag(
          id: '${result.$1}_${DateTime.now().millisecondsSinceEpoch}',
          label: result.$1,
          emoji: result.$2,
        ),
      ];
    });
    await _save();
  }

  Future<void> _showEditDialog(int index, MyroomTag tag) async {
    final result = await _showTagDialog(
      initialLabel: tag.label,
      initialEmoji: tag.emoji,
    );
    if (result == null) return;
    setState(() {
      _tags = [..._tags];
      _tags[index] = tag.copyWith(label: result.$1, emoji: result.$2);
    });
    await _save();
  }

  void _deleteTag(int index) {
    setState(() {
      _tags = [..._tags]..removeAt(index);
    });
    // 삭제된 태그가 선택돼 있으면 해제
    final deleted = ref.read(myroomSelectedTagProvider);
    if (deleted != null && !_tags.any((t) => t.label == deleted)) {
      ref.read(myroomSelectedTagProvider.notifier).state = null;
    }
    _save();
  }

  Future<void> _save() async {
    await ref.read(myroomNotifierProvider.notifier).saveTags(_tags);
  }

  /// 태그 추가/편집 다이얼로그 → (label, emoji) 반환
  Future<(String, String)?> _showTagDialog({
    String? initialLabel,
    String? initialEmoji,
  }) async {
    final labelCtrl = TextEditingController(text: initialLabel ?? '');
    final emojiCtrl = TextEditingController(text: initialEmoji ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(initialLabel == null ? '태그 추가' : '태그 수정'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emojiCtrl,
                decoration: const InputDecoration(
                  labelText: '이모지',
                  hintText: '🍳',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '이모지를 입력하세요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: '태그명',
                  hintText: '예: 요리, 운동, 영화...',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '태그명을 입력하세요' : null,
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogCtx,
                        (labelCtrl.text.trim(), emojiCtrl.text.trim()));
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogCtx,
                    (labelCtrl.text.trim(), emojiCtrl.text.trim()));
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    labelCtrl.dispose();
    emojiCtrl.dispose();
    return result;
  }
}
