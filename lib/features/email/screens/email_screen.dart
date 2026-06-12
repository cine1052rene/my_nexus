import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/email_message.dart';
import '../models/email_account.dart';
import '../providers/email_provider.dart';
import '../widgets/email_tile.dart';
import 'add_account_sheet.dart';
import 'email_detail_screen.dart';

class EmailScreen extends ConsumerWidget {
  const EmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(emailAccountsProvider);

    return accountsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('오류: $e'))),
      data: (accounts) => accounts.isEmpty
          ? _EmptyState(onAddAccount: () => _showAddAccount(context))
          : _InboxView(accounts: accounts),
    );
  }

  void _showAddAccount(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAccountSheet(),
    );
  }
}

// ── 계정 없을 때 빈 화면 ─────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddAccount;
  const _EmptyState({required this.onAddAccount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📧 메일')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📬', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text('연결된 이메일 계정이 없어요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Gmail 또는 외부 이메일을 추가해보세요',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddAccount,
              icon: const Icon(Icons.add),
              label: const Text('이메일 계정 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 받은 편지함 메인 뷰 ──────────────────────────────────────────

class _InboxView extends ConsumerWidget {
  final List<EmailAccount> accounts;
  const _InboxView({required this.accounts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailsAsync = ref.watch(emailsProvider);
    final filtered = ref.watch(filteredEmailsProvider);
    final selectedCategory = ref.watch(selectedEmailCategoryProvider);
    final selectedAccountId = ref.watch(selectedAccountIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📧 메일'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(emailsProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddAccountSheet(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 계정 탭 (여러 계정 있을 때만)
          if (accounts.length > 1)
            _AccountSelector(
              accounts: accounts,
              selectedId: selectedAccountId,
              onSelect: (id) =>
                  ref.read(selectedAccountIdProvider.notifier).state = id,
            ),

          // ── 카테고리 필터 칩
          _CategoryFilter(
            selected: selectedCategory,
            onSelect: (cat) =>
                ref.read(selectedEmailCategoryProvider.notifier).state = cat,
          ),

          // ── 이메일 목록
          Expanded(
            child: emailsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('불러오기 실패: $e')),
              data: (_) => filtered.isEmpty
                  ? const Center(
                      child: Text('메일이 없어요 📭',
                          style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(emailsProvider.notifier).refresh(),
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => EmailTile(
                          email: filtered[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EmailDetailScreen(email: filtered[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 계정 셀렉터 ──────────────────────────────────────────────────

class _AccountSelector extends StatelessWidget {
  final List<EmailAccount> accounts;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _AccountSelector({
    required this.accounts,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _chip('전체', selectedId == null, () => onSelect(null)),
          ...accounts.map((a) => _chip(
              a.email.split('@').first,
              selectedId == a.id,
              () => onSelect(a.id))),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFD9D6FF),
        checkmarkColor: const Color(0xFF6C63FF),
      ),
    );
  }
}

// ── 카테고리 필터 ─────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  final EmailCategory? selected;
  final ValueChanged<EmailCategory?> onSelect;

  const _CategoryFilter({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _chip('전체', null),
          ...EmailCategory.values.map((c) => _chip('${c.emoji} ${c.label}', c)),
        ],
      ),
    );
  }

  Widget _chip(String label, EmailCategory? cat) {
    final isSelected = selected == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (_) => onSelect(isSelected ? null : cat),
        selectedColor: const Color(0xFFD9D6FF),
        checkmarkColor: const Color(0xFF6C63FF),
      ),
    );
  }
}
