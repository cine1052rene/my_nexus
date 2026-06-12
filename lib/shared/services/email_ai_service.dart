import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/email/models/email_message.dart';

/// Gemini AI 기반 이메일 분류 + 요약 서비스
class EmailAiService {
  static GenerativeModel? _model;

  static void init(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 512,
      ),
    );
  }

  /// 이메일 카테고리 자동 분류
  static Future<EmailCategory> classify({
    required String subject,
    required String snippet,
  }) async {
    if (_model == null) return EmailCategory.other;
    try {
      final prompt = '''
다음 이메일을 딱 한 단어로 분류하세요. (work / personal / newsletter / notification / other)
- work: 업무, 미팅, 계약, 청구서, 프로젝트
- personal: 지인, 가족, 친구, 개인 연락
- newsletter: 뉴스레터, 마케팅, 홍보, 구독
- notification: 앱/서비스 알림, 인증코드, 자동발송
- other: 위에 해당 없음

제목: $subject
내용: $snippet

분류(한 단어만):''';

      final res =
          await _model!.generateContent([Content.text(prompt)]);
      final text = (res.text ?? '').trim().toLowerCase();

      if (text.startsWith('work')) return EmailCategory.work;
      if (text.startsWith('personal')) return EmailCategory.personal;
      if (text.startsWith('newsletter')) return EmailCategory.newsletter;
      if (text.startsWith('notification')) return EmailCategory.notification;
      return EmailCategory.other;
    } catch (_) {
      return EmailCategory.other;
    }
  }

  /// 이메일 내용 요약 (2-3줄)
  static Future<String?> summarize({
    required String subject,
    required String body,
  }) async {
    if (_model == null) return null;
    try {
      final truncated =
          body.length > 3000 ? '${body.substring(0, 3000)}...' : body;
      final prompt = '''
이메일을 2~3줄로 요약하세요. 핵심 내용과 요청/액션 아이템 위주로.

제목: $subject
내용:
$truncated

요약:''';

      final res = await _model!.generateContent([Content.text(prompt)]);
      return res.text?.trim();
    } catch (_) {
      return null;
    }
  }

  /// 여러 이메일 일괄 분류 (성능 최적화)
  static Future<Map<String, EmailCategory>> classifyBatch(
      List<EmailMessage> messages) async {
    final result = <String, EmailCategory>{};
    // 이미 분류된 것 제외, 5개씩 순차 처리 (rate limit 방지)
    final unclassified = messages
        .where((m) => m.category == EmailCategory.other)
        .take(10)
        .toList();

    for (final msg in unclassified) {
      result[msg.id] = await classify(
        subject: msg.subject,
        snippet: msg.snippet,
      );
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return result;
  }
}
