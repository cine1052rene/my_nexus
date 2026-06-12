import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/hub/screens/hub_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/settings/screens/settings_screen.dart';

// Auth 상태를 반영한 라우터
GoRouter _buildRouter(bool isLoggedIn) => GoRouter(
  initialLocation: isLoggedIn ? '/hub' : '/login',
  redirect: (context, state) {
    final onLogin = state.matchedLocation == '/login';
    if (!isLoggedIn && !onLogin) return '/login';
    if (isLoggedIn && onLogin) return '/hub';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) =>
          MainShell(child: child, location: state.uri.toString()),
      routes: [
        GoRoute(path: '/hub',      builder: (_, __) => const HubScreen()),
        GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
        GoRoute(path: '/chat',     builder: (_, __) => const ChatScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);

class MyNexusApp extends ConsumerWidget {
  const MyNexusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      // 로딩 중 (앱 시작 시 auth 확인)
      loading: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const MaterialApp(
        home: Scaffold(body: Center(child: Text('오류가 발생했어요'))),
      ),
      data: (user) {
        final router = _buildRouter(user != null);
        return MaterialApp.router(
          title: 'MyNexus',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// ── 메인 쉘 (BottomNav 4탭) ───────────────────────────────────
class MainShell extends StatelessWidget {
  final Widget child;
  final String location;
  const MainShell({super.key, required this.child, required this.location});

  static const _tabs   = ['/hub', '/calendar', '/chat', '/settings'];
  static const _labels = ['DB 허브', '스케줄', '챗봇', '설정'];
  static const _icons  = [
    Icons.folder_outlined,
    Icons.calendar_month_outlined,
    Icons.chat_bubble_outline,
    Icons.settings_outlined,
  ];
  static const _activeIcons = [
    Icons.folder,
    Icons.calendar_month,
    Icons.chat_bubble,
    Icons.settings,
  ];

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
          type: BottomNavigationBarType.fixed,
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
