import '../../../features/email/models/email_message.dart';
import '../ai/gemini_service.dart';
import '../ai/gemini_prompts.dart';

/// Gemini AI 기반 이메일 분류 + 요약 서비스
/// Firebase Functions 프록시를 통해 API 키 없이 동작
class EmailAiService {
  /// 이메일 카테고리 자동 분류
  static Future<EmailCategory> classify({
    required String subject,
    required String snippet,
  }) async {
    try {
      final prompt = GeminiPrompts.emailClassify(
        subject: subject,
        snippet: snippet,
      );

      final text = (await GeminiService.generate(prompt)).trim().toLowerCase();

      if (text.startsWith('work'))         return EmailCategory.work;
      if (text.startsWith('personal'))     return EmailCategory.personal;
      if (text.startsWith('newsletter'))   return EmailCategory.newsletter;
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
    try {
      final prompt = GeminiPrompts.emailSummarize(subject: subject, body: body);
      return await GeminiService.generate(prompt);
    } catch (_) {
      return null;
    }
  }

  /// 여러 이메일 일괄 분류
  static Future<Map<String, EmailCategory>> classifyBatch(
      List<EmailMessage> messages) async {
    final result = <String, EmailCategory>{};
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
