enum EmailCategory {
  work('업무', '💼'),
  personal('개인', '👤'),
  newsletter('뉴스레터', '📰'),
  notification('알림', '🔔'),
  other('기타', '📧');

  final String label;
  final String emoji;
  const EmailCategory(this.label, this.emoji);
}

class EmailMessage {
  final String id;
  final String accountId;
  final String from;
  final String fromName;
  final String subject;
  final String snippet;
  final String? body;
  final DateTime date;
  final bool isRead;
  final bool isStarred;
  final bool hasAttachment;
  final EmailCategory category;
  final String? aiSummary;

  const EmailMessage({
    required this.id,
    required this.accountId,
    required this.from,
    required this.fromName,
    required this.subject,
    required this.snippet,
    this.body,
    required this.date,
    this.isRead = false,
    this.isStarred = false,
    this.hasAttachment = false,
    this.category = EmailCategory.other,
    this.aiSummary,
  });

  EmailMessage copyWith({
    bool? isRead,
    bool? isStarred,
    EmailCategory? category,
    String? aiSummary,
    String? body,
  }) =>
      EmailMessage(
        id: id,
        accountId: accountId,
        from: from,
        fromName: fromName,
        subject: subject,
        snippet: snippet,
        body: body ?? this.body,
        date: date,
        isRead: isRead ?? this.isRead,
        isStarred: isStarred ?? this.isStarred,
        hasAttachment: hasAttachment,
        category: category ?? this.category,
        aiSummary: aiSummary ?? this.aiSummary,
      );
}
