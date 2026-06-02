import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hub_provider.dart';
import '../widgets/link_card.dart';
import '../widgets/add_link_sheet.dart';
import '../../../core/constants/app_constants.dart';

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(hubCategoryProvider);
    final search = ref.watch(hubSearchProvider);
    final links = ref.watch(filteredLinksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 DB 허브'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // 검색바
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '제목, 요약, 태그 검색...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => ref.read(hubSearchProvider.notifier).state = '',
                          )
                        : null,
                  ),
                  onChanged: (v) => ref.read(hubSearchProvider.notifier).state = v,
                ),
              ),
              // 카테고리 칩
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: HubCategory.all_list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final cat = HubCategory.all_list[i];
                    final selected = category == cat.id;
                    return FilterChip(
                      label: Text('${cat.emoji} ${cat.label}'),
                      selected: selected,
                      onSelected: (_) =>
                          ref.read(hubCategoryProvider.notifier).state = cat.id,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: links.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔗', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text('아직 저장된 링크가 없어요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('아래 + 버튼으로 첫 링크를 추가해보세요!',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return LinkCard(
                item: item,
                onEdit: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddLinkSheet(editItem: item),
                ),
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('삭제'),
                      content: const Text('이 링크를 삭제할까요?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(hubNotifierProvider.notifier).deleteLink(item.id);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddLinkSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('링크 추가'),
      ),
    );
  }
}
