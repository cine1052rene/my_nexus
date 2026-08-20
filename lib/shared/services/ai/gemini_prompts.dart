/// Gemini에게 보내는 프롬프트(지시문) 템플릿 모음.
///
/// 화면(위젯/프로바이더)마다 흩어져 있던 프롬프트 문자열을 이 파일 하나로
/// 모아둠 — 어떤 요청이 AI에게 어떤 지시를 내리는지 한눈에 파악하고,
/// 문구 수정(예: 영문화)이 필요할 때 이 파일만 보면 되도록 정리한 것.
/// 로직/동작은 기존과 동일하며 프롬프트 "내용"만 이곳으로 이동함.
library;

class GeminiPrompts {
  GeminiPrompts._();

  /// DB허브 링크 큐레이션(지식·학습 요약) 프롬프트
  /// [curation_sheet.dart]에서 사용
  static String curation({
    required String title,
    required String url,
    required String description,
  }) =>
      '''
아래 콘텐츠를 지식·학습 목적으로 한국어로 요약해주세요.

제목: $title
URL: $url
${description.isNotEmpty ? '설명:\n$description' : ''}

다음 형식으로 작성해주세요 (마크다운):

## 📌 핵심 요약
• 핵심 내용 1
• 핵심 내용 2
• 핵심 내용 3
(3~5개, 각 1~2문장)

## 💡 주요 키워드
#키워드1 #키워드2 #키워드3

## 🔗 원본
$url
''';

  /// 이메일 카테고리 자동 분류 프롬프트
  /// [email_ai_service.dart]에서 사용
  static String emailClassify({
    required String subject,
    required String snippet,
  }) =>
      '''
다음 이메일을 딱 한 단어로 분류하세요. (work / personal / newsletter / notification / other)
- work: 업무, 미팅, 계약, 청구서, 프로젝트
- personal: 지인, 가족, 친구, 개인 연락
- newsletter: 뉴스레터, 마케팅, 홍보, 구독
- notification: 앱/서비스 알림, 인증코드, 자동발송
- other: 위에 해당 없음

제목: $subject
내용: $snippet

분류(한 단어만):''';

  /// 이메일 본문 2~3줄 요약 프롬프트
  /// [email_ai_service.dart]에서 사용
  static String emailSummarize({
    required String subject,
    required String body,
  }) {
    final truncated = body.length > 3000
        ? '${body.substring(0, 3000)}...'
        : body;
    return '''
이메일을 2~3줄로 요약하세요. 핵심 내용과 요청/액션 아이템 위주로.

제목: $subject
내용:
$truncated

요약:''';
  }

  /// DB허브 링크 요약·설명 요청 프롬프트
  /// [chat_provider.dart]의 sendMessage()에서 summarize 의도일 때 사용
  ///
  /// 예전 hubContextInjection()은 저장된 링크 **전체**를 대화 히스토리에
  /// 주입해서 매 메시지마다 재전송됐고(토큰 낭비), 슬라이딩 윈도우가
  /// 이를 잘라내면 봇이 없는 링크를 지어냈다. 이제는 로컬 쿼리로 추려낸
  /// 소수의 링크만 그때그때 담아 보낸다.
  static String hubSummarize({
    required String question,
    required String linksText,
  }) =>
      '''
아래는 사용자가 저장해 둔 링크 목록입니다.

$linksText

위 목록만 근거로 사용자의 요청에 답해주세요.
- 목록에 없는 링크나 내용을 지어내지 마세요.
- 정보가 부족하면 부족하다고 솔직히 말해주세요.
- 한국어로 간결하게 작성해주세요.

사용자 요청: $question''';
}
