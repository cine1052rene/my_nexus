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

  Widget _thumbFallback() => Center(
    child: Text(
      item.isYouTube ? '▶️' : '🔗',
      style: const TextStyle(fontSize: 26),
    ),
  );
}

// ── Grid 모드 (2열 그리드) ─────────────────────────────────────────
class _GridCard extends StatelessWidget {
  final LinkItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCurate;
  const _GridCard({required this.item, required this.onEdit, required this.onDelete, required this.onCurate});

  @override
  Widget build(BuildContext context) {
    final cat = HubCategory.fromId(item.category);
    return Card(
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(item.url);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 썸네일
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: item.displayThumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.displayThumbnail,
                    height: 110, width: double.infinity, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _Placeholder(item: item, height: 110),
                  )
                : _Placeholder(item: item, height: 110),
          ),
          // 제목 + 메뉴
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${cat.emoji} ${cat.label}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600)),
                ),
                _Menu(onEdit: onEdit, onDelete: onDelete, onCurate: onCurate, iconSize: 16),
              ]),
              const SizedBox(height: 4),
              Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
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
    'facebook':  Color(0xFF1877F2),
    'twitter':   Color(0xFF000000),
    'naver':     Color(0xFF03C75A),
    'etc':       Color(0xFF607D8B),
  };

  // Material 아이콘 사용 가능한 경우
  static const _matIcons = <String, IconData>{
    'youtube':   Icons.play_circle_filled,
    'instagram': Icons.camera_alt,
    'etc':       Icons.link,
  };

  // 텍스트로 표현하는 브랜드 (f, X, N)
  static const _textLabels = <String, String>{
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

// ── 공통 플레이스홀더 (Grid용) ──────────────────────────────────────
class _Placeholder extends StatelessWidget {
  final LinkItem item;
  final double height;
  const _Placeholder({required this.item, this.height = 80});

  @override
  Widget build(BuildContext context) => Container(
    height: height, width: double.infinity,
    color: const Color(0xFFF0EFFF),
    child: Center(
      child: Text(
        item.isYouTube ? '▶️' : '🔗',
        style: TextStyle(fontSize: height > 90 ? 36 : 26),
      ),
    ),
  );
}

// ── 공통 팝업 메뉴 ─────────────────────────────────────────────────
class _Menu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCurate;
  final double iconSize;
  const _Menu({
    required this.onEdit,
    required this.onDelete,
    required this.onCurate,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    iconSize: iconSize,
    padding: EdgeInsets.zero,
    onSelected: (v) {
      if (v == 'edit')    onEdit();
      if (v == 'delete')  onDelete();
      if (v == 'curate')  onCurate();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'curate', child: Text('🎓 큐레이션')),
      const PopupMenuItem(value: 'edit',   child: Text('✏️ 수정')),
      const PopupMenuItem(value: 'delete', child: Text('🗑️ 삭제')),
    ],
  );
}
