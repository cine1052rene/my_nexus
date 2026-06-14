import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/tab_defs.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/hub/screens/hub_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/email/screens/email_screen.dart';
import 'features/myroom/screens/myroom_screen.dart';

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
        GoRoute(path: '/email',    builder: (_, __) => const EmailScreen()),
        GoRoute(path: '/chat',     builder: (_, __) => const ChatScreen()),
        GoRoute(path: '/myroom',   builder: (_, __) => const MyroomScreen()),
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
      loading: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
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

// ── 메인 쉘 (동적 BottomNav) ──────────────────────────────────
class MainShell extends ConsumerWidget {
  final Widget child;
  final String location;
  const MainShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuresAsync = ref.watch(tabFeaturesProvider);
    final featureMap = featuresAsync.valueOrNull ?? {};

    // 표시할 탭 = 활성화된 탭 + settings(항상)
    final visibleTabs = kAllTabs.where((tab) {
      if (tab.alwaysOn) return true;
      return featureMap[tab.id] ?? tab.defaultEnabled;
    }).toList();

    // 현재 위치에 해당하는 탭 인덱스
    int currentIndex = visibleTabs.indexWhere(
      (t) => location.startsWith(t.path),
    );
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEF5), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(visibleTabs[i].path),
          type: BottomNavigationBarType.fixed,
          items: visibleTabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon),
                    activeIcon: Icon(t.activeIcon),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
