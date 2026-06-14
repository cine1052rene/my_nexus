import 'package:flutter/material.dart';

class AppTabDef {
  final String id;
  final String path;
  final String label;
  final String emoji;
  final IconData icon;
  final IconData activeIcon;
  final bool alwaysOn;       // 항상 보임 (설정 탭)
  final bool defaultEnabled; // 기본 활성 여부

  const AppTabDef({
    required this.id,
    required this.path,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.activeIcon,
    this.alwaysOn = false,
    this.defaultEnabled = true,
  });
}

const kAllTabs = <AppTabDef>[
  AppTabDef(
    id: 'hub', path: '/hub', label: 'DB 허브', emoji: '📚',
    icon: Icons.folder_outlined, activeIcon: Icons.folder,
  ),
  AppTabDef(
    id: 'calendar', path: '/calendar', label: '스케줄', emoji: '📅',
    icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,
  ),
  AppTabDef(
    id: 'email', path: '/email', label: '메일', emoji: '📬',
    icon: Icons.mail_outline, activeIcon: Icons.mail,
    defaultEnabled: false, // Gmail CASA Tier 2 검토 전까지 기본 비활성
  ),
  AppTabDef(
    id: 'chat', path: '/chat', label: '챗봇', emoji: '🤖',
    icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble,
  ),
  AppTabDef(
    id: 'myroom', path: '/myroom', label: '마이룸', emoji: '🎬',
    icon: Icons.video_library_outlined, activeIcon: Icons.video_library,
    defaultEnabled: false, // 기본 비활성 (설정에서 켜야 사용 가능)
  ),
  AppTabDef(
    id: 'settings', path: '/settings', label: '설정', emoji: '⚙️',
    icon: Icons.settings_outlined, activeIcon: Icons.settings,
    alwaysOn: true,
  ),
];

/// 설정에서 토글 가능한 탭 (settings 제외)
List<AppTabDef> get kToggleableTabs =>
    kAllTabs.where((t) => !t.alwaysOn).toList();
