import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/email_message.dart';
import '../models/email_account.dart';
import '../../../shared/services/gmail_service.dart';
import '../../../shared/services/imap_service.dart';
import '../../../shared/services/email_ai_service.dart';
import '../../settings/providers/settings_provider.dart';

// ── 계정 목록 ─────────────────────────────────────────────────────

class AccountsNotifier extends AsyncNotifier<List<EmailAccount>> {
  static const _prefsKey = 'email_accounts';
  static const _pwPrefix = 'email_pw_';

  @override
  Future<List<EmailAccount>> build() async => _load();

  Future<List<EmailAccount>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw.map((s) {
      final j = jsonDecode(s) as Map<String, dynamic>;
      final pw = prefs.getString('$_pwPrefix${j['id']}');
      return EmailAccount.fromJson(j, password: pw);
    }).toList();
  }

  Future<void> addGmail() async {
    final account = await GmailService.signIn();
    if (account == null) return;
    await _persist(account);
  }

  Future<void> addImap(String email, String password) async {
    final account = EmailAccount.fromImap(email: email, password: password);
    final svc = ImapService(account);
    final ok = await svc.connect();
    await svc.disconnect();
    if (!ok) throw Exception('IMAP 연결 실패. 이메일과 비밀번호를 확인해주세요.');
    await _persist(account);
  }

  Future<void> _persist(EmailAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final current = state.value ?? [];
    if (current.any((a) => a.id == account.id)) return;
    final updated = [...current, account];
    await prefs.setStringList(
      _prefsKey,
      updated.map((a) => jsonEncode(a.toJson())).toList(),
    );
    if (account.password != null) {
      await prefs.setString('$_pwPrefix${account.id}', account.password!);
    }
    state = AsyncData(updated);
  }

  Future<void> remove(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = state.value ?? [];
    final updated = current.where((a) => a.id != accountId).toList();
    await prefs.setStringList(
      _prefsKey,
      updated.map((a) => jsonEncode(a.toJson())).toList(),
    );
    await prefs.remove('$_pwPrefix$accountId');
    state = AsyncData(updated);
  }
}

final emailAccountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<EmailAccount>>(
        AccountsNotifier.new);

// ── 선택된 계정 / 카테고리 필터 ───────────────────────────────────

final selectedAccountIdProvider = StateProvider<String?>((ref) => null);
final selectedEmailCategoryProvider =
    StateProvider<EmailCategory?>((ref) => null);

// ── 이메일 목록 ───────────────────────────────────────────────────

class EmailsNotifier extends AsyncNotifier<List<EmailMessage>> {
  final _imapClients = <String, ImapService>{};

  @override
  Future<List<EmailMessage>> build() async {
    final accounts = await ref.watch(emailAccountsProvider.future);
    if (accounts.isEmpty) return [];

    // AI 서비스는 Firebase Functions 프록시 사용 — 별도 초기화 불필요

    return _fetchAll(accounts);
  }

  Future<List<EmailMessage>> _fetchAll(List<EmailAccount> accounts) async {
    final all = <EmailMessage>[];
    for (final acc in accounts) {
      final msgs =
          acc.isGmail ? await GmailService.fetchInbox() : await _fetchImap(acc);
      all.addAll(msgs);
    }
    all.sort((a, b) => b.date.compareTo(a.date));
    _classifyBackground(all);
    return all;
  }

  void _classifyBackground(List<EmailMessage> messages) async {
    final categories = await EmailAiService.classifyBatch(messages);
    if (categories.isEmpty) return;
    final current = state.value ?? [];
    state = AsyncData(current
        .map((m) => categories[m.id] != null
            ? m.copyWith(category: categories[m.id])
            : m)
        .toList());
  }

  Future<List<EmailMessage>> _fetchImap(EmailAccount acc) async {
    final svc = _imapClients[acc.id] ??= ImapService(acc);
    await svc.connect();
    return svc.fetchInbox();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final accounts = await ref.read(emailAccountsProvider.future);
    state = AsyncData(await _fetchAll(accounts));
  }

  Future<String?> loadBody(String messageId, String accountId) async {
    if (accountId == 'gmail') return GmailService.fetchBody(messageId);
    final svc = _imapClients[accountId];
    return svc?.fetchBody(messageId);
  }

  Future<String?> summarize(EmailMessage msg) async {
    if (msg.aiSummary != null) return msg.aiSummary;
    final body = await loadBody(msg.id, msg.accountId);
    if (body == null) return null;
    final summary = await EmailAiService.summarize(
      subject: msg.subject,
      body: body,
    );
    final current = state.value ?? [];
    state = AsyncData(current
        .map((m) => m.id == msg.id ? m.copyWith(aiSummary: summary) : m)
        .toList());
    return summary;
  }

  void markRead(String messageId) {
    GmailService.markAsRead(messageId);
    final current = state.value ?? [];
    state = AsyncData(current
        .map((m) => m.id == messageId ? m.copyWith(isRead: true) : m)
        .toList());
  }
}

final emailsProvider =
    AsyncNotifierProvider<EmailsNotifier, List<EmailMessage>>(
        EmailsNotifier.new);

// ── 필터된 이메일 목록 ────────────────────────────────────────────

final filteredEmailsProvider = Provider<List<EmailMessage>>((ref) {
  final emails = ref.watch(emailsProvider).value ?? [];
  final accountId = ref.watch(selectedAccountIdProvider);
  final category = ref.watch(selectedEmailCategoryProvider);

  return emails.where((e) {
    if (accountId != null && e.accountId != accountId) return false;
    if (category != null && e.category != category) return false;
    return true;
  }).toList();
});
