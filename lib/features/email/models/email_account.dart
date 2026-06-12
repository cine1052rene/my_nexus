enum EmailAccountType { gmail, imap }

class EmailAccount {
  final String id;
  final String email;
  final String displayName;
  final EmailAccountType type;

  // IMAP 전용 설정
  final String? imapHost;
  final int imapPort;
  final bool imapSsl;
  final String? smtpHost;
  final int smtpPort;
  final bool smtpSsl;
  final String? password; // SharedPreferences에 저장 (암호화는 추후 개선)

  const EmailAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.type,
    this.imapHost,
    this.imapPort = 993,
    this.imapSsl = true,
    this.smtpHost,
    this.smtpPort = 587,
    this.smtpSsl = false,
    this.password,
  });

  bool get isGmail => type == EmailAccountType.gmail;

  /// 이메일 제공사 자동 감지
  static EmailAccount fromImap({
    required String email,
    required String password,
  }) {
    final domain = email.split('@').last.toLowerCase();
    final config = _presets[domain] ?? _presets['default']!;
    return EmailAccount(
      id: 'imap_$email',
      email: email,
      displayName: email,
      type: EmailAccountType.imap,
      imapHost: config['imapHost'] as String,
      imapPort: config['imapPort'] as int,
      imapSsl: config['imapSsl'] as bool,
      smtpHost: config['smtpHost'] as String,
      smtpPort: config['smtpPort'] as int,
      smtpSsl: config['smtpSsl'] as bool,
      password: password,
    );
  }

  // 주요 이메일 제공사 프리셋
  static const _presets = <String, Map<String, Object>>{
    'gmail.com': {
      'imapHost': 'imap.gmail.com', 'imapPort': 993, 'imapSsl': true,
      'smtpHost': 'smtp.gmail.com', 'smtpPort': 587, 'smtpSsl': false,
    },
    'naver.com': {
      'imapHost': 'imap.naver.com', 'imapPort': 993, 'imapSsl': true,
      'smtpHost': 'smtp.naver.com', 'smtpPort': 587, 'smtpSsl': false,
    },
    'daum.net': {
      'imapHost': 'imap.daum.net', 'imapPort': 993, 'imapSsl': true,
      'smtpHost': 'smtp.daum.net', 'smtpPort': 465, 'smtpSsl': true,
    },
    'kakao.com': {
      'imapHost': 'imap.kakao.com', 'imapPort': 993, 'imapSsl': true,
      'smtpHost': 'smtp.kakao.com', 'smtpPort': 465, 'smtpSsl': true,
    },
    'outlook.com': {
      'imapHost': 'outlook.office365.com', 'imapPort': 993, 'imapSsl': true,
      'smtpHost': 'smtp.office365.com', 'smtpPort': 587, 'smtpSsl': false,
    },
    'hotmail.com': {
      'imapHost': 'outlook.office365.com', 'imapPort': 993, 'imapSsl': true,
      'smtpHost': 'smtp.office365.com', 'smtpPort': 587, 'smtpSsl': false,
    },
    'default': {
      'imapHost': 'imap.gmail.com', 'imapPort': 993, 'imapSsl': true,
      'smtpHost': 'smtp.gmail.com', 'smtpPort': 587, 'smtpSsl': false,
    },
  };

  Map<String, dynamic> toJson() => {
    'id': id, 'email': email, 'displayName': displayName,
    'type': type.name, 'imapHost': imapHost, 'imapPort': imapPort,
    'imapSsl': imapSsl, 'smtpHost': smtpHost, 'smtpPort': smtpPort,
    'smtpSsl': smtpSsl,
  };

  factory EmailAccount.fromJson(Map<String, dynamic> j, {String? password}) =>
      EmailAccount(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: j['displayName'] as String,
        type: EmailAccountType.values.byName(j['type'] as String),
        imapHost: j['imapHost'] as String?,
        imapPort: j['imapPort'] as int? ?? 993,
        imapSsl: j['imapSsl'] as bool? ?? true,
        smtpHost: j['smtpHost'] as String?,
        smtpPort: j['smtpPort'] as int? ?? 587,
        smtpSsl: j['smtpSsl'] as bool? ?? false,
        password: password,
      );
}
