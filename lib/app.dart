import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/hub/screens/hub_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/settings/screens/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/hub',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          MainShell(child: child, location: state.uri.toString()),
      routes: [
        GoRoute(path: '/hub', builder: (_, __) => const HubScreen()),
        GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);

class MyNexusApp extends StatelessWidget {
  const MyNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyNexus',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
    );
  }
}

// ── 메인 쉘 (BottomNav) ────────────────────────────────────────────────────
class MainShell extends StatelessWidget {
  final Widget child;
  final String location;
  const MainShell({super.key, required this.child, required this.location});

  static const _tabs = ['/hub', '/calendar', '/settings'];
  static const _labels = ['DB 허브', '스케줄', '설정'];
  static const _icons = [Icons.folder_outlined, Icons.calendar_month_outlined, Icons.settings_outlined];
  static const _activeIcons = [Icons.folder, Icons.calendar_month, Icons.settings];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex < 0 ? 0 : currentIndex,
          onTap: (i) => context.go(_tabs[i]),
          items: List.generate(
            _tabs.length,
            (i) => BottomNavigationBarItem(
              icon: Icon(_icons[i]),
              activeIcon: Icon(_activeIcons[i]),
              label: _labels[i],
            ),
          ),
        ),
      ),
    );
  }
}
