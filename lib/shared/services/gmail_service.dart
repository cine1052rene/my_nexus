import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/email/models/email_message.dart';
import '../../features/email/models/email_account.dart';
import 'google_auth_service.dart';

class GmailService {
  static const _base = 'https://www.googleapis.com/gmail/v1/users/me';

  /// Gmail OAuth 로그인 → EmailAccount 반환
  static Future<EmailAccount?> signIn() async {
    try {
      final token = await getGoogleAccessToken(promptSignIn: true);
      if (token == null) return null;
      final user = appGoogleSignIn.currentUser!;
      return EmailAccount(
        id: 'gmail_${user.email}',
        email: user.email,
        displayName: user.displayName ?? user.email,
        type: EmailAccountType.gmail,
      );
    } catch (_) {
      return null;
    }
  }

  /// 받은 편지함 목록 (최근 [maxResults]개)
  static Future<List<EmailMessage>> fetchInbox({int maxResults = 30}) async {
    final token = await getGoogleAccessToken();
    if (token == null) return [];

    try {
      final listUri = Uri.https(
        'www.googleapis.com',
        '/gmail/v1/users/me/messages',
        {'labelIds': 'INBOX', 'maxResults': '$maxResults'},
      );
      final listRes =
          await http.get(listUri, headers: {'Authorization': 'Bearer $token'});
      if (listRes.statusCode != 200) return [];

      final ids = ((jsonDecode(listRes.body)['messages'] as List<dynamic>?) ?? [])
          .map((m) => m['id'] as String)
          .toList();

      // 병렬로 각 메시지 fetch
      final futures = ids.map((id) => _fetchMessage(id, token));
      final results = await Future.wait(futures);
      return results.whereType<EmailMessage>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<EmailMessage?> _fetchMessage(String id, String token) async {
    try {
      final uri = Uri.parse(
        '$_base/messages/$id?format=metadata'
        '&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date',
      );
      final res =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) return null;
      return _parseMessage(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 메일 본문 가져오기
  static Future<String?> fetchBody(String messageId) async {
    final token = await getGoogleAccessToken();
    if (token == null) return null;
    try {
      final uri = Uri.parse('$_base/messages/$messageId?format=full');
      final res =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) return null;
      return _extractBody(
          jsonDecode(res.body)['payload'] as Map<String, dynamic>?);
    } catch (_) {
      return null;
    }
  }

  /// 읽음 처리
  static Future<bool> markAsRead(String messageId) async {
    final token = await getGoogleAccessToken();
    if (token == null) return false;
    try {
      final uri = Uri.parse('$_base/messages/$messageId/modify');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'removeLabelIds': ['UNREAD'],
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 메일 전송 (base64url 인코딩)
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    final token = await getGoogleAccessToken();
    if (token == null) return false;
    try {
      final user = appGoogleSignIn.currentUser;
      if (user == null) return false;

      final raw = 'From: ${user.email}\r\nTo: $to\r\nSubject: $subject\r\n'
          'Content-Type: text/plain; charset=utf-8\r\n\r\n$body';
      final encoded = base64Url
          .encode(utf8.encode(raw))
          .replaceAll('+', '-')
          .replaceAll('/', '_');

      final uri = Uri.parse('$_base/messages/send');
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'raw': encoded}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── 파싱 헬퍼 ──────────────────────────────────────────────────

  static EmailMessage? _parseMessage(Map<String, dynamic> data) {
    try {
      final headers =
          (data['payload']?['headers'] as List<dynamic>?) ?? [];
      String from = '', fromName = '', subject = '(제목 없음)';
      DateTime date = DateTime.now();

      for (final h in headers) {
        final name = (h['name'] as String).toLowerCase();
        final value = h['value'] as String;
        switch (name) {
          case 'from':
            final m = RegExp(r'^"?(.+?)"?\s*<(.+)>$').firstMatch(value);
            if (m != null) {
              fromName = m.group(1)!.trim();
              from = m.group(2)!;
            } else {
              from = fromName = value;
            }
          case 'subject':
            subject = value.isEmpty ? '(제목 없음)' : value;
          case 'date':
            try {
              date = DateTime.parse(value);
            } catch (_) {}
        }
      }

      final labelIds =
          (data['labelIds'] as List<dynamic>?)?.cast<String>() ?? [];
      return EmailMessage(
        id: data['id'] as String,
        accountId: 'gmail',
        from: from,
        fromName: fromName.isEmpty ? from : fromName,
        subject: subject,
        snippet: data['snippet'] as String? ?? '',
        date: date,
        isRead: !labelIds.contains('UNREAD'),
        isStarred: labelIds.contains('STARRED'),
        hasAttachment: _hasAttachment(data),
      );
    } catch (_) {
      return null;
    }
  }

  static bool _hasAttachment(Map<String, dynamic> data) {
    final parts =
        (data['payload']?['parts'] as List<dynamic>?) ?? [];
    return parts.any((p) =>
        (p['filename'] as String?)?.isNotEmpty ?? false);
  }

  static String? _extractBody(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    // plain text 우선, 없으면 HTML
    return _findPart(payload, 'text/plain') ??
        _findPart(payload, 'text/html');
  }

  static String? _findPart(Map<String, dynamic> payload, String mime) {
    if (payload['mimeType'] == mime) {
      final data =
          (payload['body'] as Map<String, dynamic>?)?['data'] as String?;
      if (data != null) {
        final normalized =
            data.replaceAll('-', '+').replaceAll('_', '/');
        return utf8.decode(base64.decode(normalized));
      }
    }
    for (final part in (payload['parts'] as List<dynamic>?) ?? []) {
      final result = _findPart(part as Map<String, dynamic>, mime);
      if (result != null) return result;
    }
    return null;
  }
}
