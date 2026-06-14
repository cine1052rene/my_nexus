import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_clip.dart';
import '../providers/myroom_provider.dart';

class AddClipSheet extends ConsumerStatefulWidget {
  final VideoClip? editClip;
  const AddClipSheet({super.key, this.editClip});

  @override
  ConsumerState<AddClipSheet> createState() => _AddClipSheetState();
}

class _AddClipSheetState extends ConsumerState<AddClipSheet> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  ClipPlatform _detected = ClipPlatform.other;
  bool _loading = false;

  bool get _isEdit => widget.editClip != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _urlCtrl.text = widget.editClip!.url;
      _titleCtrl.text = widget.editClip!.title;
      _noteCtrl.text = widget.editClip!.note ?? '';
      _tagsCtrl.text = widget.editClip!.tags.join(', ');
      _detected = widget.editClip!.platform;
    }
    _urlCtrl.addListener(_detectPlatform);
  }

  @override
  void dispose() {
    _urlCtrl.removeListener(_detectPlatform);
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _detectPlatform() {
    final p = ClipPlatform.detect(_urlCtrl.text.trim());
    if (p != _detected) setState(() => _detected = p);
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlCtrl.text = data!.text!;
    }
  }

  List<String> get _tags => _tagsCtrl.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final notifier = ref.read(myroomNotifierProvider.notifier);
    String? err;

    if (_isEdit) {
      final updated = widget.editClip!.copyWith(
        title: _titleCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        tags: _tags,
      );
      err = await notifier.updateClip(updated);
    } else {
      err = await notifier.addClip(
        url: _urlCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        tags: _tags,
      );
    }

    setState(() => _loading = false);
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $err'), backgroundColor: Colors.red),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEdit ? '영상 수정' : '🎬 영상 큐레이션 추가',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),

              // URL (편집 시 비활성)
              TextFormField(
                controller: _urlCtrl,
                readOnly: _isEdit,
                decoration: InputDecoration(
                  labelText: 'URL *',
                  hintText: 'https://youtube.com/...',
                  suffixIcon: _isEdit
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.content_paste, size: 18),
                          onPressed: _pasteUrl,
                          tooltip: '클립보드에서 붙여넣기',
                        ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'URL을 입력해주세요' : null,
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),

              // 플랫폼 감지 표시
              if (_urlCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${_detected.emoji} ${_detected.label} 감지됨',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // 제목
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '제목 *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '제목을 입력해주세요' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // 메모 (선택)
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  hintText: '짧은 메모...',
                ),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // 태그 (선택)
              TextFormField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: '태그 (선택, 쉼표 구분)',
                  hintText: '먹방, 레시피, 일상',
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEdit ? '수정 완료' : '큐레이션에 추가'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
