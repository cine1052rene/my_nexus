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
  }) => '''
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
  }) => '''
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
    final truncated = body.length > 3000 ? '${body.substring(0, 3000)}...' : body;
    return '''
이메일을 2~3줄로 요약하세요. 핵심 내용과 요청/액션 아이템 위주로.

제목: $subject
내용:
$truncated

요약:''';
  }

  /// 챗봇에 DB허브 링크 목록을 컨텍스트로 주입할 때 보내는 메시지
  /// [chat_provider.dart]의 injectHubContext()에서 사용
  static String hubContextInjection(String linksText, int count) => '''
사용자의 DB허브 저장 링크 목록 ($count개, 최신순):

$linksText

이 링크 목록을 기억하고, 사용자가 저장한 콘텐츠에 대해 질문하면 이 정보를 바탕으로 답변해주세요.''';
}
