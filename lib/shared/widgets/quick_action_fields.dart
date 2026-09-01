import 'package:flutter/material.dart';

/// 오른쪽 끝에 **지우기(X)** 버튼이 붙는 한 줄 입력칸.
///
/// 자동 수집이 실패해 제목이 엉뚱하게 채워진 경우, 기존 글자를 일일이
/// 지우는 게 번거로워서 넣었다.
///
/// - 글자가 있을 때만 X를 보여준다. 빈 칸에 떠 있으면 지저분하고
///   사용자가 오류 표시로 오해한다.
/// - 지운 뒤 **포커스를 요청**한다. `controller.clear()` 만 하면 텍스트만
///   비고 커서가 안 들어와서, 결국 칸을 다시 눌러야 해 불편이 그대로다.
/// - 갱신은 `ValueListenableBuilder` 로 이 입력칸만 다시 그린다.
///   `setState` 를 쓰면 글자 하나 칠 때마다 시트 전체가 리빌드된다.
class ClearableTextField extends StatefulWidget {
  const ClearableTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Form 안에서 쓸 때의 검증기. 마이룸 클립 시트가 제목 필수 검증을 쓴다.
  final String? Function(String?)? validator;

  @override
  State<ClearableTextField> createState() => _ClearableTextFieldState();
}

class _ClearableTextFieldState extends State<ClearableTextField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      // TextFormField를 쓰는 이유: Form 검증(제목 필수)이 걸린 화면에서도
      // 그대로 쓸 수 있어야 한다. 기능은 TextField와 동일하다.
      builder: (context, value, _) => TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.cancel, size: 20),
                  color: Colors.grey,
                  tooltip: '지우기',
                  onPressed: () {
                    widget.controller.clear();
                    _focus.requestFocus();
                  },
                ),
        ),
      ),
    );
  }
}

/// 오른쪽 끝에 **`#` 삽입** 버튼이 붙는 태그 입력칸.
///
/// 태그를 칠 때마다 구분자를 직접 넣는 게 번거로워서 넣었다.
/// 버튼을 누르면 커서 위치에 `#` 이 들어가고 바로 이어서 타이핑할 수 있다.
///
/// 저장 시에는 `parseTags()` 가 `#` 을 떼어내므로 값에는 남지 않는다.
/// (`#`을 값에 포함하면 화면에 `##태그` 로 나오고 기존 태그와 갈라진다)
class HashtagTextField extends StatefulWidget {
  const HashtagTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;

  @override
  State<HashtagTextField> createState() => _HashtagTextFieldState();
}

class _HashtagTextFieldState extends State<HashtagTextField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _insertHash() {
    final c = widget.controller;
    final text = c.text;
    final sel = c.selection;

    // 아직 포커스가 없으면 selection이 무효(-1)다. 그 경우 맨 뒤에 붙인다.
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;

    // 앞 글자가 공백/쉼표가 아니면 공백을 하나 끼워 이전 태그와 분리한다.
    // ('뜨개질' 뒤에서 누르면 '뜨개질 #' 이 되도록)
    final prev = start > 0 ? text[start - 1] : ' ';
    final insert = (prev == ' ' || prev == ',') ? '#' : ' #';

    final newText = text.replaceRange(start, end, insert);
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        suffixIcon: IconButton(
          icon: const Text('#',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          color: Theme.of(context).colorScheme.primary,
          tooltip: '태그 구분자(#) 입력',
          onPressed: _insertHash,
        ),
      ),
    );
  }
}
