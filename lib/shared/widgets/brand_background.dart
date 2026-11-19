import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 브랜드 색 — 앱 아이콘(assets/icon/icon.png)에서 추출 (2026-11-19).
/// 스토어 그래픽 이미지·적응형 아이콘 배경(#6C2780)과 같은 계열이다.
class BrandColors {
  BrandColors._();
  static const purple = Color(0xFF6C2780); // 아이콘 배경 = 시스템 스플래시 배경
  static const deep = Color(0xFF2A0840); // 아이콘 그림자 쪽 진보라
  static const mint = Color(0xFF4FE3A8); // N 테두리
  static const teal = Color(0xFF3FBCB1); // N 옆 줄무늬
}

/// 로그인·로딩 화면 공통 배경: 보라 그라데이션 + 옅은 원 장식.
/// 시스템 스플래시(#6C2780)에서 넘어올 때 색이 끊기지 않도록 위쪽을 같은 색으로 시작한다.
class BrandBackground extends StatelessWidget {
  final Widget child;
  const BrandBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: BrandColors.deep,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BrandColors.purple, Color(0xFF4A1660), BrandColors.deep],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(top: -90, right: -70, child: _Orb(size: 260)),
            const Positioned(bottom: -60, left: -80, child: _Orb(size: 220)),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  const _Orb({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
        ),
      );
}

/// 앱 아이콘 로고 (둥근 모서리 + 민트 빛 번짐)
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 112});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.27),
          boxShadow: [
            BoxShadow(
              color: BrandColors.mint.withValues(alpha: 0.28),
              blurRadius: size * 0.35,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.27),
          child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
        ),
      );
}

/// 앱 시작 직후(로그인 상태 확인 중) 화면 — 시스템 스플래시와 같은 색·같은 로고.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: BrandBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(size: 104),
                SizedBox(height: 36),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: BrandColors.mint,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
