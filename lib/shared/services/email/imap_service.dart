import 'package:flutter/foundation.dart';
import 'package:enough_mail/enough_mail.dart';
import '../../../features/email/models/email_message.dart';
import '../../../features/email/models/email_account.dart';

/// IMAP 기반 외부 메일 서비스 (모바일 전용 — 웹에서는 비활성화)
class ImapService {
  final EmailAccount account;
  ImapClient? _client;

  ImapService(this.account);

  Future<bool> connect() async {
    if (kIsWeb) return false;
    try {
      _client = ImapClient(isLogEnabled: false);
      await _client!.connectToServer(
        account.imapHost ?? '',
        account.imapPort,
        isSecure: account.imapSsl,
      );
      await _client!.login(account.email, account.password ?? '');
      return true;
    } catch (_) {
      _client = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _client?.logout();
    } catch (_) {}
    _client = null;
  }

  Future<List<EmailMessage>> fetchInbox({int count = 30}) async {
    if (kIsWeb || _client == null) return [];
    try {
      await _client!.selectInbox();
      // 최근 n개 메시지의 헤더만 가져옴
      final fetchResult = await _client!.fetchRecentMessages(
        messageCount: count,
        criteria: 'BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE FLAGS)]',
      );
      return fetchResult.messages
          .map((m) => _convert(m))
          .whereType<EmailMessage>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> fetchBody(String messageId) async {
    if (kIsWeb || _client == null) return null;
    try {
      final seqId = int.tryParse(messageId.replaceFirst('imap_', ''));
      if (seqId == null) return null;
      await _client!.selectInbox();
      final result = await _client!.fetchMessage(
        seqId,
        'BODY[]',
      );
      return result.messages.firstOrNull?.decodeTextPlainPart();
    } catch (_) {
      return null;
    }
  }

  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (kIsWeb) return false;
    try {
      final smtpClient = SmtpClient(account.email, isLogEnabled: false);
      await smtpClient.connectToServer(
        account.smtpHost ?? '',
        account.smtpPort,
        isSecure: account.smtpSsl,
      );
      await smtpClient.ehlo();
      if (!account.smtpSsl) await smtpClient.startTls();
      await smtpClient.authenticate(
        account.email,
        account.password ?? '',
        AuthMechanism.plain,
      );

      final builder = MessageBuilder()
        ..from = [MailAddress(null, account.email)]
        ..to = [MailAddress(null, to)]
        ..subject = subject;
      builder.addTextPlain(body);

      await smtpClient.sendMessage(builder.buildMimeMessage());
      return true;
    } catch (_) {
      return false;
    }
  }

  EmailMessage? _convert(MimeMessage m) {
    try {
      final from = m.from?.firstOrNull;
      final subject = m.decodeSubject() ?? '(제목 없음)';
      final date = m.decodeDate() ?? DateTime.now();
      final isSeen = m.hasFlag(MessageFlags.seen);
      final isFlagged = m.hasFlag(MessageFlags.flagged);

      return EmailMessage(
        id: 'imap_${m.sequenceId ?? 0}',
        accountId: account.id,
        from: from?.email ?? '',
        fromName: from?.personalName ?? from?.email ?? '',
        subject: subject,
        snippet: '',
        date: date,
        isRead: isSeen,
        isStarred: isFlagged,
        hasAttachment: m.hasAttachments(),
      );
    } catch (_) {
      return null;
    }
  }
}
