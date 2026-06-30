import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/link_item.dart';
import '../../../core/constants/app_constants.dart';

/// 뷰모드에 따라 List / Grid / Compact 카드를 렌더링
class LinkCard extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCurate;
  final HubViewMode viewMode;

  const LinkCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onCurate,
    this.viewMode = HubViewMode.list,
  });

  @override
  Widget build(BuildContext context) {
    return switch (viewMode) {
      HubViewMode.grid    => _GridCard(item: item, onEdit: onEdit, onDelete: onDelete, onCurate: onCurate),
      HubViewMode.compact => _CompactRow(item: item, onEdit: onEdit, onDelete: onDelete, onCurate: onCurate),
      _                   => _ListCard(item: item, onEdit: onEdit, onDelete: onDelete, onCurate: onCurate),
    };
  }
}

// ── List 모드 (수평 레이아웃: 썸네일 좌 + 내용 우) ─────────────────
class _ListCard extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCurate;
  const _ListCard({required this.item, required this.onEdit, required this.onDelete, required this.onCurate});

  String _domain() {
    try { return Uri.parse(item.url).host.replaceFirst('www.', ''); }
    catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(item.url);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 96,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── 썸네일 (좌, BoxFit.contain → 안잘림) ──────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Container(
                width: 136,
                color: const Color(0xFFF0EFFF),
                child: item.displayThumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.displayThumbnail,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => _thumbFallback(),
                      )
                    : _thumbFallback(),
              ),
            ),
            // ── 내용 (우) ──────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 제목 + 도메인
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _domain(),
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 출처 아이콘 + 메뉴 (우측 끝)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SourceIcon(category: item.category),
                        _Menu(onEdit: onEdit, onDelete: onDelete, onCurate: onCurate, iconSize: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    final cat = HubCategory.fromId(item.category);
    return Container(
      width: 136, height: 96,
      color: _brandBgColor(item.category),
      child: Center(
        child: Text(cat.emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  static Color _brandBgColor(String category) => const {
    'youtube':   Color(0x1FFF0000),
    'instagram': Color(0x1FE1306C),
    'threads':   Color(0x1F101010),
    'tiktok':    Color(0x1FEE1D52),
    'facebook':  Color(0x1F1877F2),
    'twitter':   Color(0x1F000000),
    'naver':     Color(0x1F03C75A),
  }[category] ?? const Color(0xFFF0EFFF);
}

// ── Grid 모드 (2열 그리드) — ClipCard(마이룸)와 동일한 구조 ──────────
class _GridCard extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCurate;
  const _GridCard({required this.item, required this.onEdit,
      required this.onDelete, required this.onCurate});

  static const _brandColors = <String, Color>{
    'youtube':   Color(0xFFFF0000),
    'instagram': Color(0xFFE1306C),
    'threads':   Color(0xFF101010),
    'tiktok':    Color(0xFFEE1D52),
    'facebook':  Color(0xFF1877F2),
    'twitter':   Color(0xFF000000),
    'naver':     Color(0xFF03C75A),
    'etc':       Color(0xFF607D8B),
  };

  Future<void> _open() async {
    final uri = Uri.tryParse(item.url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // 마이룸 ClipCard와 동일 — 꾹 눌러서 옵션 표시
  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('열기'),
            onTap: () { Navigator.pop(context); _open(); },
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('큐레이션'),
            onTap: () { Navigator.pop(context); onCurate(); },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('수정'),
            onTap: () { Navigator.pop(context); onEdit(); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('삭제', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(context); onDelete(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = HubCategory.fromId(item.category);
    final brandColor = _brandColors[item.category] ?? const Color(0xFF6C63FF);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: GestureDetector(
        onTap: _open,
        onLongPress: () => _showOptions(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 썸네일 16:9 — 메뉴 없음 (꾹 눌러서 옵션)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: item.displayThumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.displayThumbnail,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _Placeholder(item: item),
                  )
                : _Placeholder(item: item),
          ),
          // 정보 영역 — Stack: 배지+제목은 Column, 메뉴는 우상단 float
          Expanded(
            child: Stack(
              children: [
                // 배지 + 제목 (Row 없이 → PopupMenu 48dp 터치타겟 영향 Zero)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 5, 36, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${cat.emoji} ${cat.label}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: item.category == 'threads' || item.category == 'twitter'
                                ? Colors.grey[700]
                                : brandColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // ⋮ 메뉴 — 우상단에 float (Column 높이에 영향 없음)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Menu(
                    onEdit: onEdit, onDelete: onDelete, onCurate: onCurate,
                    iconSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Compact 모드 (텍스트 전용) ─────────────────────────────────────
class _CompactRow extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCurate;
  const _CompactRow({required this.item, required this.onEdit, required this.onDelete, required this.onCurate});

  String _domain(String url) {
    try { return Uri.parse(url).host.replaceFirst('www.', ''); }
    catch (_) { return url; }
  }

  @override
  Widget build(BuildContext context) {
    final cat = HubCategory.fromId(item.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(item.url);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_domain(item.url),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            _Menu(onEdit: onEdit, onDelete: onDelete, onCurate: onCurate, iconSize: 16),
          ]),
        ),
      ),
    );
  }
}

// ── 출처 아이콘 (카테고리 상수 일치) ───────────────────────────────
class _SourceIcon extends StatelessWidget {
  final String category;
  const _SourceIcon({required this.category});

  // 카테고리 아이콘 바와 동일한 색상
  static const _colors = <String, Color>{
    'youtube':   Color(0xFFFF0000),
    'instagram': Color(0xFFE1306C),
    'threads':   Color(0xFF101010),
    'tiktok':    Color(0xFFEE1D52),
    'facebook':  Color(0xFF1877F2),
    'twitter':   Color(0xFF000000),
    'naver':     Color(0xFF03C75A),
    'etc':       Color(0xFF607D8B),
  };

  // Material 아이콘 사용 가능한 경우
  static const _matIcons = <String, IconData>{
    'youtube':   Icons.play_circle_filled,
    'instagram': Icons.camera_alt,
    'tiktok':    Icons.music_note,
    'etc':       Icons.link,
  };

  // 텍스트로 표현하는 브랜드 (@, f, X, N)
  static const _textLabels = <String, String>{
    'threads':  '@',
    'facebook': 'f',
    'twitter':  'X',
    'naver':    'N',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[category] ?? const Color(0xFF607D8B);
    if (_textLabels.containsKey(category)) {
      return SizedBox(
        width: 24, height: 24,
        child: Center(
          child: Text(
            _textLabels[category]!,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
        ),
      );
    }
    return Icon(_matIcons[category] ?? Icons.label_outline, size: 20, color: color);
  }
}

// ── 공통 플레이스홀더 (Grid용) — 플랫폼별 브랜드 컬러 배경 ──────────
class _Placeholder extends StatelessWidget {
  final LinkItem item;
  const _Placeholder({required this.item});

  static const _bgColors = <String, Color>{
    'youtube':   Color(0x1FFF0000),
    'instagram': Color(0x1FE1306C),
    'threads':   Color(0x1F101010),
    'tiktok':    Color(0x1FEE1D52),
    'facebook':  Color(0x1F1877F2),
    'twitter':   Color(0x1F000000),
    'naver':     Color(0x1F03C75A),
  };

  @override
  Widget build(BuildContext context) {
    final cat = HubCategory.fromId(item.category);
    final bg = _bgColors[item.category] ?? const Color(0xFFF0EFFF);
    return Container(
      width: double.infinity,
      color: bg,
      child: Center(
        child: Text(cat.emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}

// ── 공통 팝업 메뉴 ─────────────────────────────────────────────────
class _Menu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCurate;
  final double iconSize;
  final Color? iconColor;
  const _Menu({
    required this.onEdit,
    required this.onDelete,
    required this.onCurate,
    this.iconSize = 18,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    iconSize: iconSize,
    padding: EdgeInsets.zero,
    icon: Icon(Icons.more_vert, size: iconSize, color: iconColor),
    onSelected: (v) {
      if (v == 'curate') onCurate();
      if (v == 'edit')   onEdit();
      if (v == 'delete') onDelete();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'curate', child: Text('🎓 큐레이션')),
      const PopupMenuItem(value: 'edit',   child: Text('✏️ 수정')),
      const PopupMenuItem(value: 'delete', child: Text('🗑️ 삭제')),
    ],
  );
}
